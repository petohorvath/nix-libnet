/*
  libnet.host

  Pass-through union over Ipv4, Ipv6, Hostname, and Domain — the
  shapes a service consumer might address. Composed as `ip | dnsName`:
  `parse` tries an IP first (so dotted-quad strings classify as IPs),
  then falls back to a DNS name (single-label hostname or multi-label
  domain).

  Returns the underlying typed value (no new `_type` tag); consumers
  branch on `value._type` to access family-specific operations. Same
  pattern as `libnet.ip` for the v4/v6 split.

  Example:
    libnet.host.parse "192.168.1.1"   # tagged ipv4
    libnet.host.parse "nas"            # tagged hostname
    libnet.host.parse "pool.ntp.org"   # tagged domain
*/
let
  types = import ./internal/types.nix;
  ip = import ./ip.nix;
  dnsName = import ./dns-name.nix;

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
      types.tryErr "libnet.host.parse: input must be a string"
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
          types.tryErr "libnet.host.parse: \"${input}\" is not a valid IP, hostname, or domain";

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
    if types.isIp host then
      ip.toString host
    else if dnsName.is host then
      dnsName.toString host
    else
      throw "libnet.host.toString: expected ip, hostname, or domain value";

  # ===== Predicates =====

  /*
    Recognize a tagged IP value.

    `value`: any value.

    Returns true when `value` carries the `ipv4` or `ipv6` tag.
  */
  isIp = value: types.isIp value;

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

  /*
    Recognize a DNS name, the common "not an IP" branch in
    configuration code.

    `value`: any value.

    Returns true when `value` carries the `hostname` or `domain` tag.
  */
  isName = value: dnsName.is value;

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
  # names, delegated to dnsName.compare (case-insensitive per DNS).

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

  /*
    Order two hosts for sorting: ipv4 < ipv6 < hostname < domain, then
    within each family by that family's comparison.

    `a`, `b`: ipv4, ipv6, hostname, or domain values.

    Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`.
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
      dnsName.compare a b;

  /*
    Test whether one host sorts strictly before another.

    `a`, `b`: host values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether one host sorts before or equal to another.

    `a`, `b`: host values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether one host sorts strictly after another.

    `a`, `b`: host values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether one host sorts after or equal to another.

    `a`, `b`: host values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the host that sorts first.

    `a`, `b`: host values.

    Returns `a` when `le a b`, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the host that sorts last.

    `a`, `b`: host values.

    Returns `a` when `ge a b`, otherwise `b`.
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
    isDomain
    isHostname
    isIp
    isName
    isValid
    le
    lt
    max
    min
    parse
    toString
    tryParse
    ;
}
