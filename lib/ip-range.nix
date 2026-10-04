/*
  libnet.ipRange

  An inclusive range of IP addresses stored as from / to endpoints.
  Supports containment, overlap, adjacency, enumeration, and
  conversion to and from a minimal CIDR set.

  Example:
    libnet.ipRange.parse "192.0.2.0-192.0.2.255"
    => { _type = "ipRange"; from = <ipv4>; to = <ipv4>; }

    map libnet.cidr.toString
      (libnet.ipRange.toCidrs (libnet.ipRange.parse "10.0.0.0-10.0.0.3"))
    => [ "10.0.0.0/30" ]
*/
let
  bits = import ./internal/bits.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  cidr = import ./cidr.nix;

  mk = first: last: {
    _type = "ipRange";
    from = first;
    to = last;
  };

  isV4 = address: address._type == "ipv4";
  isV6 = address: address._type == "ipv6";

  # Family-specific dispatchers
  addFor = address: if isV4 address then ipv4.add else ipv6.add;
  compareFor = address: if isV4 address then ipv4.compare else ipv6.compare;
  leFor =
    address: a: b:
    (compareFor address) a b <= 0;

  # Same-family address equality on the raw representation.
  sameAddress =
    left: right: if isV4 left then left.value == right.value else left.words == right.words;

  # ===== Parsing =====

  /*
    Parse an address range without throwing, so callers can handle
    invalid input themselves.

    `input`: "<from>-<to>" with two same-family addresses, such as
    "1.2.3.4-1.2.3.10" or "2001:db8::1-2001:db8::ff".

    Returns a tryResult: `{ success = true; value = <ipRange>; }` or
    `{ success = false; error = <message>; }`. Fails on malformed
    addresses, mixed families, or from > to.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.ipRange.parse: input must be a string"
    else
      let
        parts = parsing.splitOn "-" input;
        partCount = builtins.length parts;
      in
      if partCount != 2 then
        types.tryErr "libnet.ipRange.parse: missing '-' or too many: \"${input}\""
      else
        let
          fromInput = builtins.elemAt parts 0;
          toInput = builtins.elemAt parts 1;
          isV6Input = text: parsing.countOccurrences ":" text > 0;
          fromResult = if isV6Input fromInput then ipv6.tryParse fromInput else ipv4.tryParse fromInput;
          toResult = if isV6Input toInput then ipv6.tryParse toInput else ipv4.tryParse toInput;
        in
        if !fromResult.success then
          types.tryErr "libnet.ipRange.parse: invalid 'from': ${fromResult.error}"
        else if !toResult.success then
          types.tryErr "libnet.ipRange.parse: invalid 'to': ${toResult.error}"
        else if fromResult.value._type != toResult.value._type then
          types.tryErr "libnet.ipRange.parse: mixed families in \"${input}\""
        else if !(leFor fromResult.value fromResult.value toResult.value) then
          types.tryErr "libnet.ipRange.parse: 'from' > 'to' in \"${input}\""
        else
          types.tryOk (mk fromResult.value toResult.value);

  /*
    Parse an address range from text, such as a firewall iprange rule
    or DHCP pool.

    `input`: "<from>-<to>" with two same-family addresses, such as
    "1.2.3.4-1.2.3.10" or "2001:db8::1-2001:db8::ff".

    Returns an ipRange value; throws on malformed addresses, mixed
    families, or from > to.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Format a range in canonical hyphen form.

    `range`: ipRange value.

    Returns "<from>-<to>" using each family's canonical address text.
  */
  toString =
    range:
    let
      formatAddress = if isV4 range.from then ipv4.toString else ipv6.toString;
    in
    "${formatAddress range.from}-${formatAddress range.to}";

  /*
    Build a range from two address values.

    `first`: lowest address (ipv4 or ipv6 value).
    `last`: highest address, same family as `first`.

    Returns an ipRange value; throws on non-address inputs, mixed
    families, or first > last.
  */
  make =
    first: last:
    if !(types.isIp first) then
      throw "libnet.ipRange.make: 'from' must be ipv4 or ipv6"
    else if !(types.isIp last) then
      throw "libnet.ipRange.make: 'to' must be ipv4 or ipv6"
    else if first._type != last._type then
      throw "libnet.ipRange.make: mixed families"
    else if !(leFor first first last) then
      throw "libnet.ipRange.make: 'from' > 'to'"
    else
      mk first last;

  /*
    Build a range holding exactly one address, parallel to
    `cidr.fromAddress` and `portRange.fromPort`.

    `address`: ipv4 or ipv6 value.

    Returns a single-address ipRange; throws when given a non-address.
  */
  fromAddress =
    address:
    if !(types.isIp address) then
      throw "libnet.ipRange.fromAddress: expected ipv4 or ipv6 value"
    else
      mk address address;

  # ===== Predicates =====

  /*
    Check whether a string parses as an address range.

    `input`: candidate string.

    Returns true when `tryParse input` succeeds.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is an ipRange value.

    `value`: any value.

    Returns true when `value` is tagged `_type = "ipRange"`.
  */
  is = value: types.isIpRange value;

  /*
    Check whether a range holds IPv4 addresses.

    `range`: ipRange value.

    Returns true for an IPv4 range.
  */
  isIpv4 = range: isV4 range.from;

  /*
    Check whether a range holds IPv6 addresses.

    `range`: ipRange value.

    Returns true for an IPv6 range.
  */
  isIpv6 = range: isV6 range.from;

  /*
    Check whether a range holds a single address.

    `range`: ipRange value.

    Returns true when from equals to.
  */
  isSingleton =
    range:
    if isV4 range.from then range.from.value == range.to.value else range.from.words == range.to.words;

  # ===== Accessors =====

  /*
    Get the lowest address of a range.

    `range`: ipRange value.

    Returns the `from` address value.
  */
  from = range: range.from;

  /*
    Get the highest address of a range.

    `range`: ipRange value.

    Returns the `to` address value.
  */
  to = range: range.to;

  /*
    Get the IP version of a range.

    `range`: ipRange value.

    Returns 4 or 6.
  */
  version = range: if isV4 range.from then 4 else 6;

  /*
    Count the addresses in a range.

    `range`: ipRange value.

    Returns `to - from + 1` as an integer; throws for IPv6 ranges wider
    than about 2^63 addresses.
  */
  size =
    range:
    if isV4 range.from then
      range.to.value - range.from.value + 1
    else
      ipv6.diff range.from range.to + 1;

  # ===== Containment & relationships =====

  /*
    Check whether an address lies inside a range.

    `range`: ipRange value.
    `address`: value to test.

    Returns true when `address` is a same-family address within
    [from, to]; false for other values or families.
  */
  contains =
    range: address:
    if !(types.isIp address) then
      false
    else if range.from._type != address._type then
      false
    else
      let
        lessOrEqual = leFor range.from;
      in
      (lessOrEqual range.from address) && (lessOrEqual address range.to);

  /*
    Check whether two ranges share at least one address. Symmetric.

    `a`, `b`: ipRange values.

    Returns true when the ranges intersect; false across families.
  */
  overlaps =
    a: b:
    if a.from._type != b.from._type then
      false
    else
      let
        lessOrEqual = leFor a.from;
      in
      (lessOrEqual a.from b.to) && (lessOrEqual b.from a.to);

  /*
    Check whether one range lies within another.

    `a`: candidate inner range.
    `b`: candidate outer range.

    Returns true when `a` is a subset of `b` (including equal ranges);
    false across families.
  */
  isSubrangeOf =
    a: b:
    if a.from._type != b.from._type then
      false
    else
      let
        lessOrEqual = leFor a.from;
      in
      (lessOrEqual b.from a.from) && (lessOrEqual a.to b.to);

  /*
    Check whether one range encloses another; inverse of `isSubrangeOf`.

    `a`: candidate outer range.
    `b`: candidate inner range.

    Returns true when `b` is a subset of `a` (including equal ranges).
  */
  isSuperrangeOf = a: b: isSubrangeOf b a;

  /*
    Check whether two ranges touch with no gap and no overlap. A range
    ending at the family's top address has no upward neighbour.

    `a`, `b`: ipRange values.

    Returns true when one range ends immediately before the other
    starts; false across families.
  */
  isAdjacent =
    a: b:
    if a.from._type != b.from._type then
      false
    else
      let
        # Incrementing the top address throws; tryEval turns that into
        # "no neighbour".
        aAfterEnd = builtins.tryEval ((addFor a.from) 1 a.to);
        bAfterEnd = builtins.tryEval ((addFor b.from) 1 b.to);
      in
      (aAfterEnd.success && sameAddress aAfterEnd.value b.from)
      || (bAfterEnd.success && sameAddress bAfterEnd.value a.from);

  /*
    Combine two ranges into one when they overlap or touch.

    `a`, `b`: ipRange values.

    Returns the spanning ipRange, or null when a gap separates them or
    the families differ.
  */
  merge =
    a: b:
    if a.from._type != b.from._type then
      null
    else if overlaps a b || isAdjacent a b then
      let
        lessOrEqual = leFor a.from;
        greaterOrEqual = x: y: lessOrEqual y x;
        mergedFrom = if lessOrEqual a.from b.from then a.from else b.from;
        mergedTo = if greaterOrEqual a.to b.to then a.to else b.to;
      in
      mk mergedFrom mergedTo
    else
      null;

  # ===== Enumeration =====

  /*
    List every address in a range with no size guard; the caller bounds
    the cost.

    `range`: ipRange value.

    Returns the addresses from `from` to `to` in ascending order.
  */
  addressesUnbounded =
    range:
    let
      rangeSize = size range;
      offsetAddress = addFor range.from;
    in
    builtins.genList (i: offsetAddress i range.from) rangeSize;

  /*
    List every address in a range, guarding against accidentally huge
    lists.

    `range`: ipRange value.

    Returns the addresses from `from` to `to` in ascending order; throws
    when the range holds more than 2^16 addresses (use
    `addressesUnbounded`).
  */
  addresses =
    range:
    let
      rangeSize = size range;
    in
    if rangeSize > bits.pow2 16 then
      throw "libnet.ipRange.addresses: range too large (${builtins.toString rangeSize} > 2^16); use addressesUnbounded"
    else
      addressesUnbounded range;

  /*
    Index into a range, parallel to `cidr.hostAt` and
    `ipBindpoint.endpointAt`. Like `cidr.hostAt` it relies on `size`, so
    it throws for IPv6 ranges wider than about 2^63 addresses.

    `n`: 0-based offset from `from`; negative values count from the end.
    `range`: ipRange value.

    Returns the selected address; throws when `n` falls outside the
    range.
  */
  addressAt =
    n: range:
    let
      rangeSize = size range;
      index = if n < 0 then rangeSize + n else n;
    in
    if index < 0 || index >= rangeSize then
      throw "libnet.ipRange.addressAt: index out of range [0, ${builtins.toString rangeSize})"
    else
      (addFor range.from) index range.from;

  # ===== CIDR interop =====

  /*
    Convert a CIDR block into the range it covers.

    `cidrValue`: cidr value.

    Returns the range from the network address to the block's top
    address (broadcast for IPv4); throws when given a non-cidr.
  */
  fromCidr =
    cidrValue:
    if !(types.isCidr cidrValue) then
      throw "libnet.ipRange.fromCidr: expected a cidr value"
    else
      mk (cidr.network cidrValue) (cidr.topAddress cidrValue);

  /*
    Cover a range exactly with the fewest CIDR blocks, for tools that
    accept only prefixes.

    `range`: ipRange value.

    Returns a list of cidr values in ascending address order.
  */
  toCidrs =
    range:
    let
      maxPrefix = if isV4 range.from then 32 else 128;
      nextAddress = (addFor range.from) 1;
      isTopAddress =
        address:
        if isV4 address then
          address.value == bits.mask32
        else
          address.words == [
            bits.mask32
            bits.mask32
            bits.mask32
            bits.mask32
          ];
      lessOrEqual = leFor range.from;

      # Smallest prefix whose block starting at `start` is aligned and
      # ends at or before `end`.
      findPrefix =
        start: end:
        let
          tryPrefix =
            prefix:
            if prefix > maxPrefix then
              maxPrefix
            else
              let
                block = cidr.make start prefix;
                network = cidr.network block;
                topAddress = cidr.topAddress block;
              in
              if (sameAddress network start) && (lessOrEqual topAddress end) then
                prefix
              else
                tryPrefix (prefix + 1);
        in
        tryPrefix 0;

      collectBlocks =
        blocks: current:
        if !(lessOrEqual current range.to) then
          blocks
        else
          let
            prefix = findPrefix current range.to;
            block = cidr.make current prefix;
            topOfBlock = cidr.topAddress block;
            nextBlocks = blocks ++ [ block ];
          in
          if isTopAddress topOfBlock then nextBlocks else collectBlocks nextBlocks (nextAddress topOfBlock);
    in
    collectBlocks [ ] range.from;

  # ===== Comparison =====

  compareAddresses = a: b: if isV4 a then ipv4.compare a b else ipv6.compare a b;

  /*
    Order two ranges lexicographically on (family, from, to); IPv4
    ranges sort before IPv6 ranges.

    `a`, `b`: ipRange values.

    Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`.
  */
  compare =
    a: b:
    if isV4 a.from && isV6 b.from then
      -1
    else if isV6 a.from && isV4 b.from then
      1
    else
      let
        fromOrder = compareAddresses a.from b.from;
      in
      if fromOrder != 0 then fromOrder else compareAddresses a.to b.to;

  /*
    Test two address ranges for equality.

    `a`, `b`: ipRange values.

    Returns true when both have the same type tag, family, `from`, and
    `to`.
  */
  eq =
    a: b:
    types.hasSameTag a b
    && a.from._type == b.from._type
    && (
      if isV4 a.from then
        ipv4.eq a.from b.from && ipv4.eq a.to b.to
      else
        ipv6.eq a.from b.from && ipv6.eq a.to b.to
    );

  /*
    Test whether one range sorts before another.

    `a`, `b`: ipRange values.

    Returns true when `compare a b == -1`.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether one range sorts before or equal to another.

    `a`, `b`: ipRange values.

    Returns true when `compare a b <= 0`.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether one range sorts after another.

    `a`, `b`: ipRange values.

    Returns true when `compare a b == 1`.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether one range sorts after or equal to another.

    `a`, `b`: ipRange values.

    Returns true when `compare a b >= 0`.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the earlier of two ranges in sort order.

    `a`, `b`: ipRange values.

    Returns the lesser range; `a` when they compare equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the later of two ranges in sort order.

    `a`, `b`: ipRange values.

    Returns the greater range; `a` when they compare equal.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    addressAt
    addresses
    addressesUnbounded
    compare
    contains
    eq
    from
    fromAddress
    fromCidr
    ge
    gt
    is
    isAdjacent
    isIpv4
    isIpv6
    isSingleton
    isSubrangeOf
    isSuperrangeOf
    isValid
    le
    lt
    make
    max
    merge
    min
    overlaps
    parse
    size
    to
    toCidrs
    toString
    tryParse
    version
    ;
}
