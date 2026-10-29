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
  carry = import ./internal/carry.nix;
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ip = import ./ip.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  cidr = import ./cidr.nix;

  # Force both fields, so a constructor throws for a bad argument when
  # it builds the value rather than when a field is read.
  mk =
    first: last:
    builtins.seq first (
      builtins.seq last {
        _type = "ipRange";
        from = first;
        to = last;
      }
    );

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

  # ===== Argument kinds =====

  /*
    Each returns its argument, throwing for the wrong kind on behalf of
    the public `function`. The unchecked helpers below, such as `sizeFor`
    and `order`, take values the public function has already checked.
  */
  ipRangeArgument = function: errors.expectKind "ipRange.${function}" "ipRange";
  intArgument = errors.intArgument "ipRange";
  addressArgument = function: errors.expect "ipRange.${function}" "ipv4 or ipv6 value" types.isIp;

  # Check both range operands of a binary `function`, then apply
  # `relation` to them.
  binary =
    function: relation: a: b:
    relation (ipRangeArgument function a) (ipRangeArgument function b);

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
    let
      parseError = detail: types.tryErr (errors.message "ipRange.parse" detail);
      isV6Input = text: parsing.countOccurrences ":" text > 0;
      # The address parser's detail, without its own prefix.
      addressDetail =
        text: result: errors.detail (if isV6Input text then "ipv6.parse" else "ipv4.parse") result.error;
    in
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else
      let
        parts = parsing.splitOn "-" input;
        partCount = builtins.length parts;
      in
      if partCount != 2 then
        parseError "missing '-' or too many: \"${input}\""
      else
        let
          fromInput = builtins.elemAt parts 0;
          toInput = builtins.elemAt parts 1;
          fromResult = if isV6Input fromInput then ipv6.tryParse fromInput else ipv4.tryParse fromInput;
          toResult = if isV6Input toInput then ipv6.tryParse toInput else ipv4.tryParse toInput;
        in
        if !fromResult.success then
          parseError "invalid 'from': ${addressDetail fromInput fromResult}"
        else if !toResult.success then
          parseError "invalid 'to': ${addressDetail toInput toResult}"
        else if fromResult.value._type != toResult.value._type then
          parseError "mixed families in \"${input}\""
        else if !(leFor fromResult.value fromResult.value toResult.value) then
          parseError "'from' > 'to' in \"${input}\""
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
      checked = ipRangeArgument "toString" range;
      formatAddress = if isV4 checked.from then ipv4.toString else ipv6.toString;
    in
    "${formatAddress checked.from}-${formatAddress checked.to}";

  /*
    Build a range from two address values.

    `first`: lowest address (ipv4 or ipv6 value).
    `last`: highest address, same family as `first`.

    Returns an ipRange value; throws on non-address inputs, mixed
    families, or first > last.
  */
  make =
    first: last:
    let
      lowest = addressArgument "make" first;
      highest = addressArgument "make" last;
      formatAddress = if isV4 lowest then ipv4.toString else ipv6.toString;
    in
    if lowest._type != highest._type then
      errors.fail "ipRange.make" "mixed families"
    else if !(leFor lowest lowest highest) then
      errors.fail "ipRange.make" "from > to: ${formatAddress lowest}-${formatAddress highest}"
    else
      mk lowest highest;

  /*
    Build a range holding exactly one address, parallel to
    `cidr.fromAddress` and `portRange.fromPort`.

    `address`: ipv4 or ipv6 value.

    Returns a single-address ipRange; throws when given a non-address.
  */
  fromAddress =
    address:
    let
      checked = addressArgument "fromAddress" address;
    in
    mk checked checked;

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
  isIpv4 = range: isV4 (ipRangeArgument "isIpv4" range).from;

  /*
    Check whether a range holds IPv6 addresses.

    `range`: ipRange value.

    Returns true for an IPv6 range.
  */
  isIpv6 = range: isV6 (ipRangeArgument "isIpv6" range).from;

  /*
    Check whether a range holds a single address.

    `range`: ipRange value.

    Returns true when from equals to.
  */
  isSingleton =
    range:
    let
      checked = ipRangeArgument "isSingleton" range;
    in
    sameAddress checked.from checked.to;

  # ===== Accessors =====

  /*
    Get the lowest address of a range.

    `range`: ipRange value.

    Returns the `from` address value.
  */
  from = range: (ipRangeArgument "from" range).from;

  /*
    Get the highest address of a range.

    `range`: ipRange value.

    Returns the `to` address value.
  */
  to = range: (ipRangeArgument "to" range).to;

  /*
    Get the IP version of a range.

    `range`: ipRange value.

    Returns 4 or 6.
  */
  version = range: if isV4 (ipRangeArgument "version" range).from then 4 else 6;

  /*
    The address count of `range`, throwing on behalf of `function` when
    it reaches 2^63, which a Nix int cannot hold. The IPv6 count is
    checked on the words before any arithmetic that could overflow,
    which Nix 2.18 would wrap silently.
  */
  sizeFor =
    function: range:
    if isV4 range.from then
      range.to.value - range.from.value + 1
    else
      let
        word =
          i: borrow:
          carry.sub32 (builtins.elemAt range.to.words i) (builtins.elemAt range.from.words i) borrow;
        word3 = word 3 0;
        word2 = word 2 word3.borrow;
        word1 = word 1 word2.borrow;
        word0 = word 0 word1.borrow;
        # 2^31 - 1, the largest high word of a difference below 2^63.
        highMax = 2147483647;
      in
      if
        word0.diff != 0
        || word1.diff != 0
        || word2.diff > highMax
        || (word2.diff == highMax && word3.diff == bits.mask32)
      then
        errors.fail "ipRange.${function}" "range too large for a Nix integer (2^63 or more addresses)"
      else
        word2.diff * bits.pow2_32 + word3.diff + 1;

  /*
    Count the addresses in a range.

    `range`: ipRange value.

    Returns `to - from + 1` as an integer; throws for IPv6 ranges of 2^63
    or more addresses, which a Nix int cannot hold.
  */
  size = range: sizeFor "size" (ipRangeArgument "size" range);

  # ===== Containment & relationships =====

  /*
    Check whether an address lies inside a range.

    `range`: ipRange value.
    `address`: value to test.

    Returns true when `address` lies within [from, to]; false for an
    address of the other family. Throws for any other value.
  */
  contains =
    range: address:
    let
      checkedRange = ipRangeArgument "contains" range;
      checkedAddress = addressArgument "contains" address;
      lessOrEqual = leFor checkedRange.from;
    in
    checkedRange.from._type == checkedAddress._type
    && (lessOrEqual checkedRange.from checkedAddress)
    && (lessOrEqual checkedAddress checkedRange.to);

  overlapping =
    a: b:
    if a.from._type != b.from._type then
      false
    else
      let
        lessOrEqual = leFor a.from;
      in
      (lessOrEqual a.from b.to) && (lessOrEqual b.from a.to);

  /*
    Check whether two ranges share at least one address. Symmetric.

    `a`, `b`: ipRange values.

    Returns true when the ranges intersect; false across families.
  */
  overlaps = binary "overlaps" overlapping;

  subrange =
    a: b:
    if a.from._type != b.from._type then
      false
    else
      let
        lessOrEqual = leFor a.from;
      in
      (lessOrEqual b.from a.from) && (lessOrEqual a.to b.to);

  /*
    Check whether one range lies within another.

    `a`: candidate inner range.
    `b`: candidate outer range.

    Returns true when `a` is a subset of `b` (including equal ranges);
    false across families.
  */
  isSubrangeOf = binary "isSubrangeOf" subrange;

  /*
    Check whether one range encloses another; inverse of `isSubrangeOf`.

    `a`: candidate outer range.
    `b`: candidate inner range.

    Returns true when `b` is a subset of `a` (including equal ranges).
  */
  isSuperrangeOf = binary "isSuperrangeOf" (a: b: subrange b a);

  adjacent =
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
    Check whether two ranges touch with no gap and no overlap. A range
    ending at the family's top address has no upward neighbour.

    `a`, `b`: ipRange values.

    Returns true when one range ends immediately before the other
    starts; false across families.
  */
  isAdjacent = binary "isAdjacent" adjacent;

  /*
    Combine two ranges into one when they overlap or touch.

    `a`, `b`: ipRange values.

    Returns the spanning ipRange, or null when a gap separates them or
    the families differ.
  */
  merge = binary "merge" (
    a: b:
    if a.from._type != b.from._type then
      null
    else if overlapping a b || adjacent a b then
      let
        lessOrEqual = leFor a.from;
        greaterOrEqual = x: y: lessOrEqual y x;
        mergedFrom = if lessOrEqual a.from b.from then a.from else b.from;
        mergedTo = if greaterOrEqual a.to b.to then a.to else b.to;
      in
      mk mergedFrom mergedTo
    else
      null
  );

  # ===== Enumeration =====

  # The `count` addresses of `range` from `from` up.
  listAddresses =
    range: count:
    let
      offsetAddress = addFor range.from;
    in
    builtins.genList (i: offsetAddress i range.from) count;

  /*
    List every address in a range with no size guard; the caller bounds
    the cost.

    `range`: ipRange value.

    Returns the addresses from `from` to `to` in ascending order.
  */
  addressesUnbounded =
    range:
    let
      checked = ipRangeArgument "addressesUnbounded" range;
    in
    listAddresses checked (sizeFor "addressesUnbounded" checked);

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
      checked = ipRangeArgument "addresses" range;
      rangeSize = sizeFor "addresses" checked;
    in
    if rangeSize > bits.pow2 16 then
      errors.fail "ipRange.addresses" "range too large (${builtins.toString rangeSize} > 2^16); use addressesUnbounded"
    else
      listAddresses checked rangeSize;

  /*
    Index into a range, parallel to `cidr.addressAt` and
    `ipBindpoint.endpointAt`. Like `cidr.addressAt` it relies on `size`, so
    it throws for IPv6 ranges of 2^63 or more addresses.

    `n`: 0-based offset from `from`; negative values count from the end.
    `range`: ipRange value.

    Returns the selected address; throws when `n` is not an integer or
    falls outside the range.
  */
  addressAt =
    n: range:
    let
      offset = intArgument "addressAt" n;
      checked = ipRangeArgument "addressAt" range;
      rangeSize = sizeFor "addressAt" checked;
      index = if offset < 0 then rangeSize + offset else offset;
    in
    if index < 0 || index >= rangeSize then
      errors.fail "ipRange.addressAt" "index out of range [0, ${builtins.toString rangeSize}): ${builtins.toString offset}"
    else
      (addFor checked.from) index checked.from;

  # ===== CIDR interop =====

  /*
    Convert a CIDR block into the range it covers.

    `cidrValue`: cidr value.

    Returns the range from the network address to the block's top
    address (broadcast for IPv4); throws when given a non-cidr.
  */
  fromCidr =
    cidrValue:
    let
      block = errors.expectKind "ipRange.fromCidr" "cidr" cidrValue;
    in
    mk (cidr.networkAddress block) (cidr.topAddress block);

  /*
    Cover a range exactly with the fewest CIDR blocks, for tools that
    accept only prefixes.

    `range`: ipRange value.

    Returns a list of cidr values in ascending address order.
  */
  toCidrs =
    toCidrsArgument:
    let
      range = ipRangeArgument "toCidrs" toCidrsArgument;
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
                block = cidr.supernet (maxPrefix - prefix) (cidr.fromAddress start);
                networkAddress = cidr.networkAddress block;
                topAddress = cidr.topAddress block;
              in
              if (sameAddress networkAddress start) && (lessOrEqual topAddress end) then
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

  # Order checked ranges by family (IPv4 first), then `from`, then `to`.
  order =
    a: b:
    comparison.lexicographic [
      (ip.compare a.from b.from)
      (ip.compare a.to b.to)
    ];

  ordering = comparison.suite (function: binary function order);

  /*
    Test two address ranges for equality.

    `a`, `b`: ipRange values.

    Returns true when both have the same type tag, family, `from`, and
    `to`.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.ipRange a b
    && a.from._type == b.from._type
    && (
      if isV4 a.from then
        ipv4.eq a.from b.from && ipv4.eq a.to b.to
      else
        ipv6.eq a.from b.from && ipv6.eq a.to b.to
    );
in
{
  inherit
    addressAt
    addresses
    addressesUnbounded
    contains
    eq
    from
    fromAddress
    fromCidr
    is
    isAdjacent
    isIpv4
    isIpv6
    isSingleton
    isSubrangeOf
    isSuperrangeOf
    isValid
    make
    merge
    overlaps
    parse
    size
    to
    toCidrs
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
