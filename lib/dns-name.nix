/*
  libnet.dnsName

  Pass-through union over Hostname and Domain — a DNS name that is not
  an IP literal. This is the "name" half of `host` (host = ip |
  dnsName). `parse` dispatches by label count: a single label parses
  as a hostname, multiple labels as a domain. IP literals are rejected
  (use `libnet.ip` for those), and so is any text a resolver reads as
  an IPv4 address (ADR 0021): a numeric hostname such as `2130706433`
  or `0x7f`, which `libnet.hostname` accepts, and a domain whose
  rightmost label is numeric, such as `127.1`.

  No new `_type` tag: the result is the underlying hostname or domain
  value; consumers branch on `value._type`. Same pattern as
  `libnet.ip` and `libnet.host`. Both members lowercase at parse
  (ADR 0020), so a DNS name prints canonical text.

  Example:
    libnet.dnsName.parse "nas"            # tagged hostname
    libnet.dnsName.parse "pool.ntp.org"   # tagged domain
    libnet.dnsName.parse "192.0.2.1"      # throws — that's an IP
*/
let
  types = import ./internal/types.nix;
  ip = import ./ip.nix;
  hostname = import ./hostname.nix;
  domain = import ./domain.nix;
  dnsLabel = import ./internal/dns-label.nix;
  parsing = import ./internal/parse.nix;
  comparison = import ./internal/comparison.nix;

  # Return a DNS name argument of `function`, throwing for any other value.
  dnsNameArgument =
    function: dnsLabel.expectDnsName "dnsName.${function}" "hostname or domain value" is;

  # Well-formed labels whose rightmost one is numeric, such as `127.1` or
  # `2130706433`, which `inet_aton` reads as an IPv4 address (ADR 0021).
  readsAsIpv4 =
    input:
    dnsLabel.hasNumericRightmostLabel input
    && builtins.all dnsLabel.isValidLabel (parsing.splitOn "." input);

  # ===== Parsing =====

  /*
    Parse a DNS name that is not an IP literal: the detail parser of the
    parsing suite.

    `input`: single-label hostname or multi-label domain string.

    Returns a tryResult holding a hostname value for one label or a domain
    value for several, or the detail of the failure for IP literals, text
    that reads as an IPv4 address, and invalid names.
  */
  tryParseDetail =
    input:
    if ip.isValid input then
      types.tryErr "\"${input}\" is an IP address, not a DNS name"
    else if readsAsIpv4 input then
      types.tryErr "\"${input}\" reads as an IPv4 address, not a DNS name"
    else
      let
        hostnameResult = hostname.tryParseDetail input;
      in
      if hostnameResult.success then
        hostnameResult
      else
        let
          domainResult = domain.tryParseDetail input;
        in
        if domainResult.success then
          domainResult
        # Keep the detail of the member whose shape the text has: a domain
        # has a dot and a hostname does not.
        else if parsing.countOccurrences "." input > 0 then
          domainResult
        else
          hostnameResult;

  parsers = parsing.suite "dnsName" tryParseDetail;

  /*
    Render a DNS name as a string.

    `name`: hostname or domain value.

    Returns the name in lowercase; throws for any other value.
  */
  toString = name: (dnsNameArgument "toString" name).value;

  # ===== Predicates =====

  /*
    Recognize a tagged hostname value that is a DNS name.

    `value`: any value.

    Returns true when `value` carries the `hostname` tag on a label that
    is not numeric.
  */
  isHostname = value: types.isHostname value && !dnsLabel.isNumericHostname value;

  /*
    Recognize a tagged DNS name value.

    `value`: any value.

    Returns true when `value` carries the `domain` tag, or the `hostname`
    tag on a label that is not numeric: `hostname.parse "1234"` is not a
    DNS name, since a resolver reads it as an IPv4 address (ADR 0021).
  */
  is = value: types.isDomain value || isHostname value;

  /*
    Recognize a tagged domain value.

    `value`: any value.

    Returns true when `value` carries the `domain` tag.
  */
  isDomain = value: types.isDomain value;

  # ===== Comparison =====
  #
  # Cross-family order: hostname (single label) sorts before domain
  # (multi label), then by the lowercase text within a family.

  familyRank = name: if types.isHostname name then 0 else 1;

  /*
    Test two DNS names for equality, ignoring case.

    `a`, `b`: values to compare.

    Returns true when both are hostnames or both are domains with the
    same text; false otherwise, including for a numeric hostname, which
    is not a DNS name, without throwing.
  */
  eq =
    a: b:
    if isHostname a && isHostname b then
      hostname.eq a b
    else if types.isDomain a && types.isDomain b then
      domain.eq a b
    else
      false;

  ordering = comparison.suite (
    function: a: b:
    comparison.byRank familyRank (
      left: right: comparison.order left.value right.value
    ) (dnsNameArgument function a) (dnsNameArgument function b)
  );
in
{
  inherit
    eq
    is
    isDomain
    isHostname
    toString
    tryParseDetail
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
}
