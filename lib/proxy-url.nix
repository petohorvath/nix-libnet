/*
  libnet.proxyUrl

  The address of a proxy server, in URL form: `<scheme>://<authority>`
  (`<scheme>://[userinfo@]host:port`) — e.g. `socks5://127.0.0.1:1080`,
  `http://user:pass@proxy.corp:8080`. A bounded composition of a proxy
  scheme and a `libnet.authority`, *not* a general URL parser.

  Schemes (closed registry): `http` / `https` (an HTTP proxy, reached
  plain or over TLS), `socks4` / `socks4a`, `socks5` / `socks5h` (the
  `a` / `h` variants resolve DNS at the proxy). Every scheme runs over
  TCP. Schemes match case-insensitively, are emitted lowercase, and sort
  by name. The port is required — proxy default ports are not
  standardized.

    { _type = "proxyUrl"; scheme = <scheme>; authority = <authority>; }

  Example:
    libnet.proxyUrl.parse "socks5://user:pass@10.0.0.1:1080"
    => { _type = "proxyUrl"; scheme = "socks5"; authority = <authority>; }
*/
let
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  authority = import ./authority.nix;
  urlHost = import ./url-host.nix;
  transport = import ./transport.nix;
  ipEndpoint = import ./ip-endpoint.nix;
  dnsEndpoint = import ./dns-endpoint.nix;

  lowerAscii = dnsLabel.toLowerAscii;

  # Closed registry of proxy schemes, `scheme -> { transport; secure; }`.
  # `secure` covers the client-to-proxy hop: only `https` reaches the
  # proxy over TLS; `socks5h`'s `h` means remote DNS, not TLS.
  mkScheme = secure: {
    transport = "tcp";
    inherit secure;
  };
  schemes = {
    http = mkScheme false;
    https = mkScheme true;
    socks4 = mkScheme false;
    socks4a = mkScheme false;
    socks5 = mkScheme false;
    socks5h = mkScheme false;
  };

  schemeHint = "expected http, https, socks4, socks4a, socks5, or socks5h";

  mk = schemeValue: authorityValue: {
    _type = "proxyUrl";
    scheme = schemeValue;
    authority = authorityValue;
  };

  # ===== Parsing =====

  /*
    Parse a proxy URL without throwing, for callers that branch on
    validity.

    `input`: `<scheme>://[userinfo@]host:port` text; the scheme is matched
    case-insensitively and nothing may follow the authority.

    Returns a tryResult: `{ success = true; value = <proxyUrl>; }` or
    `{ success = false; error = <string>; }` for an unknown scheme, an
    invalid authority, or a missing port. Never throws.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.proxyUrl.parse: input must be a string"
    else
      let
        parts = parsing.splitOn "://" input;
      in
      if builtins.length parts < 2 then
        types.tryErr "libnet.proxyUrl.parse: missing '<scheme>://': \"${input}\""
      else
        let
          rawScheme = builtins.elemAt parts 0;
          lowerScheme = lowerAscii rawScheme;
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
        in
        if !(schemes ? ${lowerScheme}) then
          types.tryErr "libnet.proxyUrl.parse: unknown scheme \"${rawScheme}\" (${schemeHint})"
        else
          let
            authorityResult = authority.tryParse rest;
          in
          if !authorityResult.success then
            types.tryErr "libnet.proxyUrl.parse: invalid authority in \"${input}\""
          else if authority.port authorityResult.value == null then
            types.tryErr "libnet.proxyUrl.parse: a proxy URL requires an explicit port: \"${input}\""
          else
            types.tryOk (mk lowerScheme authorityResult.value);

  /*
    Parse a proxy URL, for values that must be valid.

    `input`: proxy URL text as accepted by `tryParse`.

    Returns a proxyUrl value; throws on invalid input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a proxy URL as `<scheme>://<authority>`.

    `proxyUrl`: a proxyUrl value.

    Returns the text with the lowercase scheme.
  */
  toString = proxyUrl: "${proxyUrl.scheme}://${authority.toString proxyUrl.authority}";

  # ===== Construction =====

  /*
    Build a proxy URL from a scheme and an existing authority value.

    `schemeName`: a key of `schemes`, matched case-insensitively.
    `authorityValue`: an authority value that carries an explicit port.

    Returns a proxyUrl value with the scheme lowercased; throws on a
    non-string or unknown scheme, a non-authority value, or a missing port.
  */
  make =
    schemeName: authorityValue:
    if !(builtins.isString schemeName) then
      throw "libnet.proxyUrl.make: scheme must be a string"
    else
      let
        lowerScheme = lowerAscii schemeName;
      in
      if !(schemes ? ${lowerScheme}) then
        throw "libnet.proxyUrl.make: unknown scheme \"${schemeName}\" (${schemeHint})"
      else if !(authority.is authorityValue) then
        throw "libnet.proxyUrl.make: expected an authority value"
      else if authority.port authorityValue == null then
        throw "libnet.proxyUrl.make: a proxy URL requires an explicit port"
      else
        mk lowerScheme authorityValue;

  # ===== Predicates =====

  /*
    Check whether a string parses as a proxy URL.

    `input`: candidate proxy URL text.

    Returns true when `tryParse` succeeds.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a proxyUrl value.

    `value`: any value.

    Returns true for a proxyUrl-tagged attrset.
  */
  is = value: types.isProxyUrl value;

  /*
    Check whether the client-to-proxy hop uses TLS, per the scheme
    registry. Only `https` does; `http` and every SOCKS scheme (including
    `socks5h`, whose `h` means remote DNS) reach the proxy in plaintext.

    `proxyUrl`: a proxyUrl value.

    Returns true only for the `https` scheme.
  */
  isSecure = proxyUrl: schemes.${proxyUrl.scheme}.secure;

  # ===== Accessors =====

  /*
    Get the scheme of a proxy URL.

    `proxyUrl`: a proxyUrl value.

    Returns the lowercase scheme string.
  */
  scheme = proxyUrl: proxyUrl.scheme;

  /*
    Get the userinfo of a proxy URL.

    `proxyUrl`: a proxyUrl value.

    Returns the authority's raw userinfo string, or null when absent.
  */
  userinfo = proxyUrl: proxyUrl.authority.userinfo;

  /*
    Get the host of a proxy URL.

    `proxyUrl`: a proxyUrl value.

    Returns the authority's host: an ipv4, ipv6, or regName value.
  */
  host = proxyUrl: proxyUrl.authority.host;

  # ===== Conversions =====

  /*
    Convert a proxy URL to the L4 connect target for its host and port.

    `proxyUrl`: a proxyUrl value.

    Returns an ipEndpoint for IP hosts or a dnsEndpoint for registered
    names that are valid DNS names; throws for other registered names,
    which have no endpoint.
  */
  toEndpoint =
    proxyUrl:
    let
      hostValue = host proxyUrl;
      targetPort = proxyUrl.authority.port;
    in
    if urlHost.isIp hostValue then
      ipEndpoint.make hostValue targetPort
    else
      let
        dnsHost = urlHost.toHost hostValue;
      in
      if dnsHost == null then
        throw "libnet.proxyUrl.toEndpoint: registered name \"${urlHost.toString hostValue}\" is not a valid DNS name"
      else
        dnsEndpoint.make dnsHost targetPort;

  # ===== Comparison =====
  #
  # Sorted by scheme name, for determinism only, then by authority.

  /*
    Test two proxy URLs for equality.

    `a`, `b`: proxyUrl values.

    Returns true when the schemes match exactly (`socks5` differs from
    `socks5h`) and the authorities are equal, including userinfo.
  */
  eq = a: b: types.hasSameTag a b && a.scheme == b.scheme && authority.eq a.authority b.authority;

  /*
    Order two proxy URLs by scheme name (http < https < socks4 < socks4a <
    socks5 < socks5h), then by authority.

    `a`, `b`: proxyUrl values.

    Returns -1, 0, or 1.
  */
  compare =
    a: b:
    if a.scheme < b.scheme then
      -1
    else if a.scheme > b.scheme then
      1
    else
      authority.compare a.authority b.authority;

  /*
    Check whether one proxy URL sorts before another.

    `a`, `b`: proxyUrl values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Check whether one proxy URL sorts before or equal to another.

    `a`, `b`: proxyUrl values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Check whether one proxy URL sorts after another.

    `a`, `b`: proxyUrl values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Check whether one proxy URL sorts after or equal to another.

    `a`, `b`: proxyUrl values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two proxy URLs by `compare`.

    `a`, `b`: proxyUrl values.

    Returns `a` when it sorts first or equal, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two proxy URLs by `compare`.

    `a`, `b`: proxyUrl values.

    Returns `a` when it sorts last or equal, otherwise `b`.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    compare
    eq
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
    Get the authority of a proxy URL; reach the host, userinfo, and port
    through it.

    `proxyUrl`: a proxyUrl value.

    Returns the authority value.
  */
  authority = proxyUrl: proxyUrl.authority;

  /*
    Get the port of a proxy URL.

    `proxyUrl`: a proxyUrl value.

    Returns the authority's port value, which a proxy URL always carries.
  */
  port = proxyUrl: proxyUrl.authority.port;

  /*
    Get the L4 transport of a proxy URL's scheme.

    `proxyUrl`: a proxyUrl value.

    Returns the `tcp` transport value; every proxy scheme runs over TCP.
  */
  transport = proxyUrl: transport.parse schemes.${proxyUrl.scheme}.transport;
}
