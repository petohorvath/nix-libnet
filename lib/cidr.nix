/*
  libnet.cidr

  Parse and operate on CIDR blocks (IPv4 and IPv6). A block always
  stores its network address: host bits are rejected, and
  `interfaceAddress` holds a host address with its prefix. Provides
  network address, broadcast, and host derivation, prefix arithmetic
  (subnets, supernet), and set operations (summarize, exclude, intersect).

  Example:
    libnet.cidr.parse "192.0.2.0/24"
    => { _type = "cidr"; networkAddress = <ipv4 192.0.2.0>; prefix = 24; }

    libnet.cidr.toString (libnet.cidr.parse "2001:DB8::/32")
    => "2001:db8::/32"
*/
let
  bits = import ./internal/bits.nix;
  carry = import ./internal/carry.nix;
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ip = import ./ip.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;

  # Callers guarantee `ip` has no host bits for `prefixLength`.
  mk =
    ip: prefixLength:
    types.mkStrict "cidr" {
      networkAddress = ip;
      prefix = prefixLength;
    };

  isV4 = ip: ip._type == "ipv4";
  isV6 = ip: ip._type == "ipv6";

  maxPrefix = ip: if isV4 ip then 32 else 128;

  # ===== Argument kinds =====

  /*
    Each returns its argument, throwing for the wrong kind on behalf of
    the public `function`. The unchecked helpers below, such as
    `topAddressOf` and `order`, take values the public function has
    already checked.
  */
  cidrArgument = function: errors.expectKind "cidr.${function}" "cidr";
  intArgument = function: errors.intArgument "cidr.${function}";
  addressArgument = function: errors.expect "cidr.${function}" "ipv4 or ipv6 value" types.isIp;

  # Check both block operands of a binary `function`, then apply
  # `relation` to them.
  binary =
    function: relation: a: b:
    relation (cidrArgument function a) (cidrArgument function b);

  # Check the non-negative bit count that `subnets` and `supernet` take.
  bitCountArgument =
    function: n:
    let
      count = intArgument function n;
    in
    if count < 0 then
      errors.fail "cidr.${function}" "n must not be negative: ${builtins.toString count}"
    else
      count;

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

  # The network address of the block that `ip` falls in at `prefixLength`.
  zeroHostBits =
    ip: prefixLength:
    if isV4 ip then
      ipv4.fromInt (builtins.bitAnd ip.value (netmaskV4Int prefixLength))
    else
      ipv6.fromWords (
        builtins.genList (i: builtins.bitAnd (builtins.elemAt ip.words i) (wordMaskIpv6 i prefixLength)) 4
      );

  sameAddress = a: b: if isV4 a then a.value == b.value else a.words == b.words;

  hasHostBits = ip: prefixLength: !(sameAddress ip (zeroHostBits ip prefixLength));

  formatAddress = ip: if isV4 ip then ipv4.toString ip else ipv6.toString ip;

  # The detail `parse` and `make` report for an address with host bits set.
  hostBitsError =
    ip: prefixLength:
    let
      prefixText = builtins.toString prefixLength;
    in
    "host bits set in \"${formatAddress ip}/${prefixText}\"; the CIDR is ${formatAddress (zeroHostBits ip prefixLength)}/${prefixText}, and interfaceAddress keeps a host address with its prefix";

  # ===== Parsing =====

  /*
    Parse a CIDR block without throwing, for callers that validate
    untrusted text.

    `input`: `address/prefix` string such as `10.0.0.0/24` or
    `2001:db8::/32`; host bits must be zero.

    Returns a tryParse result whose `value` is a cidr value.
  */
  tryParse =
    input:
    let
      parseError = detail: types.tryErr (errors.message "cidr.parse" detail);
    in
    if !(builtins.isString input) then
      parseError (errors.notString input)
    else
      let
        parts = parsing.splitOn "/" input;
      in
      if builtins.length parts != 2 then
        parseError "missing '/': \"${input}\""
      else
        let
          addressText = builtins.elemAt parts 0;
          prefixText = builtins.elemAt parts 1;
          isIpv6Text = parsing.countOccurrences ":" addressText > 0;
          addressResult = if isIpv6Text then ipv6.tryParse addressText else ipv4.tryParse addressText;
          prefixLength = parsing.decimal (maxPrefix addressResult.value) prefixText;
        in
        if !addressResult.success then
          parseError (errors.detail (if isIpv6Text then "ipv6.parse" else "ipv4.parse") addressResult.error)
        else if !(parsing.isDecimal prefixText) then
          parseError "invalid prefix \"${prefixText}\""
        else if prefixLength == null then
          parseError "prefix /${prefixText} out of range"
        else if hasHostBits addressResult.value prefixLength then
          parseError (hostBitsError addressResult.value prefixLength)
        else
          types.tryOk (mk addressResult.value prefixLength);

  /*
    Parse a CIDR block from its text form.

    `input`: `address/prefix` string such as `10.0.0.0/24` or
    `2001:db8::/32`; host bits must be zero.

    Returns a cidr value; throws on invalid input or set host bits.
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

    Returns a string.
  */
  toString =
    cidr:
    let
      block = cidrArgument "toString" cidr;
    in
    "${formatAddress block.networkAddress}/${builtins.toString block.prefix}";

  /*
    Build a CIDR block from an address and a prefix length.

    `ip`: ipv4 or ipv6 network address; host bits must be zero.
    `prefixLength`: integer in [0, 32] for IPv4 or [0, 128] for IPv6.

    Returns a cidr value; throws on a non-address, a non-integer or
    out-of-range prefix, or set host bits.
  */
  make =
    ip: prefixLength:
    let
      address = addressArgument "make" ip;
      checkedPrefix = intArgument "make" prefixLength;
      prefixMax = maxPrefix address;
    in
    if checkedPrefix < 0 || checkedPrefix > prefixMax then
      errors.fail "cidr.make" "prefix out of range [0, ${builtins.toString prefixMax}]: ${builtins.toString checkedPrefix}"
    else if hasHostBits address checkedPrefix then
      errors.fail "cidr.make" (hostBitsError address checkedPrefix)
    else
      mk address checkedPrefix;

  /*
    Wrap a single address as a host-sized block.

    `ip`: ipv4 or ipv6 value.

    Returns a /32 or /128 cidr value; throws for any other value.
  */
  fromAddress =
    ip:
    let
      address = addressArgument "fromAddress" ip;
    in
    mk address (maxPrefix address);

  # ===== Accessors / predicates =====

  /*
    Read the network address of a CIDR block.

    `cidr`: cidr value.

    Returns the ipv4 or ipv6 value with the host bits zero.
  */
  networkAddress = cidr: (cidrArgument "networkAddress" cidr).networkAddress;

  /*
    Read the prefix length of a CIDR block.

    `cidr`: cidr value.

    Returns an integer.
  */
  prefix = cidr: (cidrArgument "prefix" cidr).prefix;

  /*
    Report the address family of a CIDR block.

    `cidr`: cidr value.

    Returns 4 or 6.
  */
  version = cidr: if isV4 (cidrArgument "version" cidr).networkAddress then 4 else 6;

  /*
    Check whether a CIDR block is IPv4.

    `cidr`: cidr value.

    Returns a Boolean.
  */
  isIpv4 = cidr: isV4 (cidrArgument "isIpv4" cidr).networkAddress;

  /*
    Check whether a CIDR block is IPv6.

    `cidr`: cidr value.

    Returns a Boolean.
  */
  isIpv6 = cidr: isV6 (cidrArgument "isIpv6" cidr).networkAddress;

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

  # ===== Derived values =====

  # The network address with all host bits set.
  topAddressOf =
    block:
    let
      base = block.networkAddress;
      prefixLength = block.prefix;
    in
    if isV4 base then
      ipv4.fromInt (builtins.bitOr base.value (hostmaskV4Int prefixLength))
    else
      ipv6.fromWords (
        builtins.genList (
          i: builtins.bitOr (builtins.elemAt base.words i) (wordHostmaskIpv6 i prefixLength)
        ) 4
      );

  /*
    Compute the IPv4 broadcast address of a CIDR block.

    `cidr`: IPv4 cidr value of prefix /30 or shorter.

    Returns the ipv4 value with all host bits set; throws for IPv6, which
    has no broadcast, and for /31 and /32, whose addresses are all hosts
    (RFC 3021).
  */
  broadcast =
    cidr:
    let
      block = cidrArgument "broadcast" cidr;
    in
    if isV6 block.networkAddress then
      errors.fail "cidr.broadcast" "IPv6 has no broadcast"
    else if block.prefix == 31 then
      errors.fail "cidr.broadcast" "/31 has no broadcast (RFC 3021)"
    else if block.prefix == 32 then
      errors.fail "cidr.broadcast" "/32 has no broadcast"
    else
      topAddressOf block;

  /*
    Compute the highest address of a CIDR block in either family.

    `cidr`: cidr value.

    Returns the network address with all host bits set.
  */
  topAddress = cidr: topAddressOf (cidrArgument "topAddress" cidr);

  /*
    Express the prefix length as an address-form netmask.

    `cidr`: cidr value.

    Returns an address of the block's family, e.g. `255.255.255.0` for /24.
  */
  netmask =
    cidr:
    let
      block = cidrArgument "netmask" cidr;
    in
    if isV4 block.networkAddress then
      ipv4.fromInt (netmaskV4Int block.prefix)
    else
      ipv6.fromWords (builtins.genList (i: wordMaskIpv6 i block.prefix) 4);

  /*
    Express the host part as an address-form mask, the inverse of
    `netmask`.

    `cidr`: cidr value.

    Returns an address of the block's family, e.g. `0.0.0.255` for /24.
  */
  hostmask =
    cidr:
    let
      block = cidrArgument "hostmask" cidr;
    in
    if isV4 block.networkAddress then
      ipv4.fromInt (hostmaskV4Int block.prefix)
    else
      ipv6.fromWords (builtins.genList (i: wordHostmaskIpv6 i block.prefix) 4);

  # The address count of `block`, throwing on behalf of `function` when
  # it reaches 2^63, which a Nix int cannot hold.
  sizeFor =
    function: block:
    let
      hostBits = (maxPrefix block.networkAddress) - block.prefix;
    in
    if hostBits > 62 then
      errors.fail "cidr.${function}" "block too large for a Nix integer (2^${builtins.toString hostBits} addresses)"
    else
      bits.pow2 hostBits;

  /*
    Count every address in a CIDR block.

    `cidr`: cidr value.

    Returns 2^(host bits); throws when that reaches 2^63 (IPv6 prefixes of
    65 or less), which a Nix int cannot hold.
  */
  size = cidr: sizeFor "size" (cidrArgument "size" cidr);

  # The usable host count of `block`; see `hostCount`.
  hostCountFor =
    function: block:
    let
      addressCount = sizeFor function block;
      prefixLength = block.prefix;
    in
    if isV4 block.networkAddress then
      (if prefixLength >= 31 then addressCount else addressCount - 2)
    else
      (if prefixLength >= 127 then addressCount else addressCount - 1);

  /*
    Count the usable host addresses of a CIDR block.

    `cidr`: cidr value.

    Returns `size` minus the network and broadcast addresses for IPv4
    blocks wider than /31, `size` minus the Subnet-Router anycast address
    for IPv6 blocks wider than /127, otherwise `size`; throws where
    `size` throws.
  */
  hostCount = cidr: hostCountFor "hostCount" (cidrArgument "hostCount" cidr);

  firstHostOf =
    block:
    let
      base = block.networkAddress;
      prefixLength = block.prefix;
    in
    if isV4 base then
      (if prefixLength >= 31 then base else ipv4.add 1 base)
    else
      (if prefixLength >= 127 then base else ipv6.add 1 base);

  /*
    Find the first usable host address of a CIDR block.

    `cidr`: cidr value.

    Returns the network address for IPv4 /31-/32 and IPv6 /127-/128, where
    every address is usable (point-to-point links per RFC 3021 and
    RFC 6164), otherwise the network address plus one.
  */
  firstHost = cidr: firstHostOf (cidrArgument "firstHost" cidr);

  /*
    Find the last usable host address of a CIDR block.

    `cidr`: cidr value.

    Returns the address before broadcast for IPv4 blocks wider than /31,
    otherwise the block's top address.
  */
  lastHost =
    cidr:
    let
      block = cidrArgument "lastHost" cidr;
      top = topAddressOf block;
    in
    if isV4 block.networkAddress && block.prefix < 31 then ipv4.sub 1 top else top;

  # ===== Enumeration =====

  /*
    Index into a CIDR block's addresses.

    `n`: offset from the network address; negative values count back from
    the top address (-1 is the top).
    `cidr`: cidr value.

    Returns an address of the block's family; throws when `n` is not an
    integer or falls outside the block. A block of 2^63 addresses or more
    holds every integer `n`.
  */
  addressAt =
    n: cidr:
    let
      offset = intArgument "addressAt" n;
      block = cidrArgument "addressAt" cidr;
      hostBits = maxPrefix block.networkAddress - block.prefix;
      # Read only for blocks below 2^63 addresses, which a Nix int holds.
      addressCount = bits.pow2 hostBits;
      offsetAddress = if isV4 block.networkAddress then ipv4.add else ipv6.add;
    in
    if hostBits <= 62 && (offset >= addressCount || offset < 0 - addressCount) then
      errors.fail "cidr.addressAt" "index out of range [0, ${builtins.toString addressCount}): ${builtins.toString offset}"
    else if offset < 0 then
      # Counting back from the top address avoids the size, and
      # `offset + 1` cannot overflow, even for -2^63.
      offsetAddress (offset + 1) (topAddressOf block)
    else
      offsetAddress offset block.networkAddress;

  # The usable hosts of `block`, counted on behalf of `function`.
  listHosts =
    function: block:
    let
      first = firstHostOf block;
      offsetAddress = if isV4 block.networkAddress then ipv4.add else ipv6.add;
    in
    builtins.genList (i: offsetAddress i first) (hostCountFor function block);

  /*
    List every usable host address with no size guard; the caller accepts
    the memory cost.

    `cidr`: cidr value.

    Returns `hostCount` addresses starting at `firstHost`; throws where
    `size` throws.
  */
  hostsUnbounded = cidr: listHosts "hostsUnbounded" (cidrArgument "hostsUnbounded" cidr);

  /*
    List every usable host address, guarding against accidental huge lists.

    `cidr`: cidr value.

    Returns the same list as `hostsUnbounded`; throws when the block holds
    more than 2^16 addresses.
  */
  hosts =
    cidr:
    let
      block = cidrArgument "hosts" cidr;
      hostBits = maxPrefix block.networkAddress - block.prefix;
      # `hostsUnbounded` throws where a Nix int cannot hold the size.
      fitsInt = hostBits <= 62;
      addressCount =
        if fitsInt then builtins.toString (bits.pow2 hostBits) else "2^${builtins.toString hostBits}";
    in
    if hostBits > 16 then
      errors.fail "cidr.hosts" "block too large (${addressCount} addresses > 2^16); use addressAt${
        if fitsInt then " or hostsUnbounded" else ""
      }"
    else
      listHosts "hosts" block;

  # ===== Containment =====

  # Whether same-family address `ip` lies within `block`.
  holds =
    block: ip:
    let
      base = block.networkAddress;
      top = topAddressOf block;
    in
    if isV4 ip then
      ip.value >= base.value && ip.value <= top.value
    else
      (ipv6.ge ip base) && (ipv6.le ip top);

  /*
    Test whether an address falls within a CIDR block. Test a block with
    `isSupernetOf`.

    `cidr`: cidr value.
    `ip`: ipv4 or ipv6 value.

    Returns true when `ip` lies within the block; false for an address of
    the other family. Throws for any other value, including a cidr.
  */
  contains =
    cidr: ip:
    let
      block = cidrArgument "contains" cidr;
      address =
        if types.isCidr ip then
          errors.fail "cidr.contains" "expected ipv4 or ipv6 value, got cidr value; test a block with isSupernetOf"
        else
          addressArgument "contains" ip;
    in
    block.networkAddress._type == address._type && holds block address;

  # Whether block `a` contains block `b`, false across families.
  supernetOf =
    a: b:
    a.networkAddress._type == b.networkAddress._type
    && b.prefix >= a.prefix
    && holds a b.networkAddress;

  /*
    Test whether `a` lies within `b` (subject first, container second).

    `a`, `b`: cidr values.

    Returns a Boolean; true for equal blocks, false when the families
    differ.
  */
  isSubnetOf = binary "isSubnetOf" (a: b: supernetOf b a);

  /*
    Test whether `a` contains `b`; the converse of `isSubnetOf`.

    `a`, `b`: cidr values.

    Returns a Boolean; true for equal blocks, false when the families
    differ.
  */
  isSupernetOf = binary "isSupernetOf" supernetOf;

  /*
    Test whether two CIDR blocks share any address.

    `a`, `b`: cidr values.

    Returns a Boolean; false when the families differ.
  */
  overlaps = binary "overlaps" (a: b: supernetOf a b || supernetOf b a);

  # ===== Restructuring =====

  /*
    Compute the IPv6 address `base + i * 2^shift` directly on 32-bit words.
    `subnets` uses it because 2^shift can exceed the 62-bit limit of
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
        errors.fail "cidr.subnets" "block offset overflow beyond 2^128"
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
          errors.fail "cidr.subnets" "block offset overflow beyond 2^128"
        else
          ipv6.fromWords [
            result0.sum
            result1.sum
            result2.sum
            result3.sum
          ];

  # Split `block` into 2^n blocks; `n` fits the family and is at most 16.
  split =
    n: block:
    let
      newPrefix = block.prefix + n;
      base = block.networkAddress;
      bitsToShift = maxPrefix base - newPrefix;
      blockAt =
        if isV4 base then
          let
            blockSize = bits.pow2 bitsToShift;
          in
          i: mk (ipv4.add (i * blockSize) base) newPrefix
        else
          i: mk (v6AddBlockOffset bitsToShift i base) newPrefix;
    in
    builtins.genList blockAt (bits.pow2 n);

  /*
    Split a CIDR block into equal-sized subnets.

    `n`: additional prefix bits, an integer in [0, 16].
    `cidr`: cidr value.

    Returns 2^n cidr values in address order; throws when `n` is not an
    integer, is negative, exceeds 16, or pushes the prefix past the family
    maximum.
  */
  subnets =
    n: cidr:
    let
      count = bitCountArgument "subnets" n;
      block = cidrArgument "subnets" cidr;
      newPrefix = block.prefix + count;
      maxPrefixLength = maxPrefix block.networkAddress;
    in
    if newPrefix > maxPrefixLength then
      errors.fail "cidr.subnets" "resulting prefix /${builtins.toString newPrefix} exceeds max /${builtins.toString maxPrefixLength}"
    else if count > 16 then
      errors.fail "cidr.subnets" "n too large (>16); would produce > 2^16 subnets"
    else
      split count block;

  # The block `n` bits shorter that contains `block`; `n` is at most its
  # prefix.
  widen = n: block: mk (zeroHostBits block.networkAddress (block.prefix - n)) (block.prefix - n);

  /*
    Widen a CIDR block by shortening its prefix.

    `n`: number of prefix bits to remove, from 0 to the current prefix.
    `cidr`: cidr value.

    Returns the enclosing cidr value; throws when `n` is not an integer,
    is negative, or exceeds the current prefix.
  */
  supernet =
    n: cidr:
    let
      count = bitCountArgument "supernet" n;
      block = cidrArgument "supernet" cidr;
    in
    if count > block.prefix then
      errors.fail "cidr.supernet" "n exceeds current prefix /${builtins.toString block.prefix}: ${builtins.toString count}"
    else
      widen count block;

  # ===== Comparison =====

  /*
    Test two CIDR blocks for equality.

    `a`, `b`: cidr values.

    Returns a Boolean; false when the families differ.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.cidr a b
    && a.networkAddress._type == b.networkAddress._type
    && a.prefix == b.prefix
    && sameAddress a.networkAddress b.networkAddress;

  # Order checked blocks by family, network address, then prefix.
  order =
    a: b:
    comparison.lexicographic [
      (ip.compare a.networkAddress b.networkAddress)
      (comparison.order a.prefix b.prefix)
    ];

  ordering = comparison.suite (function: binary function order);

  # ===== Set algebra =====

  mergeParent = widen 1;

  # Whether a and b are distinct halves of the same parent block.
  areSiblings =
    a: b:
    a.prefix == b.prefix
    && a.prefix > 0
    && a.networkAddress._type == b.networkAddress._type
    && !(eq a b)
    && supernetOf (mergeParent a) b;

  # Sorts by (family, network address, prefix).
  sortCidrs = cidrs: builtins.sort (a: b: order a b < 0) cidrs;

  # Coalesces same-family CIDRs into a minimal set: sort, then keep a stack
  # whose top absorbs duplicates and covered blocks and merges siblings.
  coalesceOne =
    cidrs:
    let
      sorted = sortCidrs cidrs;
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
          else if supernetOf top current then
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

    Returns sorted cidr values with duplicates and covered blocks
    dropped and sibling pairs merged; IPv4 blocks come first. Throws for
    a non-list or an element that is not a cidr value.
  */
  summarize =
    cidrs:
    let
      blocks = map (cidrArgument "summarize") (errors.expectType "cidr.summarize" "list" cidrs);
      ipv4Cidrs = builtins.filter (block: isV4 block.networkAddress) blocks;
      ipv6Cidrs = builtins.filter (block: isV6 block.networkAddress) blocks;
    in
    (coalesceOne ipv4Cidrs) ++ (coalesceOne ipv6Cidrs);

  /*
    Remove one CIDR block from another. The removed block comes first,
    so `concatMap (exclude reserved) pools` works.

    `child`: cidr value to remove, contained in `parent`.
    `parent`: cidr value to subtract from.

    Returns the minimal list of cidr values covering
    `parent \ child`, or `[ ]` when they are equal; throws when the
    families differ or `child` is not contained in `parent`.
  */
  exclude = binary "exclude" (
    child: parent:
    if parent.networkAddress._type != child.networkAddress._type then
      errors.fail "cidr.exclude" "family mismatch"
    else if !(supernetOf parent child) then
      errors.fail "cidr.exclude" "child not contained in parent"
    else
      let
        # Halve repeatedly, keeping the half that does not contain child.
        remove =
          current:
          if eq current child then
            [ ]
          else
            let
              halves = split 1 current;
              left = builtins.elemAt halves 0;
              right = builtins.elemAt halves 1;
            in
            if supernetOf left child then (remove left) ++ [ right ] else [ left ] ++ (remove right);
      in
      remove parent
  );

  /*
    Find the largest CIDR block contained in both arguments.

    `a`, `b`: cidr values.

    Returns the smaller block when one contains the other,
    otherwise null (including for different families).
  */
  intersect = binary "intersect" (
    a: b:
    if supernetOf a b then
      b
    else if supernetOf b a then
      a
    else
      null
  );
in
{
  inherit
    addressAt
    broadcast
    contains
    eq
    exclude
    firstHost
    fromAddress
    hostCount
    hostmask
    hosts
    hostsUnbounded
    intersect
    is
    isIpv4
    isIpv6
    isSubnetOf
    isSupernetOf
    isValid
    lastHost
    make
    netmask
    networkAddress
    overlaps
    parse
    prefix
    size
    subnets
    summarize
    supernet
    topAddress
    toString
    tryParse
    version
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
