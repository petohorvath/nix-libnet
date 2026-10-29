/*
  libnet.url

  Absolute hierarchical URL — `<scheme>://<authority>[/path][?query]
  [#fragment]`, where the authority is `[userinfo@]<host>[:port]`. The
  application-layer superset of `socketUrl`: `socketUrl` is an L4 socket
  address; `url` adds scheme-default ports, the path/query/fragment, and
  userinfo.

  Bounded: absolute hierarchical URLs only — no relative references, no
  opaque URIs (`mailto:`, `urn:`). Components are validated against their
  RFC 3986 grammars and stored verbatim (no percent-decoding,
  normalization, or relative resolution; `lib.escapeURL` exists for the
  encode direction). The host is the URL-authority host
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
  errors = import ./internal/errors.nix;
  comparison = import ./internal/comparison.nix;

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

  mk =
    schemeValue: authorityValue: pathValue: queryValue: fragmentValue:
    types.mkStrict "url" {
      scheme = schemeValue;
      authority = authorityValue;
      path = pathValue;
      query = queryValue;
      fragment = fragmentValue;
    };

  # Check the url argument of `function`, throwing for any other kind.
  urlArgument = function: url: errors.expectKind "url.${function}" "url" url;

  # The default and effective ports of a checked url.
  defaultPortOf = url: mkPort schemes.${url.scheme}.defaultPort;
  effectivePortOf = url: if url.authority.port != null then url.authority.port else defaultPortOf url;

  parseError = detail: types.tryErr (errors.message "url.parse" detail);

  /*
    RFC 3986 grammars for the components after the authority. A pchar is
    unreserved / pct-encoded / sub-delims / ":" / "@"; a path is
    *( "/" *pchar ) (§3.3), and a query (§3.4) or fragment (§3.5) is
    *( pchar / "/" / "?" ). The bracket expressions admit only ASCII.
  */
  pchar = "[-A-Za-z0-9._~!$&'()*+,;=:@]|%[0-9A-Fa-f][0-9A-Fa-f]";
  pathPattern = "(/(${pchar})*)*";
  queryPattern = "(${pchar}|[/?])*";

  isPath = text: builtins.match pathPattern text != null;
  isQuery = text: builtins.match queryPattern text != null;

  # The detail for the first component outside its grammar, or null.
  componentError =
    pathValue: queryValue: fragmentValue:
    if !(isPath pathValue) then
      "invalid path \"${pathValue}\""
    else if queryValue != null && !(isQuery queryValue) then
      "invalid query \"${queryValue}\""
    else if fragmentValue != null && !(isQuery fragmentValue) then
      "invalid fragment \"${fragmentValue}\""
    else
      null;

  # ===== Parsing =====

  /*
    Parse an absolute URL without throwing, for callers that branch on
    validity.

    `input`: `<scheme>://[userinfo@]host[:port][/path][?query][#fragment]`
    text; the scheme must be a key of `schemes` (matched
    case-insensitively).

    Returns a tryResult: `{ success = true; value = <url>; }` or
    `{ success = false; error = <string>; }`, whose error names
    `url.parse` and keeps the detail of an authority failure. Never
    throws.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError (errors.notString input)
    else
      let
        schemeParts = parsing.splitOn "://" input;
      in
      if builtins.length schemeParts < 2 then
        parseError "missing \"<scheme>://\": \"${input}\""
      else
        let
          rawScheme = builtins.elemAt schemeParts 0;
          lowerScheme = lowerAscii rawScheme;
          rest = builtins.concatStringsSep "://" (builtins.tail schemeParts);
        in
        if !(schemes ? ${lowerScheme}) then
          parseError "unknown scheme \"${rawScheme}\": \"${input}\""
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
            componentDetail = componentError pathValue queryValue fragmentValue;
          in
          if !authorityResult.success then
            parseError (errors.detail "authority.parse" authorityResult.error)
          else if componentDetail != null then
            parseError componentDetail
          else
            types.tryOk (mk lowerScheme authorityResult.value pathValue queryValue fragmentValue);

  /*
    Parse an absolute URL, for values that must be valid.

    `input`: URL text as accepted by `tryParse`.

    Returns a url value; throws on an unknown scheme, a missing or invalid
    host, a bad port, invalid userinfo, a path, query, or fragment
    outside its RFC 3986 grammar, or relative or opaque input.
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
      checked = urlArgument "toString" url;
      queryPart = if checked.query == null then "" else "?${checked.query}";
      fragmentPart = if checked.fragment == null then "" else "#${checked.fragment}";
    in
    "${checked.scheme}://${authority.toString checked.authority}${checked.path}${queryPart}${fragmentPart}";

  # ===== Construction =====

  /*
    Build a URL from its parts; pass a whole URL string to `parse`
    instead.

    `scheme`: a key of `schemes`, matched case-insensitively.
    `authority`: authority value; a null port means the scheme default.
    `path`: "" (default) or `/`-separated segments of RFC 3986 pchar,
    starting with `/`.
    `query`: raw query string without `?`, or null (default).
    `fragment`: raw fragment string without `#`, or null (default).

    The path, query and fragment must match the RFC 3986 grammars that
    `parse` checks, and are stored as given.

    Returns a url value that `parse (toString …)` gives back; throws for
    a non-set argument, a missing or unexpected attribute, an unknown
    scheme, a non-authority authority, or a component that is not a
    string or is outside its grammar.
  */
  make =
    arguments:
    let
      caller = "url.make";
      checked = errors.expectFields caller {
        required = [
          "authority"
          "scheme"
        ];
        optional = [
          "fragment"
          "path"
          "query"
        ];
      } arguments;
      schemeValue = errors.expectType caller "string" checked.scheme;
      lowerScheme = lowerAscii schemeValue;
      authorityValue = errors.expectKind caller "authority" checked.authority;
      pathValue = errors.expectType caller "string" (checked.path or "");
      optionalString = errors.expect caller "string or null" (
        value: value == null || builtins.isString value
      );
      queryValue = optionalString (checked.query or null);
      fragmentValue = optionalString (checked.fragment or null);
      componentDetail = componentError pathValue queryValue fragmentValue;
    in
    if !(schemes ? ${lowerScheme}) then
      errors.fail caller "unknown scheme \"${schemeValue}\""
    else if componentDetail != null then
      errors.fail caller componentDetail
    else
      mk lowerScheme authorityValue pathValue queryValue fragmentValue;

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
  isSecure = url: schemes.${(urlArgument "isSecure" url).scheme}.secure;

  # ===== Accessors =====

  /*
    Get the scheme of a URL.

    `url`: a url value.

    Returns the lowercase scheme string.
  */
  scheme = url: (urlArgument "scheme" url).scheme;

  /*
    Get the userinfo of a URL.

    `url`: a url value.

    Returns the authority's raw userinfo string, or null when absent.
  */
  userinfo = url: (urlArgument "userinfo" url).authority.userinfo;

  /*
    Get the host of a URL.

    `url`: a url value.

    Returns the authority's host: an ipv4, ipv6, or regName value.
  */
  host = url: (urlArgument "host" url).authority.host;

  /*
    Get the default port of a URL's scheme.

    `url`: a url value.

    Returns the registry default as a port value.
  */
  defaultPort = url: defaultPortOf (urlArgument "defaultPort" url);

  /*
    Get the port a URL connects to, filling in the scheme default.

    `url`: a url value.

    Returns the explicit port value, or the scheme's default port value.
  */
  effectivePort = url: effectivePortOf (urlArgument "effectivePort" url);

  /*
    Get the path of a URL.

    `url`: a url value.

    Returns the raw path: "" or a string starting with `/`.
  */
  path = url: (urlArgument "path" url).path;

  /*
    Get the query of a URL.

    `url`: a url value.

    Returns the raw query string without `?`, or null when absent.
  */
  query = url: (urlArgument "query" url).query;

  /*
    Get the fragment of a URL.

    `url`: a url value.

    Returns the raw fragment string without `#`, or null when absent.
  */
  fragment = url: (urlArgument "fragment" url).fragment;

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
      checked = urlArgument "toEndpoint" url;
      hostValue = checked.authority.host;
      targetPort = effectivePortOf checked;
    in
    if urlHost.isIp hostValue then
      ipEndpoint.make hostValue targetPort
    else
      let
        dnsHost = urlHost.toHost hostValue;
      in
      if dnsHost == null then
        errors.fail "url.toEndpoint" "registered name \"${urlHost.toString hostValue}\" is not a valid DNS name"
      else
        dnsEndpoint.make dnsHost targetPort;

  # ===== Comparison =====

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
      comparison.order a b;

  # The authority with the scheme default filled in, so `https://h` and
  # `https://h:443` compare alike.
  effectiveAuthority = url: url.authority // { port = effectivePortOf url; };

  # The path as compared: empty reads as `/` (RFC 3986 §6.2.3), so
  # `http://h` and `http://h/` compare alike.
  effectivePath = url: if url.path == "" then "/" else url.path;

  /*
    Test two URLs for equality. An omitted port equals the scheme
    default, so `https://h` equals `https://h:443`, and an empty path
    equals `/`, so `http://h` equals `http://h/`.

    `a`, `b`: values to compare.

    Returns true when the scheme, the authority with its effective port
    (userinfo exact), the path with empty read as `/`, query, and
    fragment all match; false for values of other kinds.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.url a b
    && a.scheme == b.scheme
    && authority.eq (effectiveAuthority a) (effectiveAuthority b)
    && effectivePath a == effectivePath b
    && a.query == b.query
    && a.fragment == b.fragment;

  # Order by scheme, host, effective port, userinfo, path (empty read as
  # `/`), query, then fragment (null userinfo, query, or fragment first).
  # The operands are checked first, so the delegated comparison cannot
  # fail and name itself.
  ordering = comparison.suite (
    function: a: b:
    let
      left = urlArgument function a;
      right = urlArgument function b;
    in
    comparison.lexicographic [
      (comparison.order left.scheme right.scheme)
      (authority.compare (effectiveAuthority left) (effectiveAuthority right))
      (comparison.order (effectivePath left) (effectivePath right))
      (compareOptionalStrings left.query right.query)
      (compareOptionalStrings left.fragment right.fragment)
    ]
  );
in
{
  inherit
    defaultPort
    effectivePort
    eq
    fragment
    host
    is
    isSecure
    isValid
    make
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
  inherit (ordering)
    compare
    ge
    gt
    le
    lt
    max
    min
    ;

  # Defined here rather than in `let`, where `authority`, `port` and
  # `transport` name the imported modules.
  /*
    Get the authority of a URL.

    `url`: a url value.

    Returns the authority value: userinfo, host, and explicit port.
  */
  authority = url: (urlArgument "authority" url).authority;

  /*
    Get the explicit port of a URL; see `effectivePort` for the port in use.

    `url`: a url value.

    Returns the authority's port value, or null when the input omitted it.
  */
  port = url: (urlArgument "port" url).authority.port;

  /*
    Get the L4 transport of a URL's scheme.

    `url`: a url value.

    Returns a transport value (`tcp` or `udp`) from the scheme registry.
  */
  transport = url: transport.parse schemes.${(urlArgument "transport" url).scheme}.transport;
}
