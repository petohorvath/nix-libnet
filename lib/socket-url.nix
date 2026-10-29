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
  socketUrlOf = function: errors.expectKind "socketUrl.${function}" "socketUrl";

  parseError = detail: types.tryErr (errors.message "socketUrl.parse" detail);

  # ===== Parsing =====

  /*
    Parse a socket URL without throwing, for callers that want to report
    or recover from invalid input.

    `input`: `<scheme>://<endpoint>` string; `tcp`, `udp`, and `sctp`
    take `host:port`, `unix` takes a socket path;
    the scheme is matched case-insensitively.

    Returns a tryResult: `{ success = true; value; }` with a socketUrl
    value, or `{ success = false; error; }` naming `socketUrl.parse`. An
    unknown scheme is reported before an invalid address.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else
      let
        parts = parsing.splitOn "://" input;
      in
      if builtins.length parts < 2 then
        parseError "missing '<scheme>://': \"${input}\""
      else
        let
          rawScheme = builtins.elemAt parts 0;
          schemeName = lowerAscii rawScheme;
          # Rejoin the remainder so a stray '://' inside a path is kept.
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
        in
        if !(schemes ? ${schemeName}) then
          parseError "unknown scheme \"${rawScheme}\" (${schemeHint})"
        else
          let
            endpointResult = endpoint.tryParse rest;
            endpointValue = endpointResult.value;
          in
          if !endpointResult.success then
            parseError (errors.detail "endpoint.parse" endpointResult.error)
          else if schemeName == unixScheme then
            if types.isUnixSocket endpointValue then
              types.tryOk (mk schemeName endpointValue)
            else
              parseError "'unix://' requires a socket path: \"${input}\""
          else if types.isUnixSocket endpointValue then
            parseError "'${schemeName}://' requires host:port, not a socket path: \"${input}\""
          else
            types.tryOk (mk schemeName endpointValue);

  /*
    Parse a socket URL.

    `input`: `<scheme>://<endpoint>` string; `tcp`, `udp`, and `sctp`
    take `host:port`, `unix` takes a socket path;
    the scheme is matched case-insensitively.

    Returns a socketUrl value; throws on malformed input, an unknown
    scheme, or a scheme that does not match the address kind.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a socket URL in canonical text form.

    `socketUrl`: socketUrl value.

    Returns `<scheme>://<endpoint>`, such as "tcp://1.2.3.4:80" or
    "unix:///run/foo.sock".
  */
  toString =
    socketUrl:
    let
      checked = socketUrlOf "toString" socketUrl;
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
    Check whether a string parses as a socket URL, without throwing.

    `input`: value to check.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

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
  isUnix = socketUrl: (socketUrlOf "isUnix" socketUrl).scheme == unixScheme;

  /*
    Check whether a socket URL's scheme is secure: its protocol encrypts
    the connection, per the scheme registry.

    `socketUrl`: socketUrl value.

    Returns false; no socket scheme encrypts (see `secureSocketUrl`).
  */
  isSecure = socketUrl: schemes.${(socketUrlOf "isSecure" socketUrl).scheme}.secure;

  # ===== Accessors =====

  /*
    Get the canonical scheme of a socket URL.

    `socketUrl`: socketUrl value.

    Returns "sctp", "tcp", "udp", or "unix".
  */
  scheme = socketUrl: (socketUrlOf "scheme" socketUrl).scheme;

  # ===== Comparison =====
  #
  # Sorted by scheme name (sctp < tcp < udp < unix), for determinism
  # only, then by endpoint. Each ordering function passes its own name,
  # which its errors report.

  compareFor =
    function: a: b:
    let
      left = socketUrlOf function a;
      right = socketUrlOf function b;
    in
    if left.scheme < right.scheme then
      -1
    else if left.scheme > right.scheme then
      1
    else
      endpoint.compare left.endpoint right.endpoint;

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

  /*
    Order two socket URLs by scheme name (sctp < tcp < udp < unix), then
    by endpoint.

    `a`, `b`: socketUrl values.

    Returns -1, 0, or 1 when `a` sorts before, equal to, or after `b`.
  */
  compare = compareFor "compare";

  /*
    Test whether `a` sorts strictly before `b`.

    `a`, `b`: socketUrl values.

    Returns a Boolean.
  */
  lt = a: b: compareFor "lt" a b == -1;

  /*
    Test whether `a` sorts before or equal to `b`.

    `a`, `b`: socketUrl values.

    Returns a Boolean.
  */
  le = a: b: compareFor "le" a b <= 0;

  /*
    Test whether `a` sorts strictly after `b`.

    `a`, `b`: socketUrl values.

    Returns a Boolean.
  */
  gt = a: b: compareFor "gt" a b == 1;

  /*
    Test whether `a` sorts after or equal to `b`.

    `a`, `b`: socketUrl values.

    Returns a Boolean.
  */
  ge = a: b: compareFor "ge" a b >= 0;

  /*
    Pick the lesser of two socket URLs.

    `a`, `b`: socketUrl values.

    Returns the one that sorts first; `a` when they are equal.
  */
  min = a: b: if compareFor "min" a b <= 0 then a else b;

  /*
    Pick the greater of two socket URLs.

    `a`, `b`: socketUrl values.

    Returns the one that sorts last; `a` when they are equal.
  */
  max = a: b: if compareFor "max" a b >= 0 then a else b;
in
{
  inherit
    compare
    eq
    ge
    gt
    is
    isSecure
    isUnix
    isValid
    le
    lt
    make
    max
    min
    parse
    scheme
    schemes
    toString
    tryParse
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
      transportName = schemes.${(socketUrlOf "transport" socketUrl).scheme}.transport;
    in
    if transportName == null then null else transport.parse transportName;

  /*
    Get the endpoint of a socket URL.

    `socketUrl`: socketUrl value.

    Returns the endpoint value (ipEndpoint, dnsEndpoint, or unixSocket).
  */
  endpoint = socketUrl: (socketUrlOf "endpoint" socketUrl).endpoint;
}
