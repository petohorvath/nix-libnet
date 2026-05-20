/*
  libnet.proxyUrl

  The address of a proxy server, in URL form: `<scheme>://<authority>`
  (`<scheme>://[userinfo@]host:port`) — e.g. `socks5://127.0.0.1:1080`,
  `http://user:pass@proxy.corp:8080`. A bounded composition of a proxy
  scheme and a `libnet.authority`, *not* a general URL parser.

  Schemes (closed registry): `http` / `https` (an HTTP proxy, reached
  plain or over TLS), `socks4` / `socks4a`, `socks5` / `socks5h` (the
  `a` / `h` variants resolve DNS at the proxy). Schemes match
  case-insensitively and are emitted lowercase. The port is required —
  proxy default ports are not standardized.

    { _type = "proxyUrl"; scheme = <scheme>; authority = <authority>; }

  Example:
    libnet.proxyUrl.parse "socks5://user:pass@10.0.0.1:1080"
    => { _type = "proxyUrl"; scheme = "socks5"; authority = <authority>; }
*/
let
  types = import ./internal/types.nix;
  parse' = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  authority = import ./authority.nix;

  lowerAscii = dnsLabel.toLowerAscii;

  schemes = [
    "http"
    "https"
    "socks4"
    "socks4a"
    "socks5"
    "socks5h"
  ];

  schemeHint = "expected http, https, socks4, socks4a, socks5, or socks5h";

  mk = scheme: auth: {
    _type = "proxyUrl";
    inherit scheme;
    authority = auth;
  };

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.proxyUrl.parse: input must be a string"
    else
      let
        parts = parse'.splitOn "://" s;
      in
      if builtins.length parts < 2 then
        types.tryErr "libnet.proxyUrl.parse: missing '<scheme>://': \"${s}\""
      else
        let
          rawScheme = builtins.elemAt parts 0;
          scheme = lowerAscii rawScheme;
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
        in
        if !(builtins.elem scheme schemes) then
          types.tryErr "libnet.proxyUrl.parse: unknown scheme \"${rawScheme}\" (${schemeHint})"
        else
          let
            authR = authority.tryParse rest;
          in
          if !authR.success then
            types.tryErr "libnet.proxyUrl.parse: invalid authority in \"${s}\""
          else if authority.port authR.value == null then
            types.tryErr "libnet.proxyUrl.parse: a proxy URL requires an explicit port: \"${s}\""
          else
            types.tryOk (mk scheme authR.value);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString = pu: "${pu.scheme}://${authority.toString pu.authority}";

  # ===== Construction =====

  make =
    scheme: auth:
    let
      sch = lowerAscii scheme;
    in
    if !(builtins.isString scheme) then
      builtins.throw "libnet.proxyUrl.make: scheme must be a string"
    else if !(builtins.elem sch schemes) then
      builtins.throw "libnet.proxyUrl.make: unknown scheme \"${scheme}\" (${schemeHint})"
    else if !(authority.is auth) then
      builtins.throw "libnet.proxyUrl.make: expected an authority value"
    else if authority.port auth == null then
      builtins.throw "libnet.proxyUrl.make: a proxy URL requires an explicit port"
    else
      mk sch auth;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isProxyUrl;

  # ===== Comparison =====
  #
  # Fixed scheme rank (http < https < socks4 < socks4a < socks5 <
  # socks5h), then by authority.

  schemeRank =
    scheme:
    if scheme == "http" then
      0
    else if scheme == "https" then
      1
    else if scheme == "socks4" then
      2
    else if scheme == "socks4a" then
      3
    else if scheme == "socks5" then
      4
    else
      5;

  eq = a: b: a.scheme == b.scheme && authority.eq a.authority b.authority;

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
      authority.compare a.authority b.authority;

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
  inherit isValid is;
  # `scheme` / `authority` accessors declared inline to avoid shadowing
  # the imported module of the same name.
  scheme = pu: pu.scheme;
  authority = pu: pu.authority;
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
}
