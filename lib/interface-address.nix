/*
  libnet.interfaceAddress

  An address (ipv4 or ipv6) paired with the prefix of the CIDR it sits
  on — e.g. `192.168.1.10/24`. The pure-Nix analog of Python's
  `IPv4Interface` / `IPv6Interface`.

  Distinct from `cidr`: a `cidr` is a block with the host bits zeroed
  (`192.168.1.0/24`), whereas an `interfaceAddress` keeps the host bits
  significant (`192.168.1.10/24` — a specific address plus the CIDR it
  sits on). The two never compare `eq` (different `_type`); `cidr`
  derives the block.

  The interface *name* (the NIC identifier, `eth0`) is a separate type:
  `libnet.interfaceName`.

  Example:
    libnet.interfaceAddress.parse "192.168.1.10/24"
    => { _type = "interfaceAddress"; address = <ipv4>; prefix = 24; }
*/
let
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ip = import ./ip.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  cidr = import ./cidr.nix;

  mk =
    addressValue: prefixLength:
    types.mkStrict "interfaceAddress" {
      address = addressValue;
      prefix = prefixLength;
    };

  isV4 = addressValue: addressValue._type == "ipv4";
  isV6 = addressValue: addressValue._type == "ipv6";

  maxPrefix = addressValue: if isV4 addressValue then 32 else 128;

  # ===== Argument kinds =====

  /*
    Each returns its argument, throwing for the wrong kind on behalf of
    the public `function`. The unchecked helpers below, such as `cidrOf`
    and `order`, take values the public function has already checked.
  */
  interfaceAddressArgument =
    function: errors.expectKind "interfaceAddress.${function}" "interfaceAddress";
  addressArgument =
    function: errors.expect "interfaceAddress.${function}" "ipv4 or ipv6 value" types.isIp;

  # Check both operands of a binary `function`, then apply `relation` to
  # them.
  binary =
    function: relation: a: b:
    relation (interfaceAddressArgument function a) (interfaceAddressArgument function b);

  # ===== Parsing =====

  /*
    Parse an interface address, such as a per-NIC address assignment,
    keeping the host bits: the detail parser of the parsing suite.

    `input`: "<address>/<prefix>", such as "192.168.1.5/24" or
    "2001:db8::5/64"; the prefix must fit the address family.

    Returns a tryResult whose `value` is an interfaceAddress value, or
    whose `error` is the detail of the failure.
  */
  tryParseDetail =
    input:
    let
      result = parsing.addressPrefix ip.tryParseDetail input;
    in
    if result.success then types.tryOk (mk result.value.address result.value.prefix) else result;

  parsers = parsing.suite "interfaceAddress" tryParseDetail;

  # ===== Formatting =====

  /*
    Format an interface address as text. The string has the same shape
    as a CIDR but keeps the host bits; only the type tag differs.

    `interfaceAddress`: interfaceAddress value.

    Returns "<address>/<prefix>", such as "192.168.1.10/24".
  */
  toString =
    interfaceAddress:
    let
      checked = interfaceAddressArgument "toString" interfaceAddress;
      addressText =
        if isV4 checked.address then ipv4.toString checked.address else ipv6.toString checked.address;
    in
    "${addressText}/${builtins.toString checked.prefix}";

  # ===== Construction =====

  /*
    Build an interface address from an address and prefix length.

    `addressValue`: ipv4 or ipv6 value; host bits are kept.
    `prefixLength`: integer in [0, 32] for IPv4 or [0, 128] for IPv6.

    Returns an interfaceAddress value; throws on a non-address or a
    non-integer or out-of-range prefix.
  */
  make =
    addressValue: prefixLength:
    let
      checkedAddress = addressArgument "make" addressValue;
      checkedPrefix = errors.intArgument "interfaceAddress.make" prefixLength;
      prefixMax = maxPrefix checkedAddress;
    in
    if checkedPrefix < 0 || checkedPrefix > prefixMax then
      errors.fail "interfaceAddress.make" "prefix out of range [0, ${builtins.toString prefixMax}]: ${builtins.toString checkedPrefix}"
    else
      mk checkedAddress checkedPrefix;

  /*
    Build a host-only interface address, parallel to `cidr.fromAddress`.

    `addressValue`: ipv4 or ipv6 value.

    Returns an interfaceAddress with prefix /32 (IPv4) or /128 (IPv6);
    throws on a non-address.
  */
  fromAddress =
    addressValue:
    let
      checked = addressArgument "fromAddress" addressValue;
    in
    mk checked (maxPrefix checked);

  /*
    Build an interface address from a CIDR and an address on it,
    checking that the CIDR contains the address. The CIDR comes first, so
    `map (fromCidrAndAddress block) addresses` works.

    `cidrValue`: cidr value.
    `addressValue`: ipv4 or ipv6 value of the same family inside
    `cidrValue`.

    Returns an interfaceAddress with the CIDR's prefix; throws on a
    non-cidr, non-address, family mismatch, or an address outside the
    CIDR.
  */
  fromCidrAndAddress =
    cidrValue: addressValue:
    let
      block = errors.expectKind "interfaceAddress.fromCidrAndAddress" "cidr" cidrValue;
      checkedAddress = addressArgument "fromCidrAndAddress" addressValue;
    in
    if checkedAddress._type != block.networkAddress._type then
      errors.fail "interfaceAddress.fromCidrAndAddress" "family mismatch"
    else if !(cidr.contains block checkedAddress) then
      errors.fail "interfaceAddress.fromCidrAndAddress" "address not in cidr"
    else
      mk checkedAddress block.prefix;

  # ===== Predicates =====

  /*
    Check whether a value is an interfaceAddress value.

    `value`: any value.

    Returns true when `value` is tagged `_type = "interfaceAddress"`.
  */
  is = value: types.isInterfaceAddress value;

  /*
    Check whether an interface address holds an IPv4 address.

    `interfaceAddress`: interfaceAddress value.

    Returns true for IPv4.
  */
  isIpv4 = interfaceAddress: isV4 (interfaceAddressArgument "isIpv4" interfaceAddress).address;

  /*
    Check whether an interface address holds an IPv6 address.

    `interfaceAddress`: interfaceAddress value.

    Returns true for IPv6.
  */
  isIpv6 = interfaceAddress: isV6 (interfaceAddressArgument "isIpv6" interfaceAddress).address;

  # ===== Forwarded predicates (apply to the address) =====

  # Apply the family's function to the address of the interface address
  # that the public `function` was given.
  forwardToAddress =
    function: ipv4Function: ipv6Function: interfaceAddress:
    let
      inherit (interfaceAddressArgument function interfaceAddress) address;
    in
    if isV4 address then ipv4Function address else ipv6Function address;

  /*
    Check whether the address is a loopback address.

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isLoopback` or `ipv6.isLoopback` of the address.
  */
  isLoopback =
    interfaceAddress: forwardToAddress "isLoopback" ipv4.isLoopback ipv6.isLoopback interfaceAddress;

  /*
    Check whether the address is the unspecified address.

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isUnspecified` or `ipv6.isUnspecified` of the address.
  */
  isUnspecified =
    interfaceAddress:
    forwardToAddress "isUnspecified" ipv4.isUnspecified ipv6.isUnspecified interfaceAddress;

  /*
    Check whether the address is link-local.

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isLinkLocal` or `ipv6.isLinkLocal` of the address.
  */
  isLinkLocal =
    interfaceAddress: forwardToAddress "isLinkLocal" ipv4.isLinkLocal ipv6.isLinkLocal interfaceAddress;

  /*
    Check whether the address is multicast.

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isMulticast` or `ipv6.isMulticast` of the address.
  */
  isMulticast =
    interfaceAddress: forwardToAddress "isMulticast" ipv4.isMulticast ipv6.isMulticast interfaceAddress;

  /*
    Check whether the address is reserved for documentation.

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isDocumentation` or `ipv6.isDocumentation` of the
    address.
  */
  isDocumentation =
    interfaceAddress:
    forwardToAddress "isDocumentation" ipv4.isDocumentation ipv6.isDocumentation interfaceAddress;

  /*
    Check whether the address is globally routable, using the family's
    rules (IPv6 also excludes transition forms).

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isGlobal` or `ipv6.isGlobal` of the address.
  */
  isGlobal =
    interfaceAddress: forwardToAddress "isGlobal" ipv4.isGlobal ipv6.isGlobal interfaceAddress;

  /*
    Check whether the address is a bogon (not globally routable).

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isBogon` or `ipv6.isBogon` of the address.
  */
  isBogon = interfaceAddress: forwardToAddress "isBogon" ipv4.isBogon ipv6.isBogon interfaceAddress;

  /*
    Format the address as a reverse-DNS name.

    `interfaceAddress`: interfaceAddress value.

    Returns the address's in-addr.arpa or ip6.arpa name; the prefix is
    ignored.
  */
  toArpa = forwardToAddress "toArpa" ipv4.toArpa ipv6.toArpa;

  # ===== Accessors =====

  /*
    Get the host address.

    `interfaceAddress`: interfaceAddress value.

    Returns the ipv4 or ipv6 value, host bits intact.
  */
  address = interfaceAddress: (interfaceAddressArgument "address" interfaceAddress).address;

  /*
    Get the prefix length.

    `interfaceAddress`: interfaceAddress value.

    Returns the prefix length as an integer.
  */
  prefix = interfaceAddress: (interfaceAddressArgument "prefix" interfaceAddress).prefix;

  /*
    Get the IP version of the address.

    `interfaceAddress`: interfaceAddress value.

    Returns 4 or 6.
  */
  version =
    interfaceAddress:
    if isV4 (interfaceAddressArgument "version" interfaceAddress).address then 4 else 6;

  # Derive the CIDR the checked address sits on.
  cidrOf =
    interfaceAddress:
    cidr.supernet (maxPrefix interfaceAddress.address - interfaceAddress.prefix) (
      cidr.fromAddress interfaceAddress.address
    );

  /*
    Derive the netmask for the prefix.

    `interfaceAddress`: interfaceAddress value.

    Returns an address value of the same family with the prefix bits set.
  */
  netmask =
    interfaceAddress: cidr.netmask (cidrOf (interfaceAddressArgument "netmask" interfaceAddress));

  /*
    Derive the hostmask (inverse netmask) for the prefix.

    `interfaceAddress`: interfaceAddress value.

    Returns an address value of the same family with the host bits set.
  */
  hostmask =
    interfaceAddress: cidr.hostmask (cidrOf (interfaceAddressArgument "hostmask" interfaceAddress));

  /*
    Derive the IPv4 broadcast address of the CIDR the address sits on.

    `interfaceAddress`: IPv4 interfaceAddress value of prefix /30 or
    shorter.

    Returns an ipv4 value; throws for IPv6, which has no broadcast, and
    for /31 and /32, whose addresses are all hosts (RFC 3021).
  */
  broadcast =
    interfaceAddress:
    let
      checked = interfaceAddressArgument "broadcast" interfaceAddress;
    in
    if !(isV4 checked.address) then
      errors.fail "interfaceAddress.broadcast" "IPv6 has no broadcast"
    else if checked.prefix == 31 then
      errors.fail "interfaceAddress.broadcast" "/31 has no broadcast (RFC 3021)"
    else if checked.prefix == 32 then
      errors.fail "interfaceAddress.broadcast" "/32 has no broadcast"
    else
      cidr.broadcast (cidrOf checked);

  # ===== Comparison =====

  /*
    Test two interface addresses for equality.

    `a`, `b`: interfaceAddress values.

    Returns true when the type tag, family, address, and prefix match.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.interfaceAddress a b
    && a.address._type == b.address._type
    && a.prefix == b.prefix
    && (if isV4 a.address then ipv4.eq a.address b.address else ipv6.eq a.address b.address);

  order =
    a: b:
    comparison.lexicographic [
      (ip.compare a.address b.address)
      (comparison.order a.prefix b.prefix)
    ];

  ordering = comparison.suite (function: binary function order);
in
{
  inherit
    address
    broadcast
    eq
    fromAddress
    fromCidrAndAddress
    hostmask
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
    make
    netmask
    prefix
    toArpa
    toString
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

  # Defined here rather than in `let`, where `cidr` names the cidr module.
  /*
    Derive the CIDR the address sits on.

    `interfaceAddress`: interfaceAddress value.

    Returns a cidr value.
  */
  cidr = interfaceAddress: cidrOf (interfaceAddressArgument "cidr" interfaceAddress);
}
