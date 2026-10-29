/*
  libnet.urlHost

  The host component of a URL authority (RFC 3986 §3.2.2) — the `host`
  of `libnet.authority`, and usable standalone. A pass-through union
  over `libnet.ip` and `libnet.regName`, deliberately distinct from
  `libnet.host`: a registered name is a loose ASCII set (adds `_`, `~`,
  sub-delims, `%`-encoding) with no DNS label structure, where `host`
  holds a DNS name.

  Returns the member's own tagged value (no `urlHost` tag): an `ipv4`,
  an `ipv6`, or a `regName`. IPs are tried first, so a dotted quad is an
  IPv4 address; IPv6 must be bracketed in text.

  Example:
    libnet.urlHost.parse "[::1]"
    => { _type = "ipv6"; … }   # the ::1 address

    libnet.urlHost.parse "my_host"
    => { _type = "regName"; value = "my_host"; }
*/
let
  ip = import ./ip.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  regName = import ./reg-name.nix;
  dnsName = import ./dns-name.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  # ===== Parsing =====

  /*
    Parse a URL host without throwing, for callers that branch on validity.

    `input`: a bracketed IPv6 literal (`[::1]`), dotted IPv4, or a non-empty
    registered name (unreserved, sub-delims, and `%XX` escapes).

    Returns a tryResult: `{ success = true; value = <ipv4 | ipv6 | regName>; }`
    or `{ success = false; error = <string>; }`. Never throws.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.urlHost.parse: input must be a string"
    else if input == "" then
      types.tryErr "libnet.urlHost.parse: empty host"
    else if parsing.startsWith "[" input then
      if parsing.endsWith "]" input then
        let
          inner = builtins.substring 1 (builtins.stringLength input - 2) input;
          result = ipv6.tryParse inner;
        in
        if result.success then
          result
        else
          types.tryErr "libnet.urlHost.parse: invalid IPv6 literal \"${input}\""
      else
        types.tryErr "libnet.urlHost.parse: unclosed IPv6 literal \"${input}\""
    else
      let
        ipv4Result = ipv4.tryParse input;
        regNameResult = regName.tryParse input;
      in
      if ipv4Result.success then
        ipv4Result
      else if regNameResult.success then
        regNameResult
      else
        types.tryErr "libnet.urlHost.parse: invalid host \"${input}\"";

  /*
    Parse a URL host, for values that must be valid.

    `input`: host text as accepted by `tryParse`.

    Returns an ipv4, ipv6, or regName value; throws on invalid input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a URL host as it appears in a URL authority.

    `urlHost`: an ipv4, ipv6, or regName value.

    Returns the host text: IPv6 addresses bracketed, registered names
    verbatim (case preserved); throws for any other value.
  */
  toString =
    urlHost:
    if types.isIpv6 urlHost then
      "[${ipv6.toString urlHost}]"
    else if types.isIpv4 urlHost then
      ipv4.toString urlHost
    else if regName.is urlHost then
      regName.toString urlHost
    else
      throw "libnet.urlHost.toString: expected ip or regName value";

  # ===== Predicates =====

  /*
    Check whether a string parses as a URL host.

    `input`: candidate host text.

    Returns true when `tryParse` succeeds.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a URL host value.

    `value`: any value.

    Returns true for a tagged ipv4, ipv6, or regName value.
  */
  is = value: types.isUrlHost value;

  /*
    Check whether a value is an IP address (IPv4 or IPv6).

    `value`: any value.

    Returns true for a tagged ipv4 or ipv6 value.
  */
  isIp = value: types.isIp value;

  /*
    Check whether a value is a registered name rather than an IP address.

    `value`: any value.

    Returns true for a tagged regName value.
  */
  isRegName = value: regName.is value;

  # ===== Conversion =====

  /*
    Convert a URL host to a `libnet.host`, bridging the looser URL grammar
    to the composable host types.

    `urlHost`: an ipv4, ipv6, or regName value.

    Returns the IP value itself, or the `dnsName` value when the registered
    name is a valid DNS name; null otherwise (for example, names containing
    underscores).
  */
  toHost =
    urlHost:
    if types.isIp urlHost then
      urlHost
    else
      let
        result = dnsName.tryParse (regName.toString urlHost);
      in
      if result.success then result.value else null;

  # ===== Comparison =====
  #
  # Cross-kind order: ip < regName. Within IPs, ipv4 < ipv6 (delegated
  # to ip.compare); registered names compare case-insensitively.

  rank = value: if types.isIp value then 0 else 1;

  /*
    Test two URL hosts for equality.

    `a`, `b`: values to compare.

    Returns true when both are IPs equal under `ip.eq` or both are
    registered names equal under `regName.eq` (case-insensitive); false
    across kinds. Never throws on mismatched types.
  */
  eq =
    a: b:
    if types.isIp a && types.isIp b then
      ip.eq a b
    else if regName.is a && regName.is b then
      regName.eq a b
    else
      false;

  /*
    Order two URL hosts: IPs before registered names, IPs by `ip.compare`
    (IPv4 first), and registered names case-insensitively.

    `a`, `b`: ipv4, ipv6, or regName values.

    Returns -1, 0, or 1.
  */
  compare =
    a: b:
    let
      rankA = rank a;
      rankB = rank b;
    in
    if rankA < rankB then
      -1
    else if rankA > rankB then
      1
    else if rankA == 0 then
      ip.compare a b
    else
      regName.compare a b;

  /*
    Check whether one URL host sorts before another.

    `a`, `b`: urlHost values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Check whether one URL host sorts before or equal to another.

    `a`, `b`: urlHost values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Check whether one URL host sorts after another.

    `a`, `b`: urlHost values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Check whether one URL host sorts after or equal to another.

    `a`, `b`: urlHost values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two URL hosts by `compare`.

    `a`, `b`: urlHost values.

    Returns `a` when it sorts first or equal, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two URL hosts by `compare`.

    `a`, `b`: urlHost values.

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
    is
    isIp
    isRegName
    isValid
    le
    lt
    max
    min
    parse
    toHost
    toString
    tryParse
    ;
}
