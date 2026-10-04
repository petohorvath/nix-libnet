/*
  libnet.cidr

  Parse and operate on CIDR blocks (IPv4 and IPv6). Provides network,
  broadcast, and host derivation, prefix arithmetic (subnet, supernet),
  and set operations (summarize, exclude, intersect).

  Example:
    libnet.cidr.parse "192.0.2.0/24"
    => { _type = "cidr"; address = <ipv4 192.0.2.0>; prefix = 24; }

    libnet.cidr.toString (libnet.cidr.parse "2001:DB8::/32")
    => "2001:db8::/32"
*/
let
  bits = import ./internal/bits.nix;
  carry = import ./internal/carry.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;

  mk = ip: prefixLength: {
    _type = "cidr";
    address = ip;
    prefix = prefixLength;
  };

  isV4 = ip: ip._type == "ipv4";
  isV6 = ip: ip._type == "ipv6";

  maxPrefix = ip: if isV4 ip then 32 else 128;

  # ===== Parsing =====

  /*
    Parse a CIDR block without throwing, for callers that validate
    untrusted text.

    `input`: `address/prefix` string such as `10.0.0.0/24` or
    `2001:db8::/32`; host bits may be set.

    Returns a tryParse result whose `value` is a cidr value.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.cidr.parse: input must be a string"
    else
      let
        parts = parsing.splitOn "/" input;
      in
      if builtins.length parts != 2 then
        types.tryErr "libnet.cidr.parse: missing '/': \"${input}\""
      else
        let
          addressText = builtins.elemAt parts 0;
          prefixText = builtins.elemAt parts 1;
          isIpv6Text = parsing.countOccurrences ":" addressText > 0;
          addressResult = if isIpv6Text then ipv6.tryParse addressText else ipv4.tryParse addressText;
          prefixLength = parsing.decimal prefixText;
        in
        if !addressResult.success then
          types.tryErr "libnet.cidr.parse: ${addressResult.error}"
        else if prefixLength == null then
          types.tryErr "libnet.cidr.parse: invalid prefix \"${prefixText}\""
        else if prefixLength > (maxPrefix addressResult.value) then
          types.tryErr "libnet.cidr.parse: prefix /${prefixText} out of range"
        else
          types.tryOk (mk addressResult.value prefixLength);

  /*
    Parse a CIDR block from its text form.

    `input`: `address/prefix` string such as `10.0.0.0/24` or
    `2001:db8::/32`; host bits may be set.

    Returns a cidr value storing the address as given; throws on invalid
    input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Format a CIDR block as `address/prefix`.

    `cidr`: cidr value.

    Returns a string using the stored address, which may be non-canonical.
  */
  toString =
    cidr:
    let
      addressText = if isV4 cidr.address then ipv4.toString cidr.address else ipv6.toString cidr.address;
    in
    "${addressText}/${builtins.toString cidr.prefix}";

  /*
    Build a CIDR block from an address and a prefix length.

    `ip`: ipv4 or ipv6 value; host bits may be set.
    `prefixLength`: integer in [0, 32] for IPv4 or [0, 128] for IPv6.

    Returns a cidr value; throws on a non-address or out-of-range prefix.
  */
  make =
    ip: prefixLength:
    if !(types.isIp ip) then
      throw "libnet.cidr.make: address must be ipv4 or ipv6"
    else if !(builtins.isInt prefixLength) || prefixLength < 0 || prefixLength > (maxPrefix ip) then
      throw "libnet.cidr.make: prefix out of range"
    else
      mk ip prefixLength;

  /*
    Wrap a single address as a host-sized block.

    `ip`: ipv4 or ipv6 value.

    Returns a /32 or /128 cidr value; throws for any other value.
  */
  fromAddress =
    ip:
    if !(types.isIp ip) then
      throw "libnet.cidr.fromAddress: expected ipv4 or ipv6 value"
    else
      mk ip (maxPrefix ip);

  # ===== Accessors / predicates =====

  /*
    Read the address stored in a CIDR block.

    `cidr`: cidr value.

    Returns the ipv4 or ipv6 value as given, host bits included.
  */
  address = cidr: cidr.address;

  /*
    Read the prefix length of a CIDR block.

    `cidr`: cidr value.

    Returns an integer.
  */
  prefix = cidr: cidr.prefix;

  /*
    Report the address family of a CIDR block.

    `cidr`: cidr value.

    Returns 4 or 6.
  */
  version = cidr: if isV4 cidr.address then 4 else 6;

  /*
    Check whether a CIDR block is IPv4.

    `cidr`: cidr value.

    Returns a Boolean.
  */
  isIpv4 = cidr: isV4 cidr.address;

  /*
    Check whether a CIDR block is IPv6.

    `cidr`: cidr value.

    Returns a Boolean.
  */
  isIpv6 = cidr: isV6 cidr.address;

  /*
    Check whether a string parses as a CIDR block.

    `input`: value to test.

    Returns a Boolean; never throws.
  */
  isValid = input: (tryParse input).success;

  /*
    Structural check for a tagged CIDR block.

    `value`: any value.

    Returns true only for cidr values.
  */
  is = value: types.isCidr value;

  # ===== Mask helpers =====

  # IPv4 netmask as an unsigned 32-bit int.
  netmaskV4Int =
    prefixLength:
    if prefixLength == 0 then
      0
    else if prefixLength == 32 then
      bits.mask32
    else
      bits.shl (32 - prefixLength) (bits.mask prefixLength);

  hostmaskV4Int = prefixLength: bits.mask32 - (netmaskV4Int prefixLength);

  # Netmask bits of IPv6 word `i` (0..3) for the whole-address prefix length.
  wordMaskIpv6 =
    i: prefixLength:
    let
      keptBits = prefixLength - 32 * i;
    in
    if keptBits <= 0 then
      0
    else if keptBits >= 32 then
      bits.mask32
    else
      bits.shl (32 - keptBits) (bits.mask keptBits);

  wordHostmaskIpv6 = i: prefixLength: bits.mask32 - (wordMaskIpv6 i prefixLength);

  # ===== Derived values =====

  /*
    Compute the network address of a CIDR block.

    `cidr`: cidr value.

    Returns the stored address with its host bits zeroed.
  */
  network =
    cidr:
    let
      prefixLength = cidr.prefix;
      ip = cidr.address;
    in
    if isV4 ip then
      ipv4.fromInt (builtins.bitAnd ip.value (netmaskV4Int prefixLength))
    else
      ipv6.fromWords (
        builtins.genList (i: builtins.bitAnd (builtins.elemAt ip.words i) (wordMaskIpv6 i prefixLength)) 4
      );

  /*
    Compute the IPv4 broadcast address of a CIDR block.

    `cidr`: IPv4 cidr value.

    Returns the ipv4 value with all host bits set; throws for IPv6, which
    has no broadcast.
  */
  broadcast =
    cidr:
    if isV6 cidr.address then
      throw "libnet.cidr.broadcast: IPv6 has no broadcast"
    else
      let
        base = network cidr;
      in
      ipv4.fromInt (builtins.bitOr base.value (hostmaskV4Int cidr.prefix));

  /*
    Compute the highest address of a CIDR block in either family.

    `cidr`: cidr value.

    Returns the network address with all host bits set.
  */
  topAddress =
    cidr:
    let
      base = network cidr;
      prefixLength = cidr.prefix;
    in
    if isV4 cidr.address then
      ipv4.fromInt (builtins.bitOr base.value (hostmaskV4Int prefixLength))
    else
      ipv6.fromWords (
        builtins.genList (
          i: builtins.bitOr (builtins.elemAt base.words i) (wordHostmaskIpv6 i prefixLength)
        ) 4
      );

  /*
    Express the prefix length as an address-form netmask.

    `cidr`: cidr value.

    Returns an address of the block's family, e.g. `255.255.255.0` for /24.
  */
  netmask =
    cidr:
    if isV4 cidr.address then
      ipv4.fromInt (netmaskV4Int cidr.prefix)
    else
      ipv6.fromWords (builtins.genList (i: wordMaskIpv6 i cidr.prefix) 4);

  /*
    Express the host part as an address-form mask, the inverse of
    `netmask`.

    `cidr`: cidr value.

    Returns an address of the block's family, e.g. `0.0.0.255` for /24.
  */
  hostmask =
    cidr:
    if isV4 cidr.address then
      ipv4.fromInt (hostmaskV4Int cidr.prefix)
    else
      ipv6.fromWords (builtins.genList (i: wordHostmaskIpv6 i cidr.prefix) 4);

  /*
    Count every address in a CIDR block.

    `cidr`: cidr value.

    Returns 2^(host bits); throws when that reaches 2^63 (IPv6 prefixes of
    65 or less), which a Nix int cannot hold.
  */
  size =
    cidr:
    let
      hostBits = (maxPrefix cidr.address) - cidr.prefix;
    in
    if hostBits > 62 then
      throw "libnet.cidr.size: block too large for Nix int (2^${builtins.toString hostBits}); IPv6 prefixes <= 65 exceed signed 63-bit range"
    else
      bits.pow2 hostBits;

  /*
    Count the usable host addresses of a CIDR block.

    `cidr`: cidr value.

    Returns `size` minus network and broadcast for IPv4 blocks wider than
    /31, `size` minus the Subnet-Router anycast address for IPv6 blocks
    wider than /127, otherwise `size`; throws where `size` throws.
  */
  numHosts =
    cidr:
    let
      addressCount = size cidr;
      prefixLength = cidr.prefix;
    in
    if isV4 cidr.address then
      (if prefixLength >= 31 then addressCount else addressCount - 2)
    else
      (if prefixLength >= 127 then addressCount else addressCount - 1);

  /*
    Find the first usable host address of a CIDR block.

    `cidr`: cidr value.

    Returns the network address for IPv4 /31-/32 and IPv6 /127-/128, where
    every address is usable (point-to-point links per RFC 3021 and
    RFC 6164), otherwise the network address plus one.
  */
  firstHost =
    cidr:
    let
      base = network cidr;
      prefixLength = cidr.prefix;
    in
    if isV4 cidr.address then
      (if prefixLength >= 31 then base else ipv4.add 1 base)
    else
      (if prefixLength >= 127 then base else ipv6.add 1 base);

  /*
    Find the last usable host address of a CIDR block.

    `cidr`: cidr value.

    Returns the address before broadcast for IPv4 blocks wider than /31,
    otherwise the block's top address.
  */
  lastHost =
    cidr:
    let
      top = topAddress cidr;
      prefixLength = cidr.prefix;
    in
    if isV4 cidr.address then (if prefixLength >= 31 then top else ipv4.sub 1 top) else top;

  # ===== Enumeration =====

  /*
    Index into a CIDR block's addresses.

    `n`: offset from the network address; negative values count back from
    the top address (-1 is the top).
    `cidr`: cidr value.

    Returns an address of the block's family; throws when `n` falls outside
    the block.
  */
  hostAt =
    n: cidr:
    let
      addressCount = size cidr;
      index = if n < 0 then addressCount + n else n;
    in
    if index < 0 || index >= addressCount then
      throw "libnet.cidr.hostAt: index out of range [0, ${builtins.toString addressCount})"
    else
      let
        base = network cidr;
      in
      if isV4 cidr.address then ipv4.add index base else ipv6.add index base;

  /*
    List every usable host address with no size guard; the caller accepts
    the memory cost.

    `cidr`: cidr value.

    Returns `numHosts` addresses starting at `firstHost`.
  */
  hostsUnbounded =
    cidr:
    let
      hostCount = numHosts cidr;
      first = firstHost cidr;
      offsetAddress = if isV4 cidr.address then ipv4.add else ipv6.add;
    in
    builtins.genList (i: offsetAddress i first) hostCount;

  /*
    List every usable host address, guarding against accidental huge lists.

    `cidr`: cidr value.

    Returns the same list as `hostsUnbounded`; throws when the block holds
    more than 2^16 addresses.
  */
  hosts =
    cidr:
    let
      addressCount = size cidr;
    in
    if addressCount > bits.pow2 16 then
      throw "libnet.cidr.hosts: block too large (${builtins.toString addressCount} addresses > 2^16); use hostAt or hostsUnbounded"
    else
      hostsUnbounded cidr;

  # ===== Containment =====

  /*
    Test whether an address falls within a CIDR block.

    `cidr`: cidr value.
    `ip`: ipv4 or ipv6 value.

    Returns a Boolean; false when the families differ.
  */
  containsAddress =
    cidr: ip:
    if cidr.address._type != ip._type then
      false
    else
      let
        base = network cidr;
        top = topAddress cidr;
      in
      if isV4 ip then
        ip.value >= base.value && ip.value <= top.value
      else
        (ipv6.ge ip base) && (ipv6.le ip top);

  /*
    Test whether one CIDR block lies entirely within another.

    `parent`: containing cidr value.
    `child`: contained cidr value.

    Returns a Boolean; true for equal blocks, false when the families
    differ.
  */
  containsCidr =
    parent: child:
    if parent.address._type != child.address._type then
      false
    else if child.prefix < parent.prefix then
      false
    else
      containsAddress parent (network child);

  /*
    Test containment of either an address or a CIDR block.

    `cidr`: containing cidr value.
    `value`: ipv4, ipv6, or cidr value.

    Returns a Boolean; false for mixed families or any other value.
  */
  contains =
    cidr: value:
    if types.isIp value then
      containsAddress cidr value
    else if types.isCidr value then
      containsCidr cidr value
    else
      false;

  /*
    Test whether `a` lies within `b` (subject first, container second).

    `a`, `b`: cidr values.

    Returns a Boolean; false when the families differ.
  */
  isSubnetOf = a: b: containsCidr b a;

  /*
    Test whether `a` contains `b`; the inverse of `isSubnetOf`.

    `a`, `b`: cidr values.

    Returns a Boolean; false when the families differ.
  */
  isSupernetOf = a: b: containsCidr a b;

  /*
    Test whether two CIDR blocks share any address.

    `a`, `b`: cidr values.

    Returns a Boolean; false when the families differ.
  */
  overlaps =
    a: b:
    if a.address._type != b.address._type then false else (containsCidr a b) || (containsCidr b a);

  # ===== Normalization & restructuring =====

  /*
    Zero the host bits of a CIDR block.

    `cidr`: cidr value.

    Returns a cidr value whose address is the network address.
  */
  canonical = cidr: mk (network cidr) cidr.prefix;

  /*
    Check whether a CIDR block's stored address has no host bits set.

    `cidr`: cidr value.

    Returns a Boolean.
  */
  isCanonical =
    cidr:
    let
      base = network cidr;
    in
    if isV4 cidr.address then cidr.address.value == base.value else cidr.address.words == base.words;

  /*
    Compute the IPv6 address `base + i * 2^shift` directly on 32-bit words.
    `subnet` uses it because 2^shift can exceed the 62-bit limit of
    `bits.pow2`. The caller guarantees 0 <= shift < 128 when i > 0 and
    that `bits.shl (shift mod 32) i` fits in a Nix int.
  */
  v6AddBlockOffset =
    shift: i: base:
    if i == 0 then
      base
    else
      let
        wordIndex = 3 - (shift / 32);
        shiftInWord = shift - 32 * (shift / 32);
        shifted = bits.shl shiftInWord i;
        lowPart = builtins.bitAnd shifted bits.mask32;
        highPart = if shiftInWord == 0 then 0 else bits.shr (32 - shiftInWord) i;
      in
      if wordIndex == 0 && highPart > 0 then
        throw "libnet.cidr.subnet: block offset overflow beyond 2^128"
      else
        let
          offsetWord =
            index:
            if index == wordIndex then
              lowPart
            else if index == wordIndex - 1 then
              highPart
            else
              0;
          inherit (base) words;
          result3 = carry.add32 (builtins.elemAt words 3) (offsetWord 3) 0;
          result2 = carry.add32 (builtins.elemAt words 2) (offsetWord 2) result3.carry;
          result1 = carry.add32 (builtins.elemAt words 1) (offsetWord 1) result2.carry;
          result0 = carry.add32 (builtins.elemAt words 0) (offsetWord 0) result1.carry;
        in
        if result0.carry == 1 then
          throw "libnet.cidr.subnet: block offset overflow beyond 2^128"
        else
          ipv6.fromWords [
            result0.sum
            result1.sum
            result2.sum
            result3.sum
          ];

  /*
    Split a CIDR block into equal-sized subnets.

    `n`: additional prefix bits, an integer in [0, 16].
    `cidr`: cidr value.

    Returns 2^n canonical cidr values in address order; throws when `n` is
    negative, exceeds 16, or pushes the prefix past the family maximum.
  */
  subnet =
    n: cidr:
    if !(builtins.isInt n) || n < 0 then
      throw "libnet.cidr.subnet: n must be non-negative int"
    else
      let
        newPrefix = cidr.prefix + n;
        maxPrefixLength = maxPrefix cidr.address;
      in
      if newPrefix > maxPrefixLength then
        throw "libnet.cidr.subnet: resulting prefix /${builtins.toString newPrefix} exceeds max /${builtins.toString maxPrefixLength}"
      else if n > 16 then
        throw "libnet.cidr.subnet: n too large (>16); would produce > 2^16 subnets"
      else
        let
          count = bits.pow2 n;
          base = network cidr;
          bitsToShift = maxPrefixLength - newPrefix;
          blockAt =
            if isV4 cidr.address then
              let
                blockSize = bits.pow2 bitsToShift;
              in
              i: mk (ipv4.add (i * blockSize) base) newPrefix
            else
              i: mk (v6AddBlockOffset bitsToShift i base) newPrefix;
        in
        builtins.genList blockAt count;

  /*
    Widen a CIDR block by shortening its prefix.

    `n`: number of prefix bits to remove, from 0 to the current prefix.
    `cidr`: cidr value.

    Returns the canonical enclosing cidr value; throws when `n` is negative
    or exceeds the current prefix.
  */
  supernet =
    n: cidr:
    if !(builtins.isInt n) || n < 0 then
      throw "libnet.cidr.supernet: n must be non-negative int"
    else if n > cidr.prefix then
      throw "libnet.cidr.supernet: n exceeds current prefix"
    else
      canonical (mk cidr.address (cidr.prefix - n));

  # ===== Comparison =====

  /*
    Test two CIDR blocks for equality after zeroing host bits, so
    `10.0.0.0/24` equals `10.0.0.5/24`.

    `a`, `b`: cidr values.

    Returns a Boolean; false when the families differ.
  */
  eq =
    a: b:
    types.hasSameTag a b
    && a.address._type == b.address._type
    && a.prefix == b.prefix
    && (
      let
        networkA = network a;
        networkB = network b;
      in
      if isV4 a.address then networkA.value == networkB.value else networkA.words == networkB.words
    );

  /*
    Order two CIDR blocks by family (IPv4 first), network address, then
    prefix length.

    `a`, `b`: cidr values.

    Returns -1, 0, or 1.
  */
  compare =
    a: b:
    if isV4 a.address && isV6 b.address then
      -1
    else if isV6 a.address && isV4 b.address then
      1
    else
      let
        networkA = network a;
        networkB = network b;
        addressOrder =
          if isV4 a.address then
            (
              if networkA.value < networkB.value then
                -1
              else if networkA.value > networkB.value then
                1
              else
                0
            )
          else
            ipv6.compare networkA networkB;
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
    Test whether `a` orders before `b` (see `compare`).

    `a`, `b`: cidr values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` orders before or equal to `b` (see `compare`).

    `a`, `b`: cidr values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` orders after `b` (see `compare`).

    `a`, `b`: cidr values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` orders after or equal to `b` (see `compare`).

    `a`, `b`: cidr values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lower of two CIDR blocks (see `compare`).

    `a`, `b`: cidr values.

    Returns `a` when the two compare equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the higher of two CIDR blocks (see `compare`).

    `a`, `b`: cidr values.

    Returns `a` when the two compare equal.
  */
  max = a: b: if ge a b then a else b;

  # ===== Set algebra =====

  # Whether a and b are distinct canonical halves of the same parent block.
  areSiblings =
    a: b:
    a.prefix == b.prefix
    && a.prefix > 0
    && a.address._type == b.address._type
    && isCanonical a
    && isCanonical b
    && !(eq a b)
    && containsCidr (canonical (mk a.address (a.prefix - 1))) a
    && containsCidr (canonical (mk a.address (a.prefix - 1))) b;

  mergeParent = cidr: canonical (mk cidr.address (cidr.prefix - 1));

  # Sorts by (family, network, prefix).
  sortCidrs = cidrs: builtins.sort (a: b: compare a b < 0) cidrs;

  # Coalesces same-family CIDRs into a minimal set: sort, then keep a stack
  # whose top absorbs duplicates and covered blocks and merges siblings.
  coalesceOne =
    cidrs:
    let
      sorted = sortCidrs (map canonical cidrs);
      step =
        acc: current:
        if acc == [ ] then
          [ current ]
        else
          let
            top = builtins.elemAt acc (builtins.length acc - 1);
            rest = builtins.genList (i: builtins.elemAt acc i) (builtins.length acc - 1);
          in
          if eq top current then
            acc
          else if containsCidr top current then
            acc
          else if areSiblings top current then
            step rest (mergeParent top)
          else
            acc ++ [ current ];
    in
    builtins.foldl' step [ ] sorted;

  /*
    Coalesce CIDR blocks into the minimal equivalent set, like Python's
    `ipaddress.collapse_addresses`.

    `cidrs`: list of cidr values of either family.

    Returns sorted canonical cidr values with duplicates and covered blocks
    dropped and sibling pairs merged; IPv4 blocks come first.
  */
  summarize =
    cidrs:
    let
      ipv4Cidrs = builtins.filter (cidr: isV4 cidr.address) cidrs;
      ipv6Cidrs = builtins.filter (cidr: isV6 cidr.address) cidrs;
    in
    (coalesceOne ipv4Cidrs) ++ (coalesceOne ipv6Cidrs);

  /*
    Remove one CIDR block from another.

    `parent`: cidr value to subtract from.
    `child`: cidr value contained in `parent`.

    Returns the minimal list of canonical cidr values covering
    `parent \ child`, or `[ ]` when they are equal; throws when the
    families differ or `child` is not contained in `parent`.
  */
  exclude =
    parent: child:
    if parent.address._type != child.address._type then
      throw "libnet.cidr.exclude: family mismatch"
    else if !(containsCidr parent child) then
      throw "libnet.cidr.exclude: child not contained in parent"
    else if eq parent child then
      [ ]
    else
      let
        # Halve repeatedly, keeping the half that does not contain child.
        split =
          current:
          if eq current child then
            [ ]
          else
            let
              halves = subnet 1 current;
              left = builtins.elemAt halves 0;
              right = builtins.elemAt halves 1;
            in
            if containsCidr left child then (split left) ++ [ right ] else [ left ] ++ (split right);
      in
      split (canonical parent);

  /*
    Find the largest CIDR block contained in both arguments.

    `a`, `b`: cidr values.

    Returns the canonical smaller block when one contains the other,
    otherwise null (including for different families).
  */
  intersect =
    a: b:
    if a.address._type != b.address._type then
      null
    else if containsCidr a b then
      canonical b
    else if containsCidr b a then
      canonical a
    else
      null;
in
{
  inherit
    address
    broadcast
    canonical
    compare
    contains
    containsAddress
    containsCidr
    eq
    exclude
    firstHost
    fromAddress
    ge
    gt
    hostAt
    hostmask
    hosts
    hostsUnbounded
    intersect
    is
    isCanonical
    isIpv4
    isIpv6
    isSubnetOf
    isSupernetOf
    isValid
    lastHost
    le
    lt
    make
    max
    min
    netmask
    network
    numHosts
    overlaps
    parse
    prefix
    size
    subnet
    summarize
    supernet
    topAddress
    toString
    tryParse
    version
    ;
}
