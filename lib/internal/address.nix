/*
  Arithmetic and integer-list checks shared by the address kinds and the
  `ip` union. Each function takes `caller`, the public function its errors
  name, so `ip.next` reports `libnet.ip.next` even though the IPv4 code
  does the work. Callers check the kind of the address operand; these
  functions check the offset and the integer lists.

  Every range check runs before the arithmetic it guards, since Nix 2.18
  wraps integer overflow silently.
*/
let
  bits = import ./bits.nix;
  carry = import ./carry.nix;
  errors = import ./errors.nix;

  offsetOf = caller: errors.expectType caller "int";

  outOfRange = caller: text: errors.fail caller "out of range: ${text}";

  # Arithmetic on an address stored as one integer `value` in
  # [0, maxValue], such as IPv4 and MAC. `format` renders an address for
  # error messages.
  scalar =
    {
      typeName,
      maxValue,
      format,
    }:
    let
      mk = value: {
        _type = typeName;
        inherit value;
      };
    in
    {
      # Bound the offset, not the result: both bounds lie within
      # `maxValue` of zero, so no check can overflow.
      add =
        caller: n: address:
        let
          offset = offsetOf caller n;
          inherit (address) value;
        in
        if offset < 0 - value || offset > maxValue - value then
          outOfRange caller "${format address} + ${builtins.toString offset}"
        else
          mk (value + offset);

      sub =
        caller: n: address:
        let
          offset = offsetOf caller n;
          inherit (address) value;
        in
        if offset < value - maxValue || offset > value then
          outOfRange caller "${format address} - ${builtins.toString offset}"
        else
          mk (value - offset);
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
      mk = words: {
        _type = "ipv6";
        inherit words;
      };
      # The carry or borrow out of the top word of an in-range result.
      expectedCarry = offset: if offset < 0 then 1 else 0;
    in
    {
      add =
        caller: n: address:
        let
          offset = offsetOf caller n;
          result = addWords address.words (offsetWords offset);
        in
        if result.carry != expectedCarry offset then
          outOfRange caller "${format address} + ${builtins.toString offset}"
        else
          mk result.words;

      sub =
        caller: n: address:
        let
          offset = offsetOf caller n;
          result = subWords address.words (offsetWords offset);
        in
        if result.borrow != expectedCarry offset then
          outOfRange caller "${format address} - ${builtins.toString offset}"
        else
          mk result.words;

      # `b - a` as an integer. A magnitude below 2^63 fits either way,
      # and exactly 2^63 fits only as the negative -2^63.
      diff =
        caller: a: b:
        let
          forward = subWords b.words a.words;
          magnitude = if forward.borrow == 0 then forward.words else (subWords a.words b.words).words;
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
in
{
  inherit intList scalar words;
}
