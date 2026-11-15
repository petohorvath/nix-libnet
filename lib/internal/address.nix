/*
  Arithmetic and builders shared by the address kinds, the `ip` union
  and the bounded integers. Each arithmetic function and checked builder
  takes `caller`, the public function its errors name, so `ip.next`
  reports `libnet.ip.next` even though the IPv4 arithmetic does the
  work. They check every argument: the kind of the operands, the offset
  and the lists of parts. The `…Unchecked` builders take no `caller` and
  check nothing, for parsers whose parts are in range by construction.

  Every range check runs before the arithmetic it guards, since Nix 2.18
  wraps integer overflow silently.
*/
let
  bits = import ./bits.nix;
  carry = import ./carry.nix;
  errors = import ./errors.nix;
  formatting = import ./format.nix;

  # Throw for a result outside the range, which `range` names unless it
  # is null.
  outOfRange =
    range: caller: text:
    errors.fail caller (
      if range == null then "out of range: ${text}" else "out of range ${range}: ${text}"
    );

  /*
    `add value offset` and `sub value offset` for an integer `value` in
    [minValue, maxValue], or null when the result leaves that range. The
    checks bound the offset, not the result: both bounds lie within a
    domain width of zero, so no check can overflow a Nix integer, which
    Nix 2.18 would wrap silently.
  */
  offsetWithin =
    { minValue, maxValue }:
    {
      add =
        value: offset:
        if offset < minValue - value || offset > maxValue - value then null else value + offset;
      sub =
        value: offset:
        if offset < value - maxValue || offset > value - minValue then null else value - offset;
    };

  /*
    Arithmetic on a value stored as one integer `value` in [minValue,
    maxValue] under the tag `typeName`, such as IPv4, MAC and the bounded
    integers. `format` renders an operand for error messages, and `range`,
    when set, names the range in them, such as `[0, 65535]`.
  */
  scalar =
    {
      typeName,
      minValue ? 0,
      maxValue,
      format,
      range ? null,
    }:
    let
      mk = value: {
        _type = typeName;
        inherit value;
      };
      valueOf = caller: operand: (errors.expectKind caller typeName operand).value;
      within = offsetWithin { inherit minValue maxValue; };
      # Apply `step` from `within`, written `symbol` in errors.
      offsetBy =
        step: symbol: caller: n: operand:
        let
          offset = errors.intArgument caller n;
          result = step (valueOf caller operand) offset;
        in
        if result == null then
          outOfRange range caller "${format operand} ${symbol} ${builtins.toString offset}"
        else
          mk result;
    in
    {
      add = offsetBy within.add "+";
      sub = offsetBy within.sub "-";
      # `b - a`, which cannot overflow, since both lie in the range.
      diff =
        caller: a: b:
        valueOf caller b - valueOf caller a;
    };

  ipv4Arithmetic = scalar {
    typeName = "ipv4";
    maxValue = bits.mask32;
    format = ip: formatting.ipv4 ip.value;
  };

  # ===== 128-bit words =====

  # An integer offset as four u32 words of a 128-bit two's complement
  # number, most significant first. `offset - low` is a multiple of 2^32
  # no smaller than `offset`, so the division is exact and cannot
  # overflow, even for -2^63.
  offsetWords =
    offset:
    let
      low = builtins.bitAnd offset bits.mask32;
      high = (offset - low) / bits.pow2_32;
      fill = if offset < 0 then bits.mask32 else 0;
    in
    [
      fill
      fill
      (builtins.bitAnd high bits.mask32)
      low
    ];

  addWords =
    a: b:
    let
      wordSum = i: carryIn: carry.add32 (builtins.elemAt a i) (builtins.elemAt b i) carryIn;
      result3 = wordSum 3 0;
      result2 = wordSum 2 result3.carry;
      result1 = wordSum 1 result2.carry;
      result0 = wordSum 0 result1.carry;
    in
    {
      words = [
        result0.sum
        result1.sum
        result2.sum
        result3.sum
      ];
      inherit (result0) carry;
    };

  subWords =
    a: b:
    let
      wordDiff = i: borrowIn: carry.sub32 (builtins.elemAt a i) (builtins.elemAt b i) borrowIn;
      result3 = wordDiff 3 0;
      result2 = wordDiff 2 result3.borrow;
      result1 = wordDiff 1 result2.borrow;
      result0 = wordDiff 0 result1.borrow;
    in
    {
      words = [
        result0.diff
        result1.diff
        result2.diff
        result3.diff
      ];
      inherit (result0) borrow;
    };

  # The smallest Nix integer, -2^63, which has no literal.
  minInt = -9223372036854775807 - 1;

  /*
    Arithmetic on an address stored as four u32 `words`, IPv6. A
    negative offset is 2^128 plus the offset in two's complement, so the
    result stays in range exactly when the carry or borrow out of the top
    word is 1 for a negative offset and 0 otherwise.
  */
  words =
    { format }:
    let
      typeName = "ipv6";
      mk = words: {
        _type = typeName;
        inherit words;
      };
      wordsOf = caller: address: (errors.expectKind caller typeName address).words;
      # The carry or borrow out of the top word of an in-range result.
      expectedCarry = offset: if offset < 0 then 1 else 0;
    in
    {
      add =
        caller: n: address:
        let
          offset = errors.intArgument caller n;
          result = addWords (wordsOf caller address) (offsetWords offset);
        in
        if result.carry != expectedCarry offset then
          outOfRange null caller "${format address} + ${builtins.toString offset}"
        else
          mk result.words;

      sub =
        caller: n: address:
        let
          offset = errors.intArgument caller n;
          result = subWords (wordsOf caller address) (offsetWords offset);
        in
        if result.borrow != expectedCarry offset then
          outOfRange null caller "${format address} - ${builtins.toString offset}"
        else
          mk result.words;

      # `b - a` as an integer. A magnitude below 2^63 fits either way,
      # and exactly 2^63 fits only as the negative -2^63.
      diff =
        caller: a: b:
        let
          wordsA = wordsOf caller a;
          wordsB = wordsOf caller b;
          forward = subWords wordsB wordsA;
          magnitude = if forward.borrow == 0 then forward.words else (subWords wordsA wordsB).words;
          word0 = builtins.elemAt magnitude 0;
          word1 = builtins.elemAt magnitude 1;
          word2 = builtins.elemAt magnitude 2;
          word3 = builtins.elemAt magnitude 3;
          fits = word0 == 0 && word1 == 0 && word2 < 2147483648; # 2^31
          isMinInt = forward.borrow == 1 && word0 == 0 && word1 == 0 && word2 == 2147483648 && word3 == 0;
          value = word2 * bits.pow2_32 + word3;
        in
        if isMinInt then
          minInt
        else if !fits then
          errors.fail caller "difference out of the Nix integer range: ${format b} - ${format a}"
        else if forward.borrow == 0 then
          value
        else
          0 - value;
    };

  ipv6Arithmetic = words { format = ip: formatting.ipv6 ip.words; };

  # ===== Part lists =====

  # Check a list of `count` integers in [0, maxValue], such as the bytes
  # of an address, each called a `part` in errors. Returns the list, or
  # throws for `caller`.
  intList =
    caller:
    {
      count,
      part,
      maxValue,
    }:
    list:
    let
      checked = errors.expectType caller "list" list;
      length = builtins.length checked;
      check =
        element:
        if !(builtins.isInt element) then
          errors.fail caller "expected int ${part}, got ${errors.describe element}"
        else if element < 0 || element > maxValue then
          errors.fail caller "${part} out of range [0, ${builtins.toString maxValue}]: ${builtins.toString element}"
        else
          null;
    in
    if length != count then
      errors.fail caller "expected ${builtins.toString count} ${part}s, got ${builtins.toString length}"
    else
      builtins.seq (builtins.foldl' (_: check) null checked) checked;

  # ===== Builders =====

  /*
    `build`, checking its list of parts for `caller` first, with the
    `count`, `part` and `maxValue` of `intList`. The check is forced when
    the builder is called, so a bad list throws there rather than when a
    field of the value is read.
  */
  withCheckedParts =
    settings: build: caller: list:
    let
      parts = intList caller settings list;
    in
    builtins.seq parts (build parts);

  byteParts = count: {
    inherit count;
    part = "byte";
    maxValue = bits.mask8;
  };

  ipv4FromBytes = bytes: {
    _type = "ipv4";
    value = bits.fromParts 8 bytes;
  };

  ipv6FromWords = words: {
    _type = "ipv6";
    inherit words;
  };

  ipv6FromGroups = groups: ipv6FromWords (bits.partsToWords 16 groups);

  ipv6FromBytes = bytes: ipv6FromWords (bits.partsToWords 8 bytes);

  macFromBytes = bytes: {
    _type = "mac";
    value = bits.fromParts 8 bytes;
  };
in
{
  inherit
    offsetWithin
    scalar
    words
    ;

  ipv4 = ipv4Arithmetic // {
    fromBytes = withCheckedParts (byteParts 4) ipv4FromBytes;
    fromBytesUnchecked = ipv4FromBytes;
  };

  ipv6 = ipv6Arithmetic // {
    fromWords = withCheckedParts {
      count = 4;
      part = "word";
      maxValue = bits.mask32;
    } ipv6FromWords;
    fromGroups = withCheckedParts {
      count = 8;
      part = "group";
      maxValue = bits.mask16;
    } ipv6FromGroups;
    fromGroupsUnchecked = ipv6FromGroups;
    fromBytes = withCheckedParts (byteParts 16) ipv6FromBytes;
  };

  mac = {
    fromBytes = withCheckedParts (byteParts 6) macFromBytes;
    fromBytesUnchecked = macFromBytes;
  };
}
