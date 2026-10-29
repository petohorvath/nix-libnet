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
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  cidr = import ./cidr.nix;

  # Force both fields, so a constructor throws for a bad argument when
  # it builds the value rather than when a field is read.
  mk =
    addressValue: prefixLength:
    builtins.seq addressValue (
      builtins.seq prefixLength {
        _type = "interfaceAddress";
        address = addressValue;
        prefix = prefixLength;
      }
    );

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
    Parse an interface address without throwing, so callers can handle
    invalid input themselves.

    `input`: "<address>/<prefix>", such as "192.168.1.5/24" or
    "2001:db8::5/64"; the prefix must fit the address family.

    Returns a tryResult: `{ success = true; value = <interfaceAddress>; }`
    or `{ success = false; error = <message>; }`.
  */
  tryParse =
    input:
    let
      parseError = detail: types.tryErr (errors.message "interfaceAddress.parse" detail);
    in
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else
      let
        parts = parsing.splitOn "/" input;
      in
      if builtins.length parts != 2 then
        parseError "missing '/': \"${input}\""
      else
        let
          addressInput = builtins.elemAt parts 0;
          prefixInput = builtins.elemAt parts 1;
          isV6Input = parsing.countOccurrences ":" addressInput > 0;
          addressResult = if isV6Input then ipv6.tryParse addressInput else ipv4.tryParse addressInput;
          prefixLength = parsing.decimal (maxPrefix addressResult.value) prefixInput;
        in
        if !addressResult.success then
          parseError (errors.detail (if isV6Input then "ipv6.parse" else "ipv4.parse") addressResult.error)
        else if !(parsing.isDecimal prefixInput) then
          parseError "invalid prefix \"${prefixInput}\""
        else if prefixLength == null then
          parseError "prefix /${prefixInput} out of range"
        else
          types.tryOk (mk addressResult.value prefixLength);

  /*
    Parse an interface address from text, such as a per-NIC address
    assignment. The host bits are kept, not zeroed to the network address.

    `input`: "<address>/<prefix>", such as "192.168.1.5/24" or
    "2001:db8::5/64"; the prefix must fit the address family.

    Returns an interfaceAddress value; throws on malformed input or a
    missing or out-of-range prefix.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

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
      checkedPrefix = errors.expectType "interfaceAddress.make" "int" prefixLength;
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
    Check whether a string parses as an interface address.

    `input`: candidate string.

    Returns true when `tryParse input` succeeds.
  */
  isValid = input: (tryParse input).success;

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

    `interfaceAddress`: IPv4 interfaceAddress value.

    Returns an ipv4 value; throws for IPv6, which has no broadcast.
  */
  broadcast =
    interfaceAddress:
    let
      checked = interfaceAddressArgument "broadcast" interfaceAddress;
    in
    if !(isV4 checked.address) then
      errors.fail "interfaceAddress.broadcast" "IPv6 has no broadcast"
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
    if isV4 a.address && !(isV4 b.address) then
      -1
    else if !(isV4 a.address) && isV4 b.address then
      1
    else
      let
        addressOrder =
          if isV4 a.address then ipv4.compare a.address b.address else ipv6.compare a.address b.address;
      in
      if addressOrder != 0 then
        addressOrder
      else if a.prefix < b.prefix then
        -1
      else if a.prefix > b.prefix then
        1
      else
        0;

  /*
    Order two interface addresses: IPv4 before IPv6, then by address,
    then by prefix.

    `a`, `b`: interfaceAddress values.

    Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`.
  */
  compare = binary "compare" order;

  /*
    Test whether one interface address sorts before another.

    `a`, `b`: interfaceAddress values.

    Returns true when `compare a b == -1`.
  */
  lt = binary "lt" (a: b: order a b == -1);

  /*
    Test whether one interface address sorts before or equal to another.

    `a`, `b`: interfaceAddress values.

    Returns true when `compare a b <= 0`.
  */
  le = binary "le" (a: b: order a b <= 0);

  /*
    Test whether one interface address sorts after another.

    `a`, `b`: interfaceAddress values.

    Returns true when `compare a b == 1`.
  */
  gt = binary "gt" (a: b: order a b == 1);

  /*
    Test whether one interface address sorts after or equal to another.

    `a`, `b`: interfaceAddress values.

    Returns true when `compare a b >= 0`.
  */
  ge = binary "ge" (a: b: order a b >= 0);

  /*
    Pick the earlier of two interface addresses in sort order.

    `a`, `b`: interfaceAddress values.

    Returns the lesser value; `a` when they compare equal.
  */
  min = binary "min" (a: b: if order a b <= 0 then a else b);

  /*
    Pick the later of two interface addresses in sort order.

    `a`, `b`: interfaceAddress values.

    Returns the greater value; `a` when they compare equal.
  */
  max = binary "max" (a: b: if order a b >= 0 then a else b);
in
{
  inherit
    address
    broadcast
    compare
    eq
    fromAddress
    fromCidrAndAddress
    ge
    gt
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
    isValid
    le
    lt
    make
    max
    min
    netmask
    parse
    prefix
    toArpa
    toString
    tryParse
    version
    ;

  # Defined here rather than in `let`, where `cidr` names the cidr module.
  /*
    Derive the CIDR the address sits on.

    `interfaceAddress`: interfaceAddress value.

    Returns a cidr value.
  */
  cidr = interfaceAddress: cidrOf (interfaceAddressArgument "cidr" interfaceAddress);
}
