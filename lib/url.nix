/*
  libnet.url

  Absolute hierarchical URL — `<scheme>://[userinfo@]<host>[:port][/path]
  [?query][#fragment]`. The application-layer superset of `socketUrl`:
  `socketUrl` is an L4 socket address; `url` adds scheme-default ports,
  the path/query/fragment, and userinfo.

  Bounded: absolute hierarchical URLs only — no relative references, no
  opaque URIs (`mailto:`, `urn:`). Components are stored verbatim (no
  percent-decoding, normalization, or relative resolution; `lib.escapeURL`
  exists for the encode direction). The host is the URL-authority host
  (RFC 3986 reg-name / IP-literal), looser than `libnet.host` — see
  `libnet.urlHost`. `userinfo` is kept raw and opaque; note it may carry
  credentials.

  Example:
    libnet.url.parse "https://user@example.com/p?q=1#f"
    => { _type = "url"; scheme = "https"; userinfo = "user";
         host = <urlHost example.com>; port = null; path = "/p";
         query = "q=1"; fragment = "f"; }
*/
let
  types = import ./internal/types.nix;
  parse' = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  urlHost = import ./url-host.nix;
  port = import ./port.nix;
  transport = import ./transport.nix;
  ipEndpoint = import ./ip-endpoint.nix;
  dnsEndpoint = import ./dns-endpoint.nix;
  registry = import ./registry.nix;

  lowerAscii = dnsLabel.toLowerAscii;
  mkPort = port.fromInt;
  wkp = registry.ports;

  # Closed registry of URL schemes. Default ports are sourced from
  # registry.ports (the single source of truth for port
  # numbers); this table adds only the L4 transport and the TLS flag.
  # Schemes that ride another service's port reference it (ws → http,
  # wss → https, sftp → ssh).
  mkScheme = defaultPort: transport: secure: {
    inherit defaultPort transport secure;
  };
  schemes = {
    http = mkScheme wkp.tcp.http "tcp" false;
    https = mkScheme wkp.tcp.https "tcp" true;
    ws = mkScheme wkp.tcp.http "tcp" false;
    wss = mkScheme wkp.tcp.https "tcp" true;
    ftp = mkScheme wkp.tcp.ftp "tcp" false;
    ftps = mkScheme wkp.tcp.ftps "tcp" true;
    sftp = mkScheme wkp.tcp.ssh "tcp" true;
    tftp = mkScheme wkp.udp.tftp "udp" false;
    ssh = mkScheme wkp.tcp.ssh "tcp" true;
    telnet = mkScheme wkp.tcp.telnet "tcp" false;
    rdp = mkScheme wkp.tcp.rdp "tcp" false;
    vnc = mkScheme wkp.tcp.vnc "tcp" false;
    ldap = mkScheme wkp.tcp.ldap "tcp" false;
    ldaps = mkScheme wkp.tcp.ldaps "tcp" true;
    postgres = mkScheme wkp.tcp.postgres "tcp" false;
    mysql = mkScheme wkp.tcp.mysql "tcp" false;
    mongodb = mkScheme wkp.tcp.mongodb "tcp" false;
    redis = mkScheme wkp.tcp.redis "tcp" false;
    amqp = mkScheme wkp.tcp.amqp "tcp" false;
    amqps = mkScheme wkp.tcp.amqps "tcp" true;
    mqtt = mkScheme wkp.tcp.mqtt "tcp" false;
    mqtts = mkScheme wkp.tcp.mqtts "tcp" true;
    git = mkScheme wkp.tcp.git "tcp" false;
    svn = mkScheme wkp.tcp.svn "tcp" false;
    rsync = mkScheme wkp.tcp.rsync "tcp" false;
    coap = mkScheme wkp.udp.coap "udp" false;
    coaps = mkScheme wkp.udp.coaps "udp" true;
    irc = mkScheme wkp.tcp.irc "tcp" false;
    ircs = mkScheme wkp.tcp.ircs "tcp" true;
    xmpp = mkScheme wkp.tcp.xmpp "tcp" false;
  };

  mk = scheme: userinfo: host: portVal: path: query: fragment: {
    _type = "url";
    inherit
      scheme
      userinfo
      host
      path
      query
      fragment
      ;
    port = portVal;
  };

  # ===== Parsing =====

  # Split "[userinfo@]host[:port]" into { host; portStr }, or null.
  splitHostPort =
    hp:
    if parse'.startsWith "[" hp then
      let
        parts = parse'.splitOn "]" hp;
      in
      if builtins.length parts < 2 then
        null
      else
        let
          host = (builtins.elemAt parts 0) + "]";
          after = builtins.concatStringsSep "]" (builtins.tail parts);
        in
        if after == "" then
          {
            inherit host;
            portStr = null;
          }
        else if parse'.startsWith ":" after then
          {
            inherit host;
            portStr = parse'.stripPrefix ":" after;
          }
        else
          null
    else
      let
        parts = parse'.splitOn ":" hp;
        n = builtins.length parts;
      in
      if n == 1 then
        {
          host = hp;
          portStr = null;
        }
      else if n == 2 then
        {
          host = builtins.elemAt parts 0;
          portStr = builtins.elemAt parts 1;
        }
      else
        null;

  parseAuthority =
    a:
    let
      atParts = parse'.splitOn "@" a;
      nAt = builtins.length atParts;
    in
    if nAt > 2 then
      types.tryErr "libnet.url.parse: malformed userinfo (multiple '@')"
    else
      let
        userinfo = if nAt == 2 then builtins.elemAt atParts 0 else null;
        hostport = builtins.elemAt atParts (nAt - 1);
        hp = splitHostPort hostport;
      in
      if hp == null then
        types.tryErr "libnet.url.parse: malformed authority \"${a}\""
      else
        let
          hostRes = urlHost.tryParse hp.host;
          portRes = if hp.portStr == null then null else port.tryParse hp.portStr;
        in
        if !hostRes.success then
          types.tryErr "libnet.url.parse: invalid host \"${hp.host}\""
        else if portRes != null && !portRes.success then
          types.tryErr "libnet.url.parse: invalid port \"${hp.portStr}\""
        else
          types.tryOk {
            inherit userinfo;
            host = hostRes.value;
            port = if portRes == null then null else portRes.value;
          };

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.url.parse: input must be a string"
    else
      let
        schemeParts = parse'.splitOn "://" s;
      in
      if builtins.length schemeParts < 2 then
        types.tryErr "libnet.url.parse: missing \"<scheme>://\": \"${s}\""
      else
        let
          rawScheme = builtins.elemAt schemeParts 0;
          scheme = lowerAscii rawScheme;
          rest = builtins.concatStringsSep "://" (builtins.tail schemeParts);
        in
        if !(builtins.hasAttr scheme schemes) then
          types.tryErr "libnet.url.parse: unknown scheme \"${rawScheme}\": \"${s}\""
        else
          let
            fragParts = parse'.splitOn "#" rest;
            beforeFrag = builtins.elemAt fragParts 0;
            fragment =
              if builtins.length fragParts > 1 then
                builtins.concatStringsSep "#" (builtins.tail fragParts)
              else
                null;
            queryParts = parse'.splitOn "?" beforeFrag;
            beforeQuery = builtins.elemAt queryParts 0;
            query =
              if builtins.length queryParts > 1 then
                builtins.concatStringsSep "?" (builtins.tail queryParts)
              else
                null;
            slashParts = parse'.splitOn "/" beforeQuery;
            authority = builtins.elemAt slashParts 0;
            path =
              if builtins.length slashParts > 1 then
                "/" + builtins.concatStringsSep "/" (builtins.tail slashParts)
              else
                "";
            authR = parseAuthority authority;
          in
          if !authR.success then
            authR
          else
            types.tryOk (mk scheme authR.value.userinfo authR.value.host authR.value.port path query fragment);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    u:
    let
      ui = if u.userinfo == null then "" else "${u.userinfo}@";
      pt = if u.port == null then "" else ":${port.toString u.port}";
      q = if u.query == null then "" else "?${u.query}";
      f = if u.fragment == null then "" else "#${u.fragment}";
    in
    "${u.scheme}://${ui}${urlHost.toString u.host}${pt}${u.path}${q}${f}";

  # ===== Construction =====

  # `make` takes primitives (strings + an int port), not tagged values:
  # a URL is built from its textual parts, and 5 of its 7 fields
  # (scheme/userinfo/path/query/fragment) are plain strings with no
  # tagged type — so a string `host` + int `port` keep the attrset
  # internally consistent. Pass a string URL to `parse` if you have one.
  make =
    {
      scheme,
      host,
      port ? null,
      userinfo ? null,
      path ? "",
      query ? null,
      fragment ? null,
    }:
    let
      sch = lowerAscii scheme;
      h = urlHost.tryParse host;
    in
    if !(builtins.hasAttr sch schemes) then
      builtins.throw "libnet.url.make: unknown scheme \"${scheme}\""
    else if !h.success then
      builtins.throw "libnet.url.make: invalid host \"${host}\""
    else if port != null && !(builtins.isInt port) then
      builtins.throw "libnet.url.make: port must be an int or null"
    else
      mk sch userinfo h.value (if port == null then null else mkPort port) path query fragment;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isUrl;
  isSecure = u: schemes.${u.scheme}.secure;

  # ===== Accessors =====

  defaultPort = u: schemes.${u.scheme}.defaultPort;
  effectivePort = u: if u.port != null then u.port else mkPort schemes.${u.scheme}.defaultPort;

  # ===== Conversions =====

  # Host + effective port → the L4 connect target. Throws for reg-name
  # hosts that aren't valid DNS names (no endpoint exists for them).
  toEndpoint =
    u:
    let
      h = u.host;
      ep = effectivePort u;
    in
    if urlHost.isIp h then
      ipEndpoint.make h.ip ep
    else
      let
        hostVal = urlHost.toHost h;
      in
      if hostVal == null then
        builtins.throw "libnet.url.toEndpoint: reg-name host \"${h.name}\" is not a valid DNS name"
      else
        dnsEndpoint.make hostVal ep;

  # ===== Comparison =====

  cmpStr =
    x: y:
    if x < y then
      -1
    else if x > y then
      1
    else
      0;

  cmpOpt =
    x: y:
    if x == null && y == null then
      0
    else if x == null then
      -1
    else if y == null then
      1
    else
      cmpStr x y;

  eq =
    a: b:
    a.scheme == b.scheme
    && urlHost.eq a.host b.host
    && port.eq (effectivePort a) (effectivePort b)
    && a.path == b.path
    && a.query == b.query
    && a.fragment == b.fragment;

  compare =
    a: b:
    if a.scheme != b.scheme then
      cmpStr a.scheme b.scheme
    else
      let
        hc = urlHost.compare a.host b.host;
      in
      if hc != 0 then
        hc
      else
        let
          pc = port.compare (effectivePort a) (effectivePort b);
        in
        if pc != 0 then
          pc
        else
          let
            pathc = cmpStr a.path b.path;
          in
          if pathc != 0 then
            pathc
          else
            let
              qc = cmpOpt a.query b.query;
            in
            if qc != 0 then qc else cmpOpt a.fragment b.fragment;

  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;
in
{
  inherit
    parse
    tryParse
    toString
    make
    ;
  inherit isValid is isSecure;
  inherit defaultPort effectivePort;
  inherit toEndpoint;
  inherit
    eq
    lt
    le
    gt
    ge
    compare
    min
    max
    ;
  inherit schemes;
  # Field accessors. `port` / `transport` are declared inline to avoid
  # shadowing the imported modules of the same name.
  scheme = u: u.scheme;
  userinfo = u: u.userinfo;
  host = u: u.host;
  path = u: u.path;
  query = u: u.query;
  fragment = u: u.fragment;
  port = u: u.port;
  transport = u: transport.parse schemes.${u.scheme}.transport;
}
