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
  parse' = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
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

  canonical = s: aliases.${s} or s;

  schemeHint = "expected tls/ssl, dtls, or quic";

  mk = scheme: ep: {
    _type = "secureSocketUrl";
    inherit scheme;
    endpoint = ep;
  };

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.secureSocketUrl.parse: input must be a string"
    else
      let
        parts = parse'.splitOn "://" s;
      in
      if builtins.length parts < 2 then
        types.tryErr "libnet.secureSocketUrl.parse: missing '<scheme>://': \"${s}\""
      else
        let
          rawScheme = builtins.elemAt parts 0;
          scheme = canonical (lowerAscii rawScheme);
          # Rejoin the remainder so a stray '://' is kept (and then
          # rejected by the endpoint parser).
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
        in
        if !(builtins.hasAttr scheme schemes) then
          types.tryErr "libnet.secureSocketUrl.parse: unknown scheme \"${rawScheme}\" (${schemeHint})"
        else
          let
            epRes = endpoint.tryParse rest;
          in
          if !epRes.success then
            types.tryErr "libnet.secureSocketUrl.parse: invalid address in \"${s}\""
          else if types.isUnixSocket epRes.value then
            types.tryErr "libnet.secureSocketUrl.parse: '${scheme}://' needs host:port, not a socket path: \"${s}\""
          else
            types.tryOk (mk scheme epRes.value);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString = ssu: "${ssu.scheme}://${endpoint.toString ssu.endpoint}";

  # ===== Construction =====

  make =
    scheme: ep:
    let
      sch = canonical (lowerAscii scheme);
    in
    if !(builtins.isString scheme) then
      builtins.throw "libnet.secureSocketUrl.make: scheme must be a string"
    else if !(builtins.hasAttr sch schemes) then
      builtins.throw "libnet.secureSocketUrl.make: unknown scheme \"${scheme}\" (${schemeHint})"
    else if !(endpoint.is ep) then
      builtins.throw "libnet.secureSocketUrl.make: expected an endpoint value"
    else if types.isUnixSocket ep then
      builtins.throw "libnet.secureSocketUrl.make: a secure socket needs host:port, not a unix socket"
    else
      mk sch ep;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isSecureSocketUrl;
  # Every scheme in the registry is TLS-secured.
  isSecure = _ssu: true;

  # ===== Comparison =====
  #
  # Sorted by a fixed scheme rank (tls < dtls < quic), then by endpoint.
  # Ranking on the scheme (not the derived transport) keeps `dtls` and
  # `quic` — both UDP — distinct.

  schemeRank =
    scheme:
    if scheme == "tls" then
      0
    else if scheme == "dtls" then
      1
    else
      2;

  eq = a: b: a.scheme == b.scheme && endpoint.eq a.endpoint b.endpoint;

  compare =
    a: b:
    let
      ra = schemeRank a.scheme;
      rb = schemeRank b.scheme;
    in
    if ra < rb then
      -1
    else if ra > rb then
      1
    else
      endpoint.compare a.endpoint b.endpoint;

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
  inherit
    isValid
    is
    isSecure
    ;
  # `scheme` / `endpoint` / `transport` accessors declared inline to
  # avoid shadowing the imported modules of the same name. `transport`
  # is derived from the scheme via the registry.
  scheme = ssu: ssu.scheme;
  endpoint = ssu: ssu.endpoint;
  transport = ssu: transport.parse schemes.${ssu.scheme}.transport;
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
  inherit schemes aliases;
}
