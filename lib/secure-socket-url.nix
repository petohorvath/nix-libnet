/*
  libnet.secureSocketUrl

  A TLS-secured socket address in URL form: `<scheme>://<endpoint>`.
  The secured peer of `socketUrl` — same `scheme://host:port` shape, but
  every scheme implies TLS. Not a general URL parser (no userinfo, path,
  query, fragment, or percent-encoding; see `url` for that).

  Schemes (a closed registry, every one TLS-secured):
  - `tls` — TLS over TCP (`tls://1.2.3.4:443`). `ssl` is accepted on
    input as another spelling and canonicalizes to `tls`.
  - `dtls` — DTLS over UDP (`dtls://[::1]:5684`).
  - `quic` — QUIC over UDP (`quic://example.com:443`); QUIC mandates
    TLS 1.3, so it has no plaintext form.

  The scheme is the stored identity (with `transport` derived from it),
  because `dtls` and `quic` are both "UDP + TLS" and a transport-plus-flag
  representation could not tell them apart. There is no `unix` scheme and
  no scheme-default port — the endpoint always carries an explicit port.

    { _type = "secureSocketUrl"; scheme = <"tls" | "dtls" | "quic">;
      endpoint = <ipEndpoint | dnsEndpoint>; }

  Example:
    libnet.secureSocketUrl.parse "tls://1.2.3.4:443"
    => { _type = "secureSocketUrl"; scheme = "tls"; endpoint = <ipEndpoint>; }

    libnet.secureSocketUrl.toString (libnet.secureSocketUrl.parse "ssl://h:443")
    => "tls://h:443"
*/
let
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  endpoint = import ./endpoint.nix;
  transport = import ./transport.nix;

  lowerAscii = dnsLabel.toLowerAscii;

  # Closed registry of secured schemes, `scheme -> { transport; secure; }`.
  # Every scheme's protocol encrypts the connection with TLS.
  schemes = {
    dtls = {
      transport = "udp";
      secure = true;
    };
    quic = {
      transport = "udp";
      secure = true;
    };
    tls = {
      transport = "tcp";
      secure = true;
    };
  };

  # Input spellings that canonicalize to a registry scheme. `ssl` is the
  # obsolete spelling of `tls`; both mean TLS-over-TCP.
  inputSpellings = {
    ssl = "tls";
  };

  canonicalizeScheme = schemeName: inputSpellings.${schemeName} or schemeName;

  schemeHint = "expected tls/ssl, dtls, or quic";

  # Force both fields, so a constructor throws for a bad argument when
  # it builds the value rather than when a field is read.
  mk =
    canonicalScheme: endpointValue:
    builtins.seq canonicalScheme (
      builtins.seq endpointValue {
        _type = "secureSocketUrl";
        scheme = canonicalScheme;
        endpoint = endpointValue;
      }
    );

  isNetworkEndpoint = value: types.isIpEndpoint value || types.isDnsEndpoint value;

  # Check the secureSocketUrl argument of `function`, throwing for any
  # other kind.
  secureSocketUrlArgument =
    function: errors.expectKind "secureSocketUrl.${function}" "secureSocketUrl";

  parseError = detail: types.tryErr (errors.message "secureSocketUrl.parse" detail);

  # ===== Parsing =====

  /*
    Parse a secure socket URL without throwing, for callers that want to
    report or recover from invalid input.

    `input`: `<scheme>://<host>:<port>` string. The scheme is `tls`,
    `ssl` (read as `tls`), `dtls`, or `quic`, matched
    case-insensitively; the port is required.

    Returns a tryResult: `{ success = true; value; }` with a
    secureSocketUrl value, or `{ success = false; error; }` describing
    the problem.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError (errors.notString input)
    else
      let
        parts = parsing.splitOn "://" input;
      in
      if builtins.length parts < 2 then
        parseError "missing '<scheme>://': \"${input}\""
      else
        let
          rawScheme = builtins.elemAt parts 0;
          canonicalScheme = canonicalizeScheme (lowerAscii rawScheme);
          # Rejoin the remainder so a stray '://' is kept (and then
          # rejected by the endpoint parser).
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
        in
        if !(schemes ? ${canonicalScheme}) then
          parseError "unknown scheme \"${rawScheme}\" (${schemeHint})"
        else
          let
            endpointResult = endpoint.tryParse rest;
          in
          if !endpointResult.success then
            parseError (errors.detail "endpoint.parse" endpointResult.error)
          else if types.isUnixSocket endpointResult.value then
            parseError "'${canonicalScheme}://' needs host:port, not a socket path: \"${input}\""
          else
            types.tryOk (mk canonicalScheme endpointResult.value);

  /*
    Parse a secure socket URL.

    `input`: `<scheme>://<host>:<port>` string. The scheme is `tls`,
    `ssl` (read as `tls`), `dtls`, or `quic`, matched
    case-insensitively; the port is required.

    Returns a secureSocketUrl value with the canonical scheme; throws on
    malformed input, an unknown scheme, or a socket path.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a secure socket URL in canonical text form.

    `secureSocketUrl`: secureSocketUrl value.

    Returns `<scheme>://<endpoint>` with the canonical scheme, such as
    "tls://1.2.3.4:443".
  */
  toString =
    secureSocketUrl:
    let
      checked = secureSocketUrlArgument "toString" secureSocketUrl;
    in
    "${checked.scheme}://${endpoint.toString checked.endpoint}";

  # ===== Construction =====

  /*
    Build a secure socket URL from a scheme and an already-parsed
    endpoint.

    `inputScheme`: `tls`, `ssl`, `dtls`, or `quic`, matched
    case-insensitively and canonicalized.
    `endpointValue`: ipEndpoint or dnsEndpoint value.

    Returns a secureSocketUrl value; throws on a non-string or unknown
    scheme, a non-endpoint value, or a unixSocket endpoint.
  */
  make =
    inputScheme: endpointValue:
    let
      caller = "secureSocketUrl.make";
      canonicalScheme = canonicalizeScheme (lowerAscii (errors.expectType caller "string" inputScheme));
    in
    if !(schemes ? ${canonicalScheme}) then
      errors.fail caller "unknown scheme \"${inputScheme}\" (${schemeHint})"
    else
      mk canonicalScheme (
        errors.expect caller "ipEndpoint or dnsEndpoint value" isNetworkEndpoint endpointValue
      );

  # ===== Predicates =====

  /*
    Check whether a string parses as a secure socket URL, without
    throwing.

    `input`: value to check.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a secureSocketUrl value.

    `value`: any value; non-attrsets are accepted and yield false.

    Returns true for an attrset tagged `_type = "secureSocketUrl"`, false
    otherwise; other fields are not checked.
  */
  is = value: types.isSecureSocketUrl value;

  /*
    Check whether a secure socket URL's scheme is secure: its protocol
    encrypts the connection, per the scheme registry.

    `secureSocketUrl`: secureSocketUrl value.

    Returns true; every scheme in the registry encrypts with TLS.
  */
  isSecure =
    secureSocketUrl: schemes.${(secureSocketUrlArgument "isSecure" secureSocketUrl).scheme}.secure;

  # ===== Accessors =====

  /*
    Get the canonical scheme of a secure socket URL.

    `secureSocketUrl`: secureSocketUrl value.

    Returns "dtls", "quic", or "tls".
  */
  scheme = secureSocketUrl: (secureSocketUrlArgument "scheme" secureSocketUrl).scheme;

  # ===== Comparison =====
  #
  # Sorted by scheme name (dtls < quic < tls), for determinism only, then
  # by endpoint. Comparing the scheme (not the derived transport) keeps
  # `dtls` and `quic` — both UDP — distinct. Each ordering function
  # passes its own name, which its errors report.

  compareFor =
    function: a: b:
    let
      left = secureSocketUrlArgument function a;
      right = secureSocketUrlArgument function b;
    in
    comparison.lexicographic [
      (comparison.order left.scheme right.scheme)
      (endpoint.compare left.endpoint right.endpoint)
    ];

  ordering = comparison.suite compareFor;

  /*
    Compare two secure socket URLs for equality.

    `a`, `b`: values to compare.

    Returns true when the type tags, schemes, and endpoints match; false
    for any other value.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.secureSocketUrl a b
    && a.scheme == b.scheme
    && endpoint.eq a.endpoint b.endpoint;
in
{
  inherit
    eq
    is
    isSecure
    isValid
    make
    parse
    scheme
    schemes
    toString
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

  # Defined here rather than in `let`, where `endpoint` and `transport` name
  # the imported modules.
  /*
    Get the endpoint of a secure socket URL.

    `secureSocketUrl`: secureSocketUrl value.

    Returns the ipEndpoint or dnsEndpoint value.
  */
  endpoint = secureSocketUrl: (secureSocketUrlArgument "endpoint" secureSocketUrl).endpoint;

  /*
    Get the transport a secure socket URL runs over, derived from its
    scheme.

    `secureSocketUrl`: secureSocketUrl value.

    Returns the `tcp` transport for `tls`, `udp` for `dtls` and `quic`.
  */
  transport =
    secureSocketUrl:
    transport.parse schemes.${(secureSocketUrlArgument "transport" secureSocketUrl).scheme}.transport;
}
