/*
  libnet.dnsName

  Pass-through union over Hostname and Domain — a DNS name that is not
  an IP literal. This is the "name" half of `host` (host = ip |
  dnsName). `parse` dispatches by label count: a single label parses
  as a hostname, multiple labels as a domain. IP literals are rejected
  (use `libnet.ip` for those) — that is what distinguishes a dnsName
  from a bare `domain`, which accepts all-numeric dotted forms.

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
  errors = import ./internal/errors.nix;
  comparison = import ./internal/comparison.nix;

  # Return a DNS name argument of `caller`, throwing for any other value.
  expectName = caller: errors.expect caller "hostname or domain value" is;

  parseError = detail: types.tryErr (errors.message "dnsName.parse" detail);

  # ===== Parsing =====

  /*
    Parse a DNS name without throwing, for callers that branch on
    validity or report the error themselves.

    `input`: candidate hostname or domain string.

    Returns a tryResult `{ success, value, error }` holding the
    hostname or domain value on success, or an error message for IP
    literals and invalid names.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else if ip.isValid input then
      parseError "\"${input}\" is an IP address, not a DNS name"
    else
      let
        hostnameResult = hostname.tryParse input;
      in
      if hostnameResult.success then
        hostnameResult
      else
        let
          domainResult = domain.tryParse input;
        in
        if domainResult.success then
          domainResult
        else
          parseError "\"${input}\" is not a valid hostname or domain";

  /*
    Parse a DNS name that is not an IP literal.

    `input`: single-label hostname or multi-label domain string.

    Returns a lowercase hostname value for one label or domain value
    for several; throws on IP literals and invalid names.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a DNS name as a string.

    `name`: hostname or domain value.

    Returns the name in lowercase; throws for any other value.
  */
  toString = name: (expectName "dnsName.toString" name).value;

  # ===== Predicates =====

  /*
    Check whether a value parses as a DNS name.

    `input`: any value; non-strings are invalid.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

  /*
    Recognize a tagged DNS name value.

    `value`: any value.

    Returns true when `value` carries the `hostname` or `domain` tag.
  */
  is = value: types.isHostname value || types.isDomain value;

  /*
    Recognize a tagged hostname value.

    `value`: any value.

    Returns true when `value` carries the `hostname` tag.
  */
  isHostname = value: types.isHostname value;

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
    same text; false otherwise, without throwing.
  */
  eq =
    a: b:
    if types.isHostname a && types.isHostname b then
      hostname.eq a b
    else if types.isDomain a && types.isDomain b then
      domain.eq a b
    else
      false;

  ordering = comparison.suite {
    namespace = "dnsName";
    compareFor =
      caller: a: b:
      let
        left = expectName caller a;
        right = expectName caller b;
        rankOrder = comparison.order (familyRank left) (familyRank right);
      in
      if rankOrder != 0 then rankOrder else comparison.order left.value right.value;
  };
in
{
  inherit
    eq
    is
    isDomain
    isHostname
    isValid
    parse
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
