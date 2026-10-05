/*
  libnet.interfaceAddress

  An address-on-subnet descriptor: a host address (ipv4 or ipv6) paired
  with a prefix length — e.g. `192.168.1.10/24`. The pure-Nix analog of
  Python's `IPv4Interface` / `IPv6Interface`.

  Distinct from `cidr`: a `cidr` is a network/block with the host bits
  zeroed (`192.168.1.0/24`), whereas an `interfaceAddress` keeps the host
  bits significant (`192.168.1.10/24` — a specific host's address plus
  its subnet). The two never compare `eq` (different `_type`); `toCidr`
  converts (preserving host bits), `network` derives the canonical block.

  The interface *name* (the NIC identifier, `eth0`) is a separate type:
  `libnet.interfaceName`.

  Example:
    libnet.interfaceAddress.parse "192.168.1.10/24"
    => { _type = "interfaceAddress"; address = <ipv4>; prefix = 24; }
*/
let
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  cidr = import ./cidr.nix;
  ipRange = import ./ip-range.nix;

  mk = addressValue: prefixLength: {
    _type = "interfaceAddress";
    address = addressValue;
    prefix = prefixLength;
  };

  isV4 = addressValue: addressValue._type == "ipv4";
  isV6 = addressValue: addressValue._type == "ipv6";

  maxPrefix = addressValue: if isV4 addressValue then 32 else 128;

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
    if !(builtins.isString input) then
      types.tryErr "libnet.interfaceAddress.parse: input must be a string"
    else
      let
        parts = parsing.splitOn "/" input;
      in
      if builtins.length parts != 2 then
        types.tryErr "libnet.interfaceAddress.parse: missing '/': \"${input}\""
      else
        let
          addressInput = builtins.elemAt parts 0;
          prefixInput = builtins.elemAt parts 1;
          isV6Input = parsing.countOccurrences ":" addressInput > 0;
          addressResult = if isV6Input then ipv6.tryParse addressInput else ipv4.tryParse addressInput;
          prefixLength = parsing.decimal prefixInput;
        in
        if !addressResult.success then
          types.tryErr "libnet.interfaceAddress.parse: ${addressResult.error}"
        else if prefixLength == null then
          types.tryErr "libnet.interfaceAddress.parse: invalid prefix \"${prefixInput}\""
        else if prefixLength > maxPrefix addressResult.value then
          types.tryErr "libnet.interfaceAddress.parse: prefix /${prefixInput} out of range"
        else
          types.tryOk (mk addressResult.value prefixLength);

  /*
    Parse an interface address from text, such as a per-NIC address
    assignment. The host bits are kept, not zeroed to the network.

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
      addressText =
        if isV4 interfaceAddress.address then
          ipv4.toString interfaceAddress.address
        else
          ipv6.toString interfaceAddress.address;
    in
    "${addressText}/${builtins.toString interfaceAddress.prefix}";

  # ===== Construction =====

  /*
    Build an interface address from an address and prefix length.

    `addressValue`: ipv4 or ipv6 value; host bits are kept.
    `prefixLength`: integer in [0, 32] for IPv4 or [0, 128] for IPv6.

    Returns an interfaceAddress value; throws on a non-address or an
    out-of-range prefix.
  */
  make =
    addressValue: prefixLength:
    if !(types.isIp addressValue) then
      throw "libnet.interfaceAddress.make: address must be ipv4 or ipv6"
    else if
      !(builtins.isInt prefixLength) || prefixLength < 0 || prefixLength > maxPrefix addressValue
    then
      throw "libnet.interfaceAddress.make: prefix out of range"
    else
      mk addressValue prefixLength;

  /*
    Build a host-only interface address, parallel to `cidr.fromAddress`.

    `addressValue`: ipv4 or ipv6 value.

    Returns an interfaceAddress with prefix /32 (IPv4) or /128 (IPv6);
    throws on a non-address.
  */
  fromAddress =
    addressValue:
    if !(types.isIp addressValue) then
      throw "libnet.interfaceAddress.fromAddress: expected ipv4 or ipv6 value"
    else
      mk addressValue (maxPrefix addressValue);

  /*
    Build an interface address from a host and the network it sits in,
    checking that the host belongs to that network.

    `addressValue`: ipv4 or ipv6 value.
    `networkCidr`: cidr value of the same family containing the address.

    Returns an interfaceAddress with the network's prefix; throws on a
    non-address, non-cidr, family mismatch, or an address outside the
    network.
  */
  fromAddressAndNetwork =
    addressValue: networkCidr:
    if !(types.isIp addressValue) then
      throw "libnet.interfaceAddress.fromAddressAndNetwork: address must be ipv4 or ipv6"
    else if !(types.isCidr networkCidr) then
      throw "libnet.interfaceAddress.fromAddressAndNetwork: expected cidr as network"
    else if addressValue._type != networkCidr.address._type then
      throw "libnet.interfaceAddress.fromAddressAndNetwork: family mismatch"
    else if !(cidr.containsAddress networkCidr addressValue) then
      throw "libnet.interfaceAddress.fromAddressAndNetwork: address not in network"
    else
      mk addressValue networkCidr.prefix;

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
  isIpv4 = interfaceAddress: isV4 interfaceAddress.address;

  /*
    Check whether an interface address holds an IPv6 address.

    `interfaceAddress`: interfaceAddress value.

    Returns true for IPv6.
  */
  isIpv6 = interfaceAddress: isV6 interfaceAddress.address;

  # ===== Forwarded predicates (apply to the address) =====

  # Apply the family's function to the interface's address.
  forwardToAddress =
    ipv4Function: ipv6Function: interfaceAddress:
    if isV4 interfaceAddress.address then
      ipv4Function interfaceAddress.address
    else
      ipv6Function interfaceAddress.address;

  /*
    Check whether the address is a loopback address.

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isLoopback` or `ipv6.isLoopback` of the address.
  */
  isLoopback = interfaceAddress: forwardToAddress ipv4.isLoopback ipv6.isLoopback interfaceAddress;

  /*
    Check whether the address is the unspecified address.

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isUnspecified` or `ipv6.isUnspecified` of the address.
  */
  isUnspecified =
    interfaceAddress: forwardToAddress ipv4.isUnspecified ipv6.isUnspecified interfaceAddress;

  /*
    Check whether the address is link-local.

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isLinkLocal` or `ipv6.isLinkLocal` of the address.
  */
  isLinkLocal = interfaceAddress: forwardToAddress ipv4.isLinkLocal ipv6.isLinkLocal interfaceAddress;

  /*
    Check whether the address is multicast.

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isMulticast` or `ipv6.isMulticast` of the address.
  */
  isMulticast = interfaceAddress: forwardToAddress ipv4.isMulticast ipv6.isMulticast interfaceAddress;

  /*
    Check whether the address is reserved for documentation.

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isDocumentation` or `ipv6.isDocumentation` of the
    address.
  */
  isDocumentation =
    interfaceAddress: forwardToAddress ipv4.isDocumentation ipv6.isDocumentation interfaceAddress;

  /*
    Check whether the address is globally routable, using the family's
    rules (IPv6 also excludes transition forms).

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isGlobal` or `ipv6.isGlobal` of the address.
  */
  isGlobal = interfaceAddress: forwardToAddress ipv4.isGlobal ipv6.isGlobal interfaceAddress;

  /*
    Check whether the address is a bogon (not globally routable).

    `interfaceAddress`: interfaceAddress value.

    Returns `ipv4.isBogon` or `ipv6.isBogon` of the address.
  */
  isBogon = interfaceAddress: forwardToAddress ipv4.isBogon ipv6.isBogon interfaceAddress;

  /*
    Format the address as a reverse-DNS name.

    `interfaceAddress`: interfaceAddress value.

    Returns the address's in-addr.arpa or ip6.arpa name; the prefix is
    ignored.
  */
  toArpa =
    interfaceAddress:
    if isV4 interfaceAddress.address then
      ipv4.toArpa interfaceAddress.address
    else
      ipv6.toArpa interfaceAddress.address;

  # ===== Accessors =====

  /*
    Get the host address.

    `interfaceAddress`: interfaceAddress value.

    Returns the ipv4 or ipv6 value, host bits intact.
  */
  address = interfaceAddress: interfaceAddress.address;

  /*
    Get the prefix length.

    `interfaceAddress`: interfaceAddress value.

    Returns the prefix length as an integer.
  */
  prefix = interfaceAddress: interfaceAddress.prefix;

  /*
    Get the IP version of the address.

    `interfaceAddress`: interfaceAddress value.

    Returns 4 or 6.
  */
  version = interfaceAddress: if isV4 interfaceAddress.address then 4 else 6;

  /*
    Derive the canonical network the host belongs to.

    `interfaceAddress`: interfaceAddress value.

    Returns a cidr value with the host bits zeroed.
  */
  network =
    interfaceAddress: cidr.canonical (cidr.make interfaceAddress.address interfaceAddress.prefix);

  /*
    Derive the netmask for the prefix.

    `interfaceAddress`: interfaceAddress value.

    Returns an address value of the same family with the prefix bits set.
  */
  netmask =
    interfaceAddress: cidr.netmask (cidr.make interfaceAddress.address interfaceAddress.prefix);

  /*
    Derive the hostmask (inverse netmask) for the prefix.

    `interfaceAddress`: interfaceAddress value.

    Returns an address value of the same family with the host bits set.
  */
  hostmask =
    interfaceAddress: cidr.hostmask (cidr.make interfaceAddress.address interfaceAddress.prefix);

  /*
    Derive the IPv4 broadcast address of the host's network.

    `interfaceAddress`: IPv4 interfaceAddress value.

    Returns an ipv4 value; throws for IPv6, which has no broadcast.
  */
  broadcast =
    interfaceAddress:
    if !(isV4 interfaceAddress.address) then
      throw "libnet.interfaceAddress.broadcast: IPv6 has no broadcast"
    else
      cidr.broadcast (cidr.make interfaceAddress.address interfaceAddress.prefix);

  # ===== Conversions =====

  /*
    Convert to a cidr value that keeps the host bits, unlike `network`,
    which zeroes them. Mirrors Python's IPv4Interface, whose string form
    keeps the host but whose `.network` does not.

    `interfaceAddress`: interfaceAddress value.

    Returns a possibly non-canonical cidr value.
  */
  toCidr = interfaceAddress: cidr.make interfaceAddress.address interfaceAddress.prefix;

  /*
    Convert the host's network to an address range.

    `interfaceAddress`: interfaceAddress value.

    Returns the ipRange covering `network interfaceAddress`.
  */
  toRange = interfaceAddress: ipRange.fromCidr (network interfaceAddress);

  # ===== Comparison =====

  /*
    Test two interface addresses for equality.

    `a`, `b`: interfaceAddress values.

    Returns true when the type tag, family, address, and prefix match.
  */
  eq =
    a: b:
    types.hasSameTag a b
    && a.address._type == b.address._type
    && a.prefix == b.prefix
    && (if isV4 a.address then ipv4.eq a.address b.address else ipv6.eq a.address b.address);

  /*
    Order two interface addresses: IPv4 before IPv6, then by address,
    then by prefix.

    `a`, `b`: interfaceAddress values.

    Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`.
  */
  compare =
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
    Test whether one interface address sorts before another.

    `a`, `b`: interfaceAddress values.

    Returns true when `compare a b == -1`.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether one interface address sorts before or equal to another.

    `a`, `b`: interfaceAddress values.

    Returns true when `compare a b <= 0`.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether one interface address sorts after another.

    `a`, `b`: interfaceAddress values.

    Returns true when `compare a b == 1`.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether one interface address sorts after or equal to another.

    `a`, `b`: interfaceAddress values.

    Returns true when `compare a b >= 0`.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the earlier of two interface addresses in sort order.

    `a`, `b`: interfaceAddress values.

    Returns the lesser value; `a` when they compare equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the later of two interface addresses in sort order.

    `a`, `b`: interfaceAddress values.

    Returns the greater value; `a` when they compare equal.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    address
    broadcast
    compare
    eq
    fromAddress
    fromAddressAndNetwork
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
    network
    parse
    prefix
    toArpa
    toCidr
    toRange
    toString
    tryParse
    version
    ;
}
