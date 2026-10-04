/*
  libnet.secureSocketUrl

  A TLS-secured socket address in URL form: `<scheme>://<endpoint>`.
  The secured peer of `socketUrl` — same `scheme://host:port` shape, but
  every scheme implies TLS. Not a general URL parser (no userinfo, path,
  query, fragment, or percent-encoding; see `url` for that).

  Schemes (a closed registry; `secure` is therefore always true):
  - `tls` — TLS over TCP (`tls://1.2.3.4:443`). `ssl` is accepted on
    input as an alias and canonicalizes to `tls`.
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
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  # Suffixed so the exported `endpoint` / `transport` accessors can keep
  # their names in this scope.
  endpoint = import ./endpoint.nix;
  transport = import ./transport.nix;

  lowerAscii = dnsLabel.toLowerAscii;

  # Closed registry of secured schemes, `scheme -> { transport }`. Every
  # scheme is TLS-secured, so `secure` is a constant of the type rather
  # than a per-scheme field.
  schemes = {
    tls = {
      transport = "tcp";
    };
    dtls = {
      transport = "udp";
    };
    quic = {
      transport = "udp";
    };
  };

  # Input aliases that canonicalize to a registry scheme. `ssl` is the
  # obsolete spelling of `tls`; both mean TLS-over-TCP.
  aliases = {
    ssl = "tls";
  };

  canonicalizeScheme = schemeName: aliases.${schemeName} or schemeName;

  schemeHint = "expected tls/ssl, dtls, or quic";

  mk = canonicalScheme: endpointValue: {
    _type = "secureSocketUrl";
    scheme = canonicalScheme;
    endpoint = endpointValue;
  };

  # ===== Parsing =====

  /*
    Parse a secure socket URL without throwing, for callers that want to
    report or recover from invalid input.

    `input`: `<scheme>://<host>:<port>` string. The scheme is `tls`,
    `ssl` (alias of `tls`), `dtls`, or `quic`, matched
    case-insensitively; the port is required.

    Returns a tryResult: `{ success = true; value; }` with a
    secureSocketUrl value, or `{ success = false; error; }` describing
    the problem.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.secureSocketUrl.parse: input must be a string"
    else
      let
        parts = parsing.splitOn "://" input;
      in
      if builtins.length parts < 2 then
        types.tryErr "libnet.secureSocketUrl.parse: missing '<scheme>://': \"${input}\""
      else
        let
          rawScheme = builtins.elemAt parts 0;
          canonicalScheme = canonicalizeScheme (lowerAscii rawScheme);
          # Rejoin the remainder so a stray '://' is kept (and then
          # rejected by the endpoint parser).
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
        in
        if !(builtins.hasAttr canonicalScheme schemes) then
          types.tryErr "libnet.secureSocketUrl.parse: unknown scheme \"${rawScheme}\" (${schemeHint})"
        else
          let
            endpointResult = endpoint.tryParse rest;
          in
          if !endpointResult.success then
            types.tryErr "libnet.secureSocketUrl.parse: invalid address in \"${input}\""
          else if types.isUnixSocket endpointResult.value then
            types.tryErr "libnet.secureSocketUrl.parse: '${canonicalScheme}://' needs host:port, not a socket path: \"${input}\""
          else
            types.tryOk (mk canonicalScheme endpointResult.value);

  /*
    Parse a secure socket URL.

    `input`: `<scheme>://<host>:<port>` string. The scheme is `tls`,
    `ssl` (alias of `tls`), `dtls`, or `quic`, matched
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
    secureSocketUrl: "${secureSocketUrl.scheme}://${endpoint.toString secureSocketUrl.endpoint}";

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
    if !(builtins.isString inputScheme) then
      throw "libnet.secureSocketUrl.make: scheme must be a string"
    else
      let
        canonicalScheme = canonicalizeScheme (lowerAscii inputScheme);
      in
      if !(builtins.hasAttr canonicalScheme schemes) then
        throw "libnet.secureSocketUrl.make: unknown scheme \"${inputScheme}\" (${schemeHint})"
      else if !(endpoint.is endpointValue) then
        throw "libnet.secureSocketUrl.make: expected an endpoint value"
      else if types.isUnixSocket endpointValue then
        throw "libnet.secureSocketUrl.make: a secure socket needs host:port, not a unix socket"
      else
        mk canonicalScheme endpointValue;

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
    Report whether a secure socket URL is TLS-secured, for code that
    handles it alongside other socket types.

    `_`: secureSocketUrl value (ignored).

    Returns true; every scheme in the registry is TLS-secured.
  */
  isSecure = _: true;

  # ===== Accessors =====

  /*
    Get the canonical scheme of a secure socket URL.

    `secureSocketUrl`: secureSocketUrl value.

    Returns "tls", "dtls", or "quic".
  */
  scheme = secureSocketUrl: secureSocketUrl.scheme;

  # ===== Comparison =====
  #
  # Sorted by a fixed scheme rank (tls < dtls < quic), then by endpoint.
  # Ranking on the scheme (not the derived transport) keeps `dtls` and
  # `quic` — both UDP — distinct.

  schemeRank =
    canonicalScheme:
    if canonicalScheme == "tls" then
      0
    else if canonicalScheme == "dtls" then
      1
    else
      2;

  /*
    Compare two secure socket URLs for equality.

    `a`, `b`: secureSocketUrl values.

    Returns true when the type tags, schemes, and endpoints match.
  */
  eq = a: b: a._type == b._type && a.scheme == b.scheme && endpoint.eq a.endpoint b.endpoint;

  /*
    Order two secure socket URLs by scheme (tls < dtls < quic), then by
    endpoint.

    `a`, `b`: secureSocketUrl values.

    Returns -1, 0, or 1 when `a` sorts before, equal to, or after `b`.
  */
  compare =
    a: b:
    let
      rankA = schemeRank a.scheme;
      rankB = schemeRank b.scheme;
    in
    if rankA < rankB then
      -1
    else if rankA > rankB then
      1
    else
      endpoint.compare a.endpoint b.endpoint;

  /*
    Test whether `a` sorts strictly before `b`.

    `a`, `b`: secureSocketUrl values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` sorts before or equal to `b`.

    `a`, `b`: secureSocketUrl values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` sorts strictly after `b`.

    `a`, `b`: secureSocketUrl values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` sorts after or equal to `b`.

    `a`, `b`: secureSocketUrl values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two secure socket URLs.

    `a`, `b`: secureSocketUrl values.

    Returns the one that sorts first; `a` when they are equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two secure socket URLs.

    `a`, `b`: secureSocketUrl values.

    Returns the one that sorts last; `a` when they are equal.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    aliases
    compare
    eq
    ge
    gt
    is
    isSecure
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

  /*
    Get the endpoint of a secure socket URL.

    `secureSocketUrl`: secureSocketUrl value.

    Returns the ipEndpoint or dnsEndpoint value.
  */
  endpoint = secureSocketUrl: secureSocketUrl.endpoint;

  /*
    Get the transport a secure socket URL runs over, derived from its
    scheme.

    `secureSocketUrl`: secureSocketUrl value.

    Returns the `tcp` transport for `tls`, `udp` for `dtls` and `quic`.
  */
  transport = secureSocketUrl: transport.parse schemes.${secureSocketUrl.scheme}.transport;
}
