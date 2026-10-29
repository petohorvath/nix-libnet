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
  dnsName = import ./dns-name.nix;

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

  splitKnownScheme = parsing.splitKnownScheme {
    canonicalize = lowerAscii;
    inherit schemes;
    hint = schemeHint;
  };

  mk = schemeValue: authorityValue: {
    _type = "proxyUrl";
    scheme = schemeValue;
    authority = authorityValue;
  };

  # Check the proxyUrl argument of `function`, throwing for any other
  # kind.
  proxyUrlArgument = function: errors.expectKind "proxyUrl.${function}" "proxyUrl";

  # ===== Parsing =====

  /*
    Parse a proxy URL: the detail parser of the parsing suite.

    `input`: `<scheme>://[userinfo@]host:port` text; the scheme is matched
    case-insensitively and nothing may follow the authority.

    Returns a tryResult holding a proxyUrl value, or the detail of the
    failure: an unknown scheme, an invalid authority, or a missing port.
  */
  tryParseDetail =
    input:
    let
      schemeResult = splitKnownScheme input;
      canonicalScheme = schemeResult.value.scheme;
      inherit (schemeResult.value) rest;
    in
    if !schemeResult.success then
      schemeResult
    else
      let
        authorityResult = authority.tryParseDetail rest;
      in
      if !authorityResult.success then
        authorityResult
      else if authority.port authorityResult.value == null then
        types.tryErr "a proxy URL requires an explicit port: \"${input}\""
      else
        types.tryOk (mk canonicalScheme authorityResult.value);

  parsers = parsing.suite "proxyUrl" tryParseDetail;

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
      canonicalScheme = lowerAscii (errors.expectType caller "string" schemeName);
      checked = errors.expectKind caller "authority" authorityValue;
    in
    if !(schemes ? ${canonicalScheme}) then
      errors.fail caller "unknown scheme \"${schemeName}\" (${schemeHint})"
    else if checked.port == null then
      errors.fail caller "a proxy URL requires an explicit port"
    else
      mk canonicalScheme checked;

  # ===== Predicates =====

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
        nameText = urlHost.toString hostValue;
      in
      # Guard `toHost`, which would name itself in the error.
      if dnsName.isValid nameText then
        dnsEndpoint.make (urlHost.toHost hostValue) targetPort
      else
        errors.fail "proxyUrl.toEndpoint" "registered name \"${nameText}\" is not a valid DNS name";

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
    make
    scheme
    schemes
    toEndpoint
    toString
    userinfo
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
