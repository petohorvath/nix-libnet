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
  errors = import ./internal/errors.nix;
  comparison = import ./internal/comparison.nix;

  # Return a URL host argument of `function`, throwing for any other value.
  urlHostArgument =
    function: errors.expect "urlHost.${function}" "ip or regName value" types.isUrlHost;

  parseError = detail: types.tryErr (errors.message "urlHost.parse" detail);

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
      parseError "expected string, got ${errors.describe input}"
    else if input == "" then
      parseError "empty host"
    else if parsing.startsWith "[" input then
      if parsing.endsWith "]" input then
        let
          inner = builtins.substring 1 (builtins.stringLength input - 2) input;
          result = ipv6.tryParse inner;
        in
        if result.success then result else parseError "invalid IPv6 literal \"${input}\""
      else
        parseError "unclosed IPv6 literal \"${input}\""
    else
      let
        ipv4Result = ipv4.tryParse input;
        regNameResult = regName.tryParse input;
      in
      if ipv4Result.success then
        ipv4Result
      else if regNameResult.success then
        regNameResult
      # Keep the detail of the member whose shape the text has; a
      # registered name of only digits and dots reads as IPv4 (ADR 0021).
      else if parsing.isDottedDigits input then
        parseError (errors.detail "ipv4.parse" ipv4Result.error)
      else
        parseError (errors.detail "regName.parse" regNameResult.error);

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

    Returns the host text: IPv6 addresses bracketed, registered names in
    their canonical lowercase form; throws for any other value.
  */
  toString =
    urlHost:
    let
      checked = urlHostArgument "toString" urlHost;
    in
    if types.isIpv6 checked then
      "[${ipv6.toString checked}]"
    else if types.isIpv4 checked then
      ipv4.toString checked
    else
      regName.toString checked;

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
    underscores). Throws for any other value.
  */
  toHost =
    urlHost:
    let
      checked = urlHostArgument "toHost" urlHost;
      result = dnsName.tryParse checked.value;
    in
    if types.isIp checked then
      checked
    else if result.success then
      result.value
    else
      null;

  # ===== Comparison =====
  #
  # Cross-kind order: ip < regName. Within IPs, ipv4 < ipv6 (delegated
  # to ip.compare); registered names by their folded text.

  rank = value: if types.isIp value then 0 else 1;

  /*
    Test two URL hosts for equality.

    `a`, `b`: values to compare.

    Returns true when both are IPs equal under `ip.eq` or both are
    registered names equal under `regName.eq`; false across kinds. Never
    throws on mismatched types.
  */
  eq =
    a: b:
    if types.isIp a && types.isIp b then
      ip.eq a b
    else if regName.is a && regName.is b then
      regName.eq a b
    else
      false;

  # The operands are checked first, so the delegated comparison cannot
  # fail and name itself.
  ordering = comparison.suite (
    function: a: b:
    comparison.byRank rank (
      left: right: if rank left == 0 then ip.compare left right else regName.compare left right
    ) (urlHostArgument function a) (urlHostArgument function b)
  );
in
{
  inherit
    eq
    is
    isIp
    isRegName
    isValid
    parse
    toHost
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
}
