/*
  libnet.url

  Absolute hierarchical URL — `<scheme>://<authority>[/path][?query]
  [#fragment]`, where the authority is `[userinfo@]<host>[:port]`. The
  application-layer superset of `socketUrl`: `socketUrl` is an L4 socket
  address; `url` adds scheme-default ports, the path/query/fragment, and
  userinfo.

  Bounded: absolute hierarchical URLs only — no relative references, no
  opaque URIs (`mailto:`, `urn:`). Components are stored verbatim (no
  percent-decoding, normalization, or relative resolution; `lib.escapeURL`
  exists for the encode direction). The host is the URL-authority host
  (RFC 3986 reg-name / IP-literal), looser than `libnet.host` — see
  `libnet.urlHost`. `userinfo` is kept raw and opaque; note it may carry
  credentials. The authority is stored as a `libnet.authority` value, and
  `host`, `port` and `userinfo` read through it.

  Example:
    libnet.url.parse "https://user@example.com/p?q=1#f"
    => { _type = "url"; scheme = "https";
         authority = <authority user@example.com>; path = "/p";
         query = "q=1"; fragment = "f"; }
*/
let
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  urlHost = import ./url-host.nix;
  authority = import ./authority.nix;
  port = import ./port.nix;
  transport = import ./transport.nix;
  ipEndpoint = import ./ip-endpoint.nix;
  dnsEndpoint = import ./dns-endpoint.nix;
  registry = import ./registry.nix;

  lowerAscii = dnsLabel.toLowerAscii;
  mkPort = port.fromInt;
  wellKnownPorts = registry.ports;

  # Closed registry of URL schemes. Default ports are sourced from
  # registry.ports (the single source of truth for port numbers); this
  # table adds only the L4 transport and whether the scheme's protocol
  # encrypts the connection (`secure`). Schemes that ride another
  # service's port reference it (ws → http, wss → https, sftp → ssh).
  mkScheme = portNumber: transportName: secure: {
    defaultPort = portNumber;
    transport = transportName;
    inherit secure;
  };
  schemes = {
    http = mkScheme wellKnownPorts.tcp.http "tcp" false;
    https = mkScheme wellKnownPorts.tcp.https "tcp" true;
    ws = mkScheme wellKnownPorts.tcp.http "tcp" false;
    wss = mkScheme wellKnownPorts.tcp.https "tcp" true;
    ftp = mkScheme wellKnownPorts.tcp.ftp "tcp" false;
    ftps = mkScheme wellKnownPorts.tcp.ftps "tcp" true;
    sftp = mkScheme wellKnownPorts.tcp.ssh "tcp" true;
    tftp = mkScheme wellKnownPorts.udp.tftp "udp" false;
    ssh = mkScheme wellKnownPorts.tcp.ssh "tcp" true;
    telnet = mkScheme wellKnownPorts.tcp.telnet "tcp" false;
    rdp = mkScheme wellKnownPorts.tcp.rdp "tcp" false;
    vnc = mkScheme wellKnownPorts.tcp.vnc "tcp" false;
    ldap = mkScheme wellKnownPorts.tcp.ldap "tcp" false;
    ldaps = mkScheme wellKnownPorts.tcp.ldaps "tcp" true;
    postgres = mkScheme wellKnownPorts.tcp.postgres "tcp" false;
    mysql = mkScheme wellKnownPorts.tcp.mysql "tcp" false;
    mongodb = mkScheme wellKnownPorts.tcp.mongodb "tcp" false;
    redis = mkScheme wellKnownPorts.tcp.redis "tcp" false;
    amqp = mkScheme wellKnownPorts.tcp.amqp "tcp" false;
    amqps = mkScheme wellKnownPorts.tcp.amqps "tcp" true;
    mqtt = mkScheme wellKnownPorts.tcp.mqtt "tcp" false;
    mqtts = mkScheme wellKnownPorts.tcp.mqtts "tcp" true;
    git = mkScheme wellKnownPorts.tcp.git "tcp" false;
    svn = mkScheme wellKnownPorts.tcp.svn "tcp" false;
    rsync = mkScheme wellKnownPorts.tcp.rsync "tcp" false;
    coap = mkScheme wellKnownPorts.udp.coap "udp" false;
    coaps = mkScheme wellKnownPorts.udp.coaps "udp" true;
    irc = mkScheme wellKnownPorts.tcp.irc "tcp" false;
    ircs = mkScheme wellKnownPorts.tcp.ircs "tcp" true;
    xmpp = mkScheme wellKnownPorts.tcp.xmpp "tcp" false;
  };

  mk = schemeValue: authorityValue: pathValue: queryValue: fragmentValue: {
    _type = "url";
    scheme = schemeValue;
    authority = authorityValue;
    path = pathValue;
    query = queryValue;
    fragment = fragmentValue;
  };

  # ===== Parsing =====

  /*
    Parse an absolute URL without throwing, for callers that branch on
    validity.

    `input`: `<scheme>://[userinfo@]host[:port][/path][?query][#fragment]`
    text; the scheme must be a key of `schemes` (matched
    case-insensitively).

    Returns a tryResult: `{ success = true; value = <url>; }` or
    `{ success = false; error = <string>; }`. Authority errors come from
    `libnet.authority.tryParse`. Never throws.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.url.parse: input must be a string"
    else
      let
        schemeParts = parsing.splitOn "://" input;
      in
      if builtins.length schemeParts < 2 then
        types.tryErr "libnet.url.parse: missing \"<scheme>://\": \"${input}\""
      else
        let
          rawScheme = builtins.elemAt schemeParts 0;
          lowerScheme = lowerAscii rawScheme;
          rest = builtins.concatStringsSep "://" (builtins.tail schemeParts);
        in
        if !(schemes ? ${lowerScheme}) then
          types.tryErr "libnet.url.parse: unknown scheme \"${rawScheme}\": \"${input}\""
        else
          let
            fragmentParts = parsing.splitOn "#" rest;
            beforeFragment = builtins.elemAt fragmentParts 0;
            fragmentValue =
              if builtins.length fragmentParts > 1 then
                builtins.concatStringsSep "#" (builtins.tail fragmentParts)
              else
                null;
            queryParts = parsing.splitOn "?" beforeFragment;
            beforeQuery = builtins.elemAt queryParts 0;
            queryValue =
              if builtins.length queryParts > 1 then
                builtins.concatStringsSep "?" (builtins.tail queryParts)
              else
                null;
            slashParts = parsing.splitOn "/" beforeQuery;
            authorityText = builtins.elemAt slashParts 0;
            pathValue =
              if builtins.length slashParts > 1 then
                "/" + builtins.concatStringsSep "/" (builtins.tail slashParts)
              else
                "";
            authorityResult = authority.tryParse authorityText;
          in
          if !authorityResult.success then
            authorityResult
          else
            types.tryOk (mk lowerScheme authorityResult.value pathValue queryValue fragmentValue);

  /*
    Parse an absolute URL, for values that must be valid.

    `input`: URL text as accepted by `tryParse`.

    Returns a url value; throws on an unknown scheme, a missing or invalid
    host, a bad port, or relative or opaque input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a URL back to text.

    `url`: a url value.

    Returns `<scheme>://<authority><path>[?query][#fragment]`, omitting the
    port when none was given, so parsed input round-trips.
  */
  toString =
    url:
    let
      queryPart = if url.query == null then "" else "?${url.query}";
      fragmentPart = if url.fragment == null then "" else "#${url.fragment}";
    in
    "${url.scheme}://${authority.toString url.authority}${url.path}${queryPart}${fragmentPart}";

  # ===== Construction =====

  /*
    Build a URL from its parts; pass a whole URL string to `parse`
    instead.

    `scheme`: a key of `schemes`, matched case-insensitively.
    `authority`: authority value; a null port means the scheme default.
    `path`: "" (default) or a string starting with `/`.
    `query`: raw query string without `?`, or null (default).
    `fragment`: raw fragment string without `#`, or null (default).

    Returns a url value; throws on an unknown scheme, a non-authority
    authority, or a path that does not start with `/`.
  */
  make =
    {
      scheme,
      authority,
      path ? "",
      query ? null,
      fragment ? null,
    }:
    let
      lowerScheme = lowerAscii scheme;
    in
    if !(schemes ? ${lowerScheme}) then
      throw "libnet.url.make: unknown scheme \"${scheme}\""
    else if !(types.isAuthority authority) then
      throw "libnet.url.make: authority must be an authority value"
    else if path != "" && !(parsing.startsWith "/" path) then
      throw "libnet.url.make: path must be empty or start with '/': \"${path}\""
    else
      mk lowerScheme authority path query fragment;

  # ===== Predicates =====

  /*
    Check whether a string parses as a URL.

    `input`: candidate URL text.

    Returns true when `tryParse` succeeds.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a url value.

    `value`: any value.

    Returns true for a url-tagged attrset.
  */
  is = value: types.isUrl value;

  /*
    Check whether a URL's scheme is secure: its protocol encrypts the
    connection, per the scheme registry. `ssh` and `sftp` are secure
    without TLS.

    `url`: a url value.

    Returns the scheme's `secure` flag.
  */
  isSecure = url: schemes.${url.scheme}.secure;

  # ===== Accessors =====

  /*
    Get the scheme of a URL.

    `url`: a url value.

    Returns the lowercase scheme string.
  */
  scheme = url: url.scheme;

  /*
    Get the userinfo of a URL.

    `url`: a url value.

    Returns the authority's raw userinfo string, or null when absent.
  */
  userinfo = url: url.authority.userinfo;

  /*
    Get the host of a URL.

    `url`: a url value.

    Returns the authority's host: an ipv4, ipv6, or regName value.
  */
  host = url: url.authority.host;

  /*
    Get the default port of a URL's scheme.

    `url`: a url value.

    Returns the registry default as a port value.
  */
  defaultPort = url: mkPort schemes.${url.scheme}.defaultPort;

  /*
    Get the port a URL connects to, filling in the scheme default.

    `url`: a url value.

    Returns the explicit port value, or the scheme's default port value.
  */
  effectivePort = url: if url.authority.port != null then url.authority.port else defaultPort url;

  /*
    Get the path of a URL.

    `url`: a url value.

    Returns the raw path: "" or a string starting with `/`.
  */
  path = url: url.path;

  /*
    Get the query of a URL.

    `url`: a url value.

    Returns the raw query string without `?`, or null when absent.
  */
  query = url: url.query;

  /*
    Get the fragment of a URL.

    `url`: a url value.

    Returns the raw fragment string without `#`, or null when absent.
  */
  fragment = url: url.fragment;

  # ===== Conversions =====

  /*
    Convert a URL to the L4 connect target for its host and effective port.

    `url`: a url value.

    Returns an ipEndpoint for IP hosts or a dnsEndpoint for registered
    names that are valid DNS names; throws for other registered names,
    which have no endpoint.
  */
  toEndpoint =
    url:
    let
      hostValue = host url;
      targetPort = effectivePort url;
    in
    if urlHost.isIp hostValue then
      ipEndpoint.make hostValue targetPort
    else
      let
        dnsHost = urlHost.toHost hostValue;
      in
      if dnsHost == null then
        throw "libnet.url.toEndpoint: registered name \"${urlHost.toString hostValue}\" is not a valid DNS name"
      else
        dnsEndpoint.make dnsHost targetPort;

  # ===== Comparison =====

  compareStrings =
    a: b:
    if a < b then
      -1
    else if a > b then
      1
    else
      0;

  # Order nullable strings with null first.
  compareOptionalStrings =
    a: b:
    if a == null && b == null then
      0
    else if a == null then
      -1
    else if b == null then
      1
    else
      compareStrings a b;

  # The authority with the scheme default filled in, so `https://h` and
  # `https://h:443` compare alike.
  effectiveAuthority = url: url.authority // { port = effectivePort url; };

  /*
    Test two URLs for equality. An omitted port equals the scheme
    default, so `https://h` equals `https://h:443`.

    `a`, `b`: url values.

    Returns true when the scheme, the authority with its effective port
    (host case-folded, userinfo exact), path, query, and fragment all
    match.
  */
  eq =
    a: b:
    types.hasSameTag a b
    && a.scheme == b.scheme
    && authority.eq (effectiveAuthority a) (effectiveAuthority b)
    && a.path == b.path
    && a.query == b.query
    && a.fragment == b.fragment;

  /*
    Order two URLs by scheme, host, effective port, userinfo, path,
    query, then fragment (null userinfo, query, or fragment first).

    `a`, `b`: url values.

    Returns -1, 0, or 1.
  */
  compare =
    a: b:
    if a.scheme != b.scheme then
      compareStrings a.scheme b.scheme
    else
      let
        authorityOrder = authority.compare (effectiveAuthority a) (effectiveAuthority b);
      in
      if authorityOrder != 0 then
        authorityOrder
      else
        let
          pathOrder = compareStrings a.path b.path;
        in
        if pathOrder != 0 then
          pathOrder
        else
          let
            queryOrder = compareOptionalStrings a.query b.query;
          in
          if queryOrder != 0 then queryOrder else compareOptionalStrings a.fragment b.fragment;

  /*
    Check whether one URL sorts before another.

    `a`, `b`: url values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Check whether one URL sorts before or equal to another.

    `a`, `b`: url values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Check whether one URL sorts after another.

    `a`, `b`: url values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Check whether one URL sorts after or equal to another.

    `a`, `b`: url values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two URLs by `compare`.

    `a`, `b`: url values.

    Returns `a` when it sorts first or equal, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two URLs by `compare`.

    `a`, `b`: url values.

    Returns `a` when it sorts last or equal, otherwise `b`.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    compare
    defaultPort
    effectivePort
    eq
    fragment
    ge
    gt
    host
    is
    isSecure
    isValid
    le
    lt
    make
    max
    min
    parse
    path
    query
    scheme
    schemes
    toEndpoint
    toString
    tryParse
    userinfo
    ;

  # Defined here rather than in `let`, where `authority`, `port` and
  # `transport` name the imported modules.
  /*
    Get the authority of a URL.

    `url`: a url value.

    Returns the authority value: userinfo, host, and explicit port.
  */
  authority = url: url.authority;

  /*
    Get the explicit port of a URL; see `effectivePort` for the port in use.

    `url`: a url value.

    Returns the authority's port value, or null when the input omitted it.
  */
  port = url: url.authority.port;

  /*
    Get the L4 transport of a URL's scheme.

    `url`: a url value.

    Returns a transport value (`tcp` or `udp`) from the scheme registry.
  */
  transport = url: transport.parse schemes.${url.scheme}.transport;
}
