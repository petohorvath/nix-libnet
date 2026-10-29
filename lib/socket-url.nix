/*
  libnet.socketUrl

  A socket address in URL form: `<scheme>://<endpoint>`. A bounded
  composition of a socket scheme and an `endpoint`, *not* a general URL
  parser
  (no userinfo, query, fragment, percent-encoding, or relative
  resolution; see docs/adr/0011). For the TLS-secured peer
  (`tls`/`ssl`/`dtls`/`quic`), see `secureSocketUrl`.

  Schemes:
  - `tcp` / `udp` / `sctp` → an IP or DNS endpoint follows
    (`tcp://1.2.3.4:80`, `udp://[::]:53`, `sctp://pool.ntp.org:9999`).
  - `unix` → a socket path follows (`unix:///run/foo.sock`,
    `unix://@abstract`); no port.

  Schemes match case-insensitively and are emitted lowercase, and sort
  by name (sctp < tcp < udp < unix).

  Stored as the canonical scheme and the endpoint, like every URL form;
  `transport` derives from the scheme:

    { _type = "socketUrl"; scheme = <"sctp" | "tcp" | "udp" | "unix">;
      endpoint = <endpoint>; }

  Invariant: `scheme == "unix"` iff `endpoint` is a `unixSocket`. A
  Unix socket has no L4 transport.

  Example:
    libnet.socketUrl.parse "tcp://1.2.3.4:80"
    => { _type = "socketUrl"; scheme = "tcp"; endpoint = <ipEndpoint>; }

    libnet.socketUrl.toString (libnet.socketUrl.parse "unix:///run/foo.sock")
    => "unix:///run/foo.sock"
*/
let
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  transport = import ./transport.nix;
  endpoint = import ./endpoint.nix;

  lowerAscii = dnsLabel.toLowerAscii;

  unixScheme = "unix";

  # Closed registry of socket schemes, `scheme -> { transport; secure; }`.
  # `unix` has no transport, and no scheme's protocol encrypts the
  # connection.
  schemes = {
    sctp = {
      transport = "sctp";
      secure = false;
    };
    tcp = {
      transport = "tcp";
      secure = false;
    };
    udp = {
      transport = "udp";
      secure = false;
    };
    unix = {
      transport = null;
      secure = false;
    };
  };

  schemeHint = "expected tcp, udp, sctp, or unix";

  mk = schemeName: endpointValue: {
    _type = "socketUrl";
    scheme = schemeName;
    endpoint = endpointValue;
  };

  # Check the socketUrl argument of `function`, throwing for any other
  # kind.
  socketUrlArgument = function: errors.expectKind "socketUrl.${function}" "socketUrl";

  # ===== Parsing =====

  /*
    Parse a socket URL: the detail parser of the parsing suite.

    `input`: `<scheme>://<endpoint>` string; `tcp`, `udp`, and `sctp`
    take `host:port`, `unix` takes a socket path;
    the scheme is matched case-insensitively.

    Returns a tryResult holding a socketUrl value, or the detail of the
    failure. An unknown scheme is reported before an invalid address.
  */
  tryParseDetail =
    input:
    let
      parts = parsing.splitOn "://" input;
    in
    if builtins.length parts < 2 then
      types.tryErr "missing '<scheme>://': \"${input}\""
    else
      let
        rawScheme = builtins.elemAt parts 0;
        schemeName = lowerAscii rawScheme;
        # Rejoin the remainder so a stray '://' inside a path is kept.
        rest = builtins.concatStringsSep "://" (builtins.tail parts);
      in
      if !(schemes ? ${schemeName}) then
        types.tryErr "unknown scheme \"${rawScheme}\" (${schemeHint})"
      else
        let
          endpointResult = endpoint.tryParseDetail rest;
          endpointValue = endpointResult.value;
        in
        if !endpointResult.success then
          endpointResult
        else if schemeName == unixScheme then
          if types.isUnixSocket endpointValue then
            types.tryOk (mk schemeName endpointValue)
          else
            types.tryErr "'unix://' requires a socket path: \"${input}\""
        else if types.isUnixSocket endpointValue then
          types.tryErr "'${schemeName}://' requires host:port, not a socket path: \"${input}\""
        else
          types.tryOk (mk schemeName endpointValue);

  parsers = parsing.suite "socketUrl" tryParseDetail;

  /*
    Render a socket URL in canonical text form.

    `socketUrl`: socketUrl value.

    Returns `<scheme>://<endpoint>`, such as "tcp://1.2.3.4:80" or
    "unix:///run/foo.sock".
  */
  toString =
    socketUrl:
    let
      checked = socketUrlArgument "toString" socketUrl;
    in
    "${checked.scheme}://${endpoint.toString checked.endpoint}";

  # ===== Construction =====

  /*
    Build a socket URL from a scheme and an already-parsed endpoint, as
    `parse` would.

    `schemeName`: `tcp`, `udp`, `sctp`, or `unix`, matched
    case-insensitively and stored lowercase.
    `endpointValue`: a unixSocket value for `unix`, otherwise an
    ipEndpoint or dnsEndpoint value.

    Returns a socketUrl value; throws on a non-string or unknown scheme,
    a non-endpoint value, or an endpoint that does not match the scheme.
  */
  make =
    schemeName: endpointValue:
    let
      caller = "socketUrl.make";
      canonicalScheme = lowerAscii (errors.expectType caller "string" schemeName);
      checked =
        errors.expect caller "ipEndpoint, dnsEndpoint or unixSocket value" endpoint.is
          endpointValue;
      expectedEndpoint =
        if canonicalScheme == unixScheme then "unixSocket value" else "ipEndpoint or dnsEndpoint value";
    in
    if !(schemes ? ${canonicalScheme}) then
      errors.fail caller "unknown scheme \"${schemeName}\" (${schemeHint})"
    else if (canonicalScheme == unixScheme) != types.isUnixSocket checked then
      errors.fail caller "expected ${expectedEndpoint} for scheme \"${canonicalScheme}\", got ${errors.describe checked}"
    else
      mk canonicalScheme checked;

  # ===== Predicates =====

  /*
    Check whether a value is a socketUrl value.

    `value`: any value; non-attrsets are accepted and yield false.

    Returns true for an attrset tagged `_type = "socketUrl"`, false
    otherwise; other fields are not checked.
  */
  is = value: types.isSocketUrl value;

  /*
    Check whether a socket URL addresses a Unix socket.

    `socketUrl`: socketUrl value.

    Returns true for the `unix` scheme.
  */
  isUnix = socketUrl: (socketUrlArgument "isUnix" socketUrl).scheme == unixScheme;

  /*
    Check whether a socket URL's scheme is secure: its protocol encrypts
    the connection, per the scheme registry.

    `socketUrl`: socketUrl value.

    Returns false; no socket scheme encrypts (see `secureSocketUrl`).
  */
  isSecure = socketUrl: schemes.${(socketUrlArgument "isSecure" socketUrl).scheme}.secure;

  # ===== Accessors =====

  /*
    Get the canonical scheme of a socket URL.

    `socketUrl`: socketUrl value.

    Returns "sctp", "tcp", "udp", or "unix".
  */
  scheme = socketUrl: (socketUrlArgument "scheme" socketUrl).scheme;

  # ===== Comparison =====
  #
  # Sorted by scheme name (sctp < tcp < udp < unix), for determinism
  # only, then by endpoint. Each ordering function passes its own name,
  # which its errors report.

  compareFor =
    function: a: b:
    let
      left = socketUrlArgument function a;
      right = socketUrlArgument function b;
    in
    comparison.lexicographic [
      (comparison.order left.scheme right.scheme)
      (endpoint.compare left.endpoint right.endpoint)
    ];

  ordering = comparison.suite compareFor;

  /*
    Compare two socket URLs for equality.

    `a`, `b`: values to compare.

    Returns true when the type tags, schemes, and endpoints match; false
    for any other value.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.socketUrl a b
    && a.scheme == b.scheme
    && endpoint.eq a.endpoint b.endpoint;
in
{
  inherit
    eq
    is
    isSecure
    isUnix
    make
    scheme
    schemes
    toString
    ;
  inherit (parsers)
    isValid
    parse
    tryParse
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

  # Defined here rather than in `let`, where `transport` and `endpoint` name
  # the imported modules.
  /*
    Get the transport of a socket URL, derived from its scheme.

    `socketUrl`: socketUrl value.

    Returns the transport value, or null for the `unix` scheme.
  */
  transport =
    socketUrl:
    let
      transportName = schemes.${(socketUrlArgument "transport" socketUrl).scheme}.transport;
    in
    if transportName == null then null else transport.parse transportName;

  /*
    Get the endpoint of a socket URL.

    `socketUrl`: socketUrl value.

    Returns the endpoint value (ipEndpoint, dnsEndpoint, or unixSocket).
  */
  endpoint = socketUrl: (socketUrlArgument "endpoint" socketUrl).endpoint;
}
