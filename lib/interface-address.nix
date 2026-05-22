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
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  cidr = import ./cidr.nix;
  ipRange = import ./ip-range.nix;

  mk = addr: prefix: {
    _type = "interfaceAddress";
    address = addr;
    inherit prefix;
  };

  isV4 = addr: addr._type == "ipv4";

  maxPrefix = addr: if isV4 addr then 32 else 128;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.interfaceAddress.parse: input must be a string"
    else
      let
        parts = parse'.splitOn "/" s;
      in
      if builtins.length parts != 2 then
        types.tryErr "libnet.interfaceAddress.parse: missing '/': \"${s}\""
      else
        let
          addrStr = builtins.elemAt parts 0;
          prefStr = builtins.elemAt parts 1;
          isV6Str = parse'.countOccurrences ":" addrStr > 0;
          addrRes = if isV6Str then ipv6.tryParse addrStr else ipv4.tryParse addrStr;
          prefInt = parse'.decimal prefStr;
        in
        if !addrRes.success then
          types.tryErr "libnet.interfaceAddress.parse: ${addrRes.error}"
        else if prefInt == null then
          types.tryErr "libnet.interfaceAddress.parse: invalid prefix \"${prefStr}\""
        else if prefInt > maxPrefix addrRes.value then
          types.tryErr "libnet.interfaceAddress.parse: prefix /${prefStr} out of range"
        else
          types.tryOk (mk addrRes.value prefInt);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  # ===== Formatting =====

  # Canonical text form is `<address>/<prefix>` with the host bits kept
  # (same string shape as a CIDR; the distinction is in the type tag).
  toString =
    i:
    let
      s = if isV4 i.address then ipv4.toString i.address else ipv6.toString i.address;
    in
    "${s}/${builtins.toString i.prefix}";

  # ===== Construction =====

  make =
    addr: prefix:
    if !(types.isIp addr) then
      builtins.throw "libnet.interfaceAddress.make: address must be ipv4 or ipv6"
    else if !(builtins.isInt prefix) || prefix < 0 || prefix > maxPrefix addr then
      builtins.throw "libnet.interfaceAddress.make: prefix out of range"
    else
      mk addr prefix;

  fromAddress =
    addr:
    if !(types.isIp addr) then
      builtins.throw "libnet.interfaceAddress.fromAddress: expected ipv4 or ipv6 value"
    else
      mk addr (maxPrefix addr);

  fromAddressAndNetwork =
    addr: net:
    if !(types.isIp addr) then
      builtins.throw "libnet.interfaceAddress.fromAddressAndNetwork: address must be ipv4 or ipv6"
    else if !(types.isCidr net) then
      builtins.throw "libnet.interfaceAddress.fromAddressAndNetwork: expected cidr as network"
    else if addr._type != net.address._type then
      builtins.throw "libnet.interfaceAddress.fromAddressAndNetwork: family mismatch"
    else if !(cidr.containsAddress net addr) then
      builtins.throw "libnet.interfaceAddress.fromAddressAndNetwork: address not in network"
    else
      mk addr net.prefix;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isInterfaceAddress;
  isIpv4 = i: isV4 i.address;
  isIpv6 = i: !(isV4 i.address);

  # ===== Forwarded predicates (apply to the address) =====

  fwd =
    v4Fn: v6Fn: i:
    if isV4 i.address then v4Fn i.address else v6Fn i.address;

  isLoopback = fwd ipv4.isLoopback ipv6.isLoopback;
  isUnspecified = fwd ipv4.isUnspecified ipv6.isUnspecified;
  isLinkLocal = fwd ipv4.isLinkLocal ipv6.isLinkLocal;
  isMulticast = fwd ipv4.isMulticast ipv6.isMulticast;
  isDocumentation = fwd ipv4.isDocumentation ipv6.isDocumentation;
  isGlobal = fwd ipv4.isGlobal ipv6.isGlobal;
  isBogon = fwd ipv4.isBogon ipv6.isBogon;

  toArpa = i: if isV4 i.address then ipv4.toArpa i.address else ipv6.toArpa i.address;

  # ===== Accessors =====

  address = i: i.address;
  prefix = i: i.prefix;
  version = i: if isV4 i.address then 4 else 6;

  network = i: cidr.canonical (cidr.make i.address i.prefix);
  netmask = i: cidr.netmask (cidr.make i.address i.prefix);
  hostmask = i: cidr.hostmask (cidr.make i.address i.prefix);

  broadcast =
    i:
    if !(isV4 i.address) then
      builtins.throw "libnet.interfaceAddress.broadcast: IPv6 has no broadcast"
    else
      cidr.broadcast (cidr.make i.address i.prefix);

  # ===== Conversions =====

  # Preserves the host bits — unlike `network`, which returns the
  # canonical (host-zeroed) block. Mirrors Python's IPv4Interface, where
  # the string form keeps the host but `.network` does not.
  toCidr = i: cidr.make i.address i.prefix;

  toRange = i: ipRange.fromCidr (network i);

  # ===== Comparison =====

  eq =
    a: b:
    a.address._type == b.address._type
    && a.prefix == b.prefix
    && (if isV4 a.address then ipv4.eq a.address b.address else ipv6.eq a.address b.address);

  # Strict total order: v4 < v6, then by address, then by prefix.
  compare =
    a: b:
    if isV4 a.address && !(isV4 b.address) then
      -1
    else if !(isV4 a.address) && isV4 b.address then
      1
    else
      let
        addrCmp =
          if isV4 a.address then ipv4.compare a.address b.address else ipv6.compare a.address b.address;
      in
      if addrCmp != 0 then
        addrCmp
      else if a.prefix < b.prefix then
        -1
      else if a.prefix > b.prefix then
        1
      else
        0;

  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;
in
{
  inherit
    parse
    tryParse
    toString
    make
    fromAddress
    fromAddressAndNetwork
    ;
  inherit
    isValid
    is
    isIpv4
    isIpv6
    ;
  inherit
    isLoopback
    isUnspecified
    isLinkLocal
    isMulticast
    isDocumentation
    isGlobal
    isBogon
    toArpa
    ;
  inherit
    address
    prefix
    version
    network
    netmask
    hostmask
    broadcast
    ;
  inherit toCidr toRange;
  inherit
    eq
    lt
    le
    gt
    ge
    compare
    min
    max
    ;
}
