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
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  # An address argument of `function`, which throws for any other kind.
  ipArgument = function: errors.expect "ip.${function}" "ipv4 or ipv6 value" types.isIp;

  # Call the family's implementation for the public function `function`,
  # which throws for an argument that is not an address.
  dispatch =
    function: onIpv4: onIpv6: ip:
    if types.isIpv4 (ipArgument function ip) then onIpv4 ip else onIpv6 ip;

  # ===== Parsing =====

  /*
    Parse an address of either family when the family is not known in
    advance: the detail parser of the parsing suite.

    `input`: address string; any ':' selects IPv6, otherwise IPv4.

    Returns a tryResult whose `value` is an ipv4 or ipv6 value, or whose
    `error` is the detail of the family parser. Colon text that is not
    plausibly IPv6 names the syntax it belongs to instead: a bracketed
    literal, or a host other than an IPv6 group followed by a port.
  */
  tryParseDetail =
    input:
    if parsing.countOccurrences ":" input > 0 then
      let
        ipv6Result = ipv6.tryParseDetail input;
        parts = parsing.splitOn ":" input;
        isHostAndPort =
          builtins.length parts == 2
          && parsing.hexGroup (builtins.head parts) == null
          && parsing.isRepetitionOf "[0-9]" (builtins.elemAt parts 1);
      in
      if ipv6Result.success then
        ipv6Result
      else if parsing.startsWith "[" input then
        types.tryErr "\"${input}\" is bracketed, which is URL and endpoint syntax"
      else if isHostAndPort then
        types.tryErr "\"${input}\" reads as host:port, which is endpoint syntax"
      else
        ipv6Result
    else
      ipv4.tryParseDetail input;

  parsers = parsing.suite "ip" tryParseDetail;

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

  # IPv4 before IPv6, then by address. The operands are checked first, so
  # the family comparison cannot fail and name itself.
  compareFor =
    function: a: b:
    comparison.byRank (address: if types.isIpv4 address then 0 else 1) (
      left: right: if types.isIpv4 left then ipv4.compare left right else ipv6.compare left right
    ) (ipArgument function a) (ipArgument function b);

  ordering = comparison.suite compareFor;

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

  # ===== Arithmetic (dispatched) =====

  # The families share their arithmetic with `ip`, which runs it under
  # the `ip` function's name so its errors name the function the caller
  # called.

  /*
    Offset an address within its family.

    `n`: integer offset; may be negative.
    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws on overflow, underflow,
    or a non-address value.
  */
  add = n: dispatch "add" (address.ipv4.add "ip.add" n) (address.ipv6.add "ip.add" n);

  /*
    Offset an address downward within its family.

    `n`: integer to subtract; may be negative.
    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws on overflow, underflow,
    or a non-address value.
  */
  sub = n: dispatch "sub" (address.ipv4.sub "ip.sub" n) (address.ipv6.sub "ip.sub" n);

  /*
    Step to the following address in the same family.

    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws past the family's highest
    address or for a non-address value.
  */
  next = dispatch "next" (address.ipv4.add "ip.next" 1) (address.ipv6.add "ip.next" 1);

  /*
    Step to the preceding address in the same family.

    `ip`: ipv4 or ipv6 value.

    Returns an address of the same family; throws below the family's lowest
    address or for a non-address value.
  */
  prev = dispatch "prev" (address.ipv4.sub "ip.prev" 1) (address.ipv6.sub "ip.prev" 1);

  /*
    Measure the distance between two addresses of the same family.

    `a`, `b`: ipv4 or ipv6 values of one family.

    Returns `b - a` as an integer; throws when the families differ or the
    distance does not fit in a Nix int.
  */
  diff =
    a: b:
    let
      left = ipArgument "diff" a;
      right = ipArgument "diff" b;
    in
    if left._type != right._type then
      errors.fail "ip.diff" "cross-family difference is undefined"
    else if types.isIpv4 left then
      address.ipv4.diff "ip.diff" left right
    else
      address.ipv6.diff "ip.diff" left right;
in
{
  inherit
    add
    diff
    eq
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
    next
    prev
    sub
    toArpa
    toString
    tryParseDetail
    version
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
