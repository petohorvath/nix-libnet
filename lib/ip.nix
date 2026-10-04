/*
  libnet.ip

  Unified IPv4/IPv6 dispatch. Auto-detects the family from input
  (strings containing ':' go to ipv6) and forwards predicates,
  comparisons, and arithmetic to the underlying family module.

  Example:
    libnet.ip.parse "192.0.2.1"    # tagged ipv4
    libnet.ip.parse "2001:db8::1"  # tagged ipv6

    libnet.ip.version (libnet.ip.parse "::1")
    => 6
*/
let
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  # ===== Parsing =====

  /*
    Parse an address of either family without throwing, for callers that
    validate untrusted text.

    `input`: address string; any ':' selects IPv6, otherwise IPv4.

    Returns a tryParse result whose `value` is an ipv4 or ipv6 value.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.ip.parse: input must be a string"
    else if parsing.countOccurrences ":" input > 0 then
      ipv6.tryParse input
    else
      ipv4.tryParse input;

  /*
    Parse an address of either family when the family is not known in
    advance.

    `input`: address string; any ':' selects IPv6, otherwise IPv4.

    Returns an ipv4 or ipv6 value; throws on invalid input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Format an address of either family in its canonical text form.

    `ip`: ipv4 or ipv6 value.

    Returns the family's canonical string; throws for any other value.
  */
  toString =
    ip:
    if types.isIpv4 ip then
      ipv4.toString ip
    else if types.isIpv6 ip then
      ipv6.toString ip
    else
      throw "libnet.ip.toString: expected ipv4 or ipv6 value";

  /*
    Report the family of an address.

    `ip`: ipv4 or ipv6 value.

    Returns 4 or 6; throws for any other value.
  */
  version =
    ip:
    if types.isIpv4 ip then
      4
    else if types.isIpv6 ip then
      6
    else
      throw "libnet.ip.version: expected ipv4 or ipv6 value";

  /*
    Check whether a string parses as an address of either family.

    `input`: value to test.

    Returns a Boolean; never throws.
  */
  isValid = input: (tryParse input).success;

  /*
    Structural check for a tagged address of either family.

    `value`: any value.

    Returns true for ipv4 and ipv6 values.
  */
  is = value: types.isIp value;

  /*
    Structural check for a tagged IPv4 address.

    `value`: any value.

    Returns true only for ipv4 values.
  */
  isIpv4 = value: types.isIpv4 value;

  /*
    Structural check for a tagged IPv6 address.

    `value`: any value.

    Returns true only for ipv6 values.
  */
  isIpv6 = value: types.isIpv6 value;

  # ===== Forwarded predicates =====

  # Calls the family-specific implementation; `functionName` only labels the
  # error for non-address input.
  dispatch =
    functionName: onIpv4: onIpv6: ip:
    if types.isIpv4 ip then
      onIpv4 ip
    else if types.isIpv6 ip then
      onIpv6 ip
    else
      throw "libnet.ip.${functionName}: expected ipv4 or ipv6 value";

  /*
    Check whether an address is a loopback address of its family.

    `ip`: ipv4 or ipv6 value.

    Returns a Boolean; throws for any other value.
  */
  isLoopback = ip: dispatch "isLoopback" ipv4.isLoopback ipv6.isLoopback ip;

  /*
    Check whether an address is the unspecified address of its family.

    `ip`: ipv4 or ipv6 value.

    Returns a Boolean; throws for any other value.
  */
  isUnspecified = ip: dispatch "isUnspecified" ipv4.isUnspecified ipv6.isUnspecified ip;

  /*
    Check whether an address is link-local in its family.

    `ip`: ipv4 or ipv6 value.

    Returns a Boolean; throws for any other value.
  */
  isLinkLocal = ip: dispatch "isLinkLocal" ipv4.isLinkLocal ipv6.isLinkLocal ip;

  /*
    Check whether an address is multicast in its family.

    `ip`: ipv4 or ipv6 value.

    Returns a Boolean; throws for any other value.
  */
  isMulticast = ip: dispatch "isMulticast" ipv4.isMulticast ipv6.isMulticast ip;

  /*
    Check whether an address is reserved for documentation in its family.

    `ip`: ipv4 or ipv6 value.

    Returns a Boolean; throws for any other value.
  */
  isDocumentation = ip: dispatch "isDocumentation" ipv4.isDocumentation ipv6.isDocumentation ip;

  /*
    Check whether an address is globally routable, using the family's rules.

    `ip`: ipv4 or ipv6 value.

    Returns a Boolean; throws for any other value.
  */
  isGlobal = ip: dispatch "isGlobal" ipv4.isGlobal ipv6.isGlobal ip;

  /*
    Check whether an address is not globally routable, using the family's
    rules.

    `ip`: ipv4 or ipv6 value.

    Returns a Boolean; throws for any other value.
  */
  isBogon = ip: dispatch "isBogon" ipv4.isBogon ipv6.isBogon ip;

  /*
    Format an address as its reverse-DNS name.

    `ip`: ipv4 or ipv6 value.

    Returns an in-addr.arpa or ip6.arpa name; throws for any other value.
  */
  toArpa = ip: dispatch "toArpa" ipv4.toArpa ipv6.toArpa ip;

  # ===== Comparison (lenient cross-family) =====

  /*
    Test two addresses for equality; different families are never equal.

    `a`, `b`: ipv4 or ipv6 values.

    Returns a Boolean.
  */
  eq =
    a: b:
    if types.isIpv4 a && types.isIpv4 b then
      ipv4.eq a b
    else if types.isIpv6 a && types.isIpv6 b then
      ipv6.eq a b
    else
      false;

  /*
    Order two addresses, placing every IPv4 address before every IPv6
    address so mixed lists sort without throwing.

    `a`, `b`: ipv4 or ipv6 values.

    Returns -1, 0, or 1.
  */
  compare =
    a: b:
    if types.isIpv4 a && types.isIpv6 b then
      -1
    else if types.isIpv6 a && types.isIpv4 b then
      1
    else if types.isIpv4 a then
      ipv4.compare a b
    else
      ipv6.compare a b;

  /*
    Test whether `a` orders before `b` (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` orders before or equal to `b` (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` orders after `b` (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` orders after or equal to `b` (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lower of two addresses (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns `a` when the two compare equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the higher of two addresses (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns `a` when the two compare equal.
  */
  max = a: b: if ge a b then a else b;

  # ===== Arithmetic (dispatched) =====

  /*
    Offset an address within its family.

    `n`: integer offset; may be negative.
    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws on overflow, underflow,
    or a non-address value.
  */
  add = n: ip: dispatch "add" (ipv4.add n) (ipv6.add n) ip;

  /*
    Offset an address downward within its family.

    `n`: integer to subtract; may be negative.
    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws on overflow, underflow,
    or a non-address value.
  */
  sub = n: ip: dispatch "sub" (ipv4.sub n) (ipv6.sub n) ip;

  /*
    Step to the following address in the same family.

    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws past the family's highest
    address or for a non-address value.
  */
  next = ip: dispatch "next" ipv4.next ipv6.next ip;

  /*
    Step to the preceding address in the same family.

    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws below the family's lowest
    address or for a non-address value.
  */
  prev = ip: dispatch "prev" ipv4.prev ipv6.prev ip;

  /*
    Measure the distance between two addresses of the same family.

    `a`, `b`: ipv4 or ipv6 values of one family.

    Returns `b - a` as an integer; throws when the families differ or the
    distance does not fit in a Nix int.
  */
  diff =
    a: b:
    if a._type != b._type then
      throw "libnet.ip.diff: cross-family difference is undefined"
    else if types.isIpv4 a then
      ipv4.diff a b
    else
      ipv6.diff a b;
in
{
  inherit
    add
    compare
    diff
    eq
    ge
    gt
    is
    isBogon
    isDocumentation
    isGlobal
    isIpv4
    isIpv6
    isLinkLocal
    isLoopback
    isMulticast
    isUnspecified
    isValid
    le
    lt
    max
    min
    next
    parse
    prev
    sub
    toArpa
    toString
    tryParse
    version
    ;
}
