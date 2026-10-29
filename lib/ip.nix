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
  address = import ./internal/address.nix;
  bits = import ./internal/bits.nix;
  errors = import ./internal/errors.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  # An address argument of `function`, which throws for any other kind.
  checked = function: errors.expect "ip.${function}" "ipv4 or ipv6 value" types.isIp;

  # The family arithmetic, run under the `ip` function's name so its
  # errors name the function the caller called.
  ipv4Arithmetic = address.scalar {
    typeName = "ipv4";
    maxValue = bits.mask32;
    format = ipv4.toString;
  };
  ipv6Arithmetic = address.words { format = ipv6.toString; };

  # Call the family's implementation for the public function `function`,
  # which throws for an argument that is not an address.
  dispatch =
    function: onIpv4: onIpv6: ip:
    if types.isIpv4 (checked function ip) then onIpv4 ip else onIpv6 ip;

  # Report a member's parse failure as `ip.parse`, keeping its detail.
  fromMember =
    member: result:
    if result.success then
      result
    else
      types.tryErr (errors.message "ip.parse" (errors.detailOf "${member}.parse" result.error));

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
      types.tryErr (errors.message "ip.parse" "expected string, got ${errors.describe input}")
    else if parsing.countOccurrences ":" input > 0 then
      fromMember "ipv6" (ipv6.tryParse input)
    else
      fromMember "ipv4" (ipv4.tryParse input);

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
  toString = dispatch "toString" ipv4.toString ipv6.toString;

  /*
    Report the family of an address.

    `ip`: ipv4 or ipv6 value.

    Returns 4 or 6; throws for any other value.
  */
  version = dispatch "version" (_: 4) (_: 6);

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

  # Order two addresses for the public function `function`, IPv4 before
  # IPv6, throwing for an argument that is not an address.
  compareFor =
    function: a: b:
    let
      left = checked function a;
      right = checked function b;
    in
    if types.isIpv4 left && types.isIpv6 right then
      -1
    else if types.isIpv6 left && types.isIpv4 right then
      1
    else if types.isIpv4 left then
      ipv4.compare left right
    else
      ipv6.compare left right;

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
  compare = compareFor "compare";

  /*
    Test whether `a` orders before `b` (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns a Boolean.
  */
  lt = a: b: compareFor "lt" a b == -1;

  /*
    Test whether `a` orders before or equal to `b` (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns a Boolean.
  */
  le = a: b: compareFor "le" a b <= 0;

  /*
    Test whether `a` orders after `b` (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns a Boolean.
  */
  gt = a: b: compareFor "gt" a b == 1;

  /*
    Test whether `a` orders after or equal to `b` (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns a Boolean.
  */
  ge = a: b: compareFor "ge" a b >= 0;

  /*
    Pick the lower of two addresses (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns `a` when the two compare equal.
  */
  min = a: b: if compareFor "min" a b <= 0 then a else b;

  /*
    Pick the higher of two addresses (IPv4 before IPv6).

    `a`, `b`: ipv4 or ipv6 values.

    Returns `a` when the two compare equal.
  */
  max = a: b: if compareFor "max" a b >= 0 then a else b;

  # ===== Arithmetic (dispatched) =====

  /*
    Offset an address within its family.

    `n`: integer offset; may be negative.
    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws on overflow, underflow,
    or a non-address value.
  */
  add = n: dispatch "add" (ipv4Arithmetic.add "ip.add" n) (ipv6Arithmetic.add "ip.add" n);

  /*
    Offset an address downward within its family.

    `n`: integer to subtract; may be negative.
    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws on overflow, underflow,
    or a non-address value.
  */
  sub = n: dispatch "sub" (ipv4Arithmetic.sub "ip.sub" n) (ipv6Arithmetic.sub "ip.sub" n);

  /*
    Step to the following address in the same family.

    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws past the family's highest
    address or for a non-address value.
  */
  next = dispatch "next" (ipv4Arithmetic.add "ip.next" 1) (ipv6Arithmetic.add "ip.next" 1);

  /*
    Step to the preceding address in the same family.

    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws below the family's lowest
    address or for a non-address value.
  */
  prev = dispatch "prev" (ipv4Arithmetic.sub "ip.prev" 1) (ipv6Arithmetic.sub "ip.prev" 1);

  /*
    Measure the distance between two addresses of the same family.

    `a`, `b`: ipv4 or ipv6 values of one family.

    Returns `b - a` as an integer; throws when the families differ or the
    distance does not fit in a Nix int.
  */
  diff =
    a: b:
    let
      left = checked "diff" a;
      right = checked "diff" b;
    in
    if left._type != right._type then
      errors.fail "ip.diff" "cross-family difference is undefined"
    else if types.isIpv4 left then
      ipv4.diff left right
    else
      ipv6Arithmetic.diff "ip.diff" left right;
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
