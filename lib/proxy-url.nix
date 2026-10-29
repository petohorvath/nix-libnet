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
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
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
  # `secure` covers the client-to-proxy hop: only `https` encrypts it;
  # `socks5h`'s `h` means remote DNS, not encryption.
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

  # Check the proxyUrl argument of `function`, throwing for any other
  # kind.
  proxyUrlArgument = function: errors.expectKind "proxyUrl.${function}" "proxyUrl";

  parseError = detail: types.tryErr (errors.message "proxyUrl.parse" detail);

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
          lowerScheme = lowerAscii rawScheme;
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
        in
        if !(schemes ? ${lowerScheme}) then
          parseError "unknown scheme \"${rawScheme}\" (${schemeHint})"
        else
          let
            authorityResult = authority.tryParse rest;
          in
          if !authorityResult.success then
            parseError (errors.detail "authority.parse" authorityResult.error)
          else if authority.port authorityResult.value == null then
            parseError "a proxy URL requires an explicit port: \"${input}\""
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
  toString =
    proxyUrl:
    let
      checked = proxyUrlArgument "toString" proxyUrl;
    in
    "${checked.scheme}://${authority.toString checked.authority}";

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
    let
      caller = "proxyUrl.make";
      lowerScheme = lowerAscii (errors.expectType caller "string" schemeName);
      checked = errors.expectKind caller "authority" authorityValue;
    in
    if !(schemes ? ${lowerScheme}) then
      errors.fail caller "unknown scheme \"${schemeName}\" (${schemeHint})"
    else if checked.port == null then
      errors.fail caller "a proxy URL requires an explicit port"
    else
      mk lowerScheme checked;

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
    Check whether a proxy URL's scheme is secure: its protocol encrypts
    the client-to-proxy connection, per the scheme registry. Only `https`
    does; `http` and every SOCKS scheme (including `socks5h`, whose `h`
    means remote DNS) reach the proxy in plaintext.

    `proxyUrl`: a proxyUrl value.

    Returns true only for the `https` scheme.
  */
  isSecure = proxyUrl: schemes.${(proxyUrlArgument "isSecure" proxyUrl).scheme}.secure;

  # ===== Accessors =====

  /*
    Get the scheme of a proxy URL.

    `proxyUrl`: a proxyUrl value.

    Returns the lowercase scheme string.
  */
  scheme = proxyUrl: (proxyUrlArgument "scheme" proxyUrl).scheme;

  /*
    Get the userinfo of a proxy URL.

    `proxyUrl`: a proxyUrl value.

    Returns the authority's raw userinfo string, or null when absent.
  */
  userinfo = proxyUrl: (proxyUrlArgument "userinfo" proxyUrl).authority.userinfo;

  /*
    Get the host of a proxy URL.

    `proxyUrl`: a proxyUrl value.

    Returns the authority's host: an ipv4, ipv6, or regName value.
  */
  host = proxyUrl: (proxyUrlArgument "host" proxyUrl).authority.host;

  # ===== Conversions =====

  /*
    Convert a proxy URL to the endpoint for its host and port.

    `proxyUrl`: a proxyUrl value.

    Returns an ipEndpoint for IP hosts or a dnsEndpoint for registered
    names that are valid DNS names; throws for other registered names,
    which have no endpoint.
  */
  toEndpoint =
    proxyUrl:
    let
      checked = proxyUrlArgument "toEndpoint" proxyUrl;
      hostValue = checked.authority.host;
      targetPort = checked.authority.port;
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
  # Sorted by scheme name, for determinism only, then by authority. Each
  # ordering function passes its own name, which its errors report.

  compareFor =
    function: a: b:
    let
      left = proxyUrlArgument function a;
      right = proxyUrlArgument function b;
    in
    comparison.lexicographic [
      (comparison.order left.scheme right.scheme)
      (authority.compare left.authority right.authority)
    ];

  ordering = comparison.suite compareFor;

  /*
    Test two proxy URLs for equality.

    `a`, `b`: values to compare.

    Returns true when the schemes match exactly (`socks5` differs from
    `socks5h`) and the authorities are equal, including userinfo; false
    for any other value.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.proxyUrl a b
    && a.scheme == b.scheme
    && authority.eq a.authority b.authority;
in
{
  inherit
    eq
    host
    is
    isSecure
    isValid
    make
    parse
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
    Get the authority of a proxy URL; reach the host, userinfo, and port
    through it.

    `proxyUrl`: a proxyUrl value.

    Returns the authority value.
  */
  authority = proxyUrl: (proxyUrlArgument "authority" proxyUrl).authority;

  /*
    Get the port of a proxy URL.

    `proxyUrl`: a proxyUrl value.

    Returns the authority's port value, which a proxy URL always carries.
  */
  port = proxyUrl: (proxyUrlArgument "port" proxyUrl).authority.port;

  /*
    Get the transport of a proxy URL's scheme.

    `proxyUrl`: a proxyUrl value.

    Returns the `tcp` transport value; every proxy scheme runs over TCP.
  */
  transport =
    proxyUrl: transport.parse schemes.${(proxyUrlArgument "transport" proxyUrl).scheme}.transport;
}
