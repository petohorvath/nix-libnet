/*
  libnet.host

  Pass-through union over Ipv4, Ipv6, Hostname, and Domain — the
  shapes a service consumer might address. Composed as `ip | dnsName`:
  `parse` tries an IP first (so dotted-quad strings classify as IPs),
  then falls back to a DNS name (single-label hostname or multi-label
  domain).

  Returns the underlying typed value (no new `_type` tag); consumers
  branch on `value._type` to access family-specific operations. Same
  pattern as `libnet.ip` for the v4/v6 split. Names lowercase at parse
  (ADR 0020), so a host prints canonical text.

  Example:
    libnet.host.parse "192.168.1.1"   # tagged ipv4
    libnet.host.parse "nas"            # tagged hostname
    libnet.host.parse "pool.ntp.org"   # tagged domain
*/
let
  types = import ./internal/types.nix;
  ip = import ./ip.nix;
  dnsName = import ./dns-name.nix;
  errors = import ./internal/errors.nix;
  comparison = import ./internal/comparison.nix;

  # Return a host argument of `caller`, throwing for any other value.
  expectHost = caller: errors.expect caller "ip, hostname or domain value" is;

  parseError = detail: types.tryErr (errors.message "host.parse" detail);

  # ===== Parsing =====

  /*
    Parse a host without throwing, for callers that branch on validity
    or report the error themselves. IPs are tried first so dotted-quad
    strings classify as IPs rather than as four-label domains.

    `input`: candidate IP, hostname, or domain string.

    Returns a tryResult `{ success, value, error }` holding the ipv4,
    ipv6, hostname, or domain value on success, or an error message.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else
      let
        ipResult = ip.tryParse input;
      in
      if ipResult.success then
        ipResult
      else
        let
          nameResult = dnsName.tryParse input;
        in
        if nameResult.success then
          nameResult
        else
          parseError "\"${input}\" is not a valid IP, hostname, or domain";

  /*
    Parse an address a service consumer might connect to.

    `input`: IPv4, IPv6, hostname, or domain string.

    Returns the ipv4, ipv6, hostname, or domain value; throws when no
    family matches.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a host as a string using its family's formatting.

    `host`: ipv4, ipv6, hostname, or domain value.

    Returns the family's string form; throws for any other value.
  */
  toString =
    host:
    let
      checked = expectHost "host.toString" host;
    in
    if types.isIp checked then ip.toString checked else dnsName.toString checked;

  # ===== Predicates =====

  /*
    Recognize a tagged IP value.

    `value`: any value.

    Returns true when `value` carries the `ipv4` or `ipv6` tag.
  */
  isIp = value: types.isIp value;

  /*
    Recognize a DNS name, the common "not an IP" branch in
    configuration code.

    `value`: any value.

    Returns true when `value` carries the `hostname` or `domain` tag.
  */
  isDnsName = value: dnsName.is value;

  /*
    Recognize a tagged host value.

    `value`: any value.

    Returns true when `value` is a tagged ipv4, ipv6, hostname, or
    domain value.
  */
  is = value: types.isIp value || dnsName.is value;

  /*
    Check whether a value parses as a host.

    `input`: any value; non-strings are invalid.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

  # ===== Comparison =====
  #
  # Cross-family order: ip < name (hostname < domain within names).
  # Within the IP family, ipv4 < ipv6 (delegated to ip.compare); among
  # names, delegated to dnsName.compare.

  rank = value: if types.isIp value then 0 else 1;

  /*
    Test two hosts for equality within the same family.

    `a`, `b`: values to compare.

    Returns true when both are IPs equal under `ip.eq` or both are DNS
    names equal under `dnsName.eq`; false across families.
  */
  eq =
    a: b:
    if types.isIp a && types.isIp b then
      ip.eq a b
    else if dnsName.is a && dnsName.is b then
      dnsName.eq a b
    else
      false;

  # The operands are checked first, so the delegated comparison cannot
  # fail and name itself.
  ordering = comparison.suite {
    namespace = "host";
    compareFor =
      caller: a: b:
      let
        left = expectHost caller a;
        right = expectHost caller b;
        rankOrder = comparison.order (rank left) (rank right);
      in
      if rankOrder != 0 then
        rankOrder
      else if rank left == 0 then
        ip.compare left right
      else
        dnsName.compare left right;
  };
in
{
  inherit
    eq
    is
    isDnsName
    isIp
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
