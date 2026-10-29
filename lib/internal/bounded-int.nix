/*
  Shared implementation for bounded-integer modules. Each domain supplies
  its tag and inclusive bounds; arithmetic is opt-in because it does not
  describe meaningful operations on ICMP message types.

  The text form is unsigned decimal, so `lowestValue` must not be
  negative. Keep validation separate from tag inspection: `is` recognizes
  a tag without forcing the payload, while `isValid` checks text.

  The public `port`, `vlanId`, `mtu`, and `icmpType` modules export these
  functions, so their headers describe public API. `scalar` below means
  a value tagged with `typeName`.
*/
{
  typeName,
  lowestValue,
  highestValue,
  arithmetic ? false,
}:
let
  parsing = import ./parse.nix;
  types = import ./types.nix;
  rangeText = "[${builtins.toString lowestValue}, ${builtins.toString highestValue}]";

  mk = value: {
    _type = typeName;
    inherit value;
  };

  inRange = n: builtins.isInt n && n >= lowestValue && n <= highestValue;

  /*
    Parse a value from its decimal text without throwing, so callers can
    handle invalid input themselves.

    `input`: decimal string within the inclusive bounds, without sign,
    whitespace or leading zeros.

    Returns a tryResult: `{ success = true; value = <scalar>; }` or
    `{ success = false; error = <message>; }`.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.${typeName}.parse: input must be a string"
    else
      let
        number = parsing.decimal highestValue input;
      in
      if !(parsing.isDecimal input) then
        types.tryErr "libnet.${typeName}.parse: not a decimal number: \"${input}\""
      else if number == null || !(inRange number) then
        types.tryErr "libnet.${typeName}.parse: out of range ${rangeText}: ${input}"
      else
        types.tryOk (mk number);

  /*
    Parse a value from its decimal text, for configuration values written
    as text.

    `input`: decimal string within the inclusive bounds, without sign,
    whitespace or leading zeros.

    Returns the tagged value; throws on malformed or out-of-range input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Check whether a string parses as a value of this domain.

    `input`: candidate string.

    Returns true when `tryParse input` succeeds.
  */
  isValid = input: (tryParse input).success;

  /*
    Recognize a constructed value by its tag, without forcing its payload,
    so callers can dispatch on the kind of value.

    `value`: any value.

    Returns true when `value` is an attrset tagged with `typeName`.
  */
  is = value: types.hasTag typeName value;

  /*
    Lift a bare integer into a value, for values computed or written as
    numbers.

    `n`: integer within the inclusive bounds.

    Returns the tagged value; throws when `n` is out of range or not an
    integer.
  */
  fromInt =
    n:
    if !(inRange n) then
      throw "libnet.${typeName}.fromInt: out of range ${rangeText}: ${builtins.toString n}"
    else
      mk n;

  /*
    Unwrap a value to the bare integer it holds.

    `scalar`: tagged value.

    Returns the integer.
  */
  toInt = scalar: scalar.value;

  /*
    Render a value in decimal.

    `scalar`: tagged value.

    Returns the decimal string.
  */
  toString = scalar: builtins.toString scalar.value;

  /*
    Test two values for equality, including their tags.

    `a`, `b`: tagged values.

    Returns true when both tags and integers match.
  */
  eq = a: b: types.hasSameTag a b && a.value == b.value;

  /*
    Order two values numerically.

    `a`, `b`: tagged values.

    Returns -1, 0, or 1 as `a` is less than, equal to, or greater than `b`.
  */
  compare =
    a: b:
    if a.value < b.value then
      -1
    else if a.value > b.value then
      1
    else
      0;

  /*
    Test whether `a` is less than `b`.

    `a`, `b`: tagged values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` is less than or equal to `b`.

    `a`, `b`: tagged values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` is greater than `b`.

    `a`, `b`: tagged values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` is greater than or equal to `b`.

    `a`, `b`: tagged values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Select the smaller of two values.

    `a`, `b`: tagged values.

    Returns the smaller value, or `a` when they are equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Select the larger of two values.

    `a`, `b`: tagged values.

    Returns the larger value, or `a` when they are equal.
  */
  max = a: b: if ge a b then a else b;

  /*
    Offset a value by an integer, staying within the domain.

    `n`: integer offset; may be negative.
    `scalar`: tagged value.

    Returns the offset value; throws when the result is out of range.
  */
  add =
    n: scalar:
    let
      result = scalar.value + n;
    in
    if !(inRange result) then
      throw "libnet.${typeName}.add: result out of range ${rangeText}: ${builtins.toString result}"
    else
      mk result;

  /*
    Offset a value downward by an integer; `sub n` is `add (-n)`.

    `n`: integer to subtract; may be negative.
    `scalar`: tagged value.

    Returns the offset value; throws when the result is out of range.
  */
  sub = n: scalar: add (0 - n) scalar;

  /*
    Measure the distance between two values. All scalar modules define
    `diff` as the second argument minus the first.

    `a`, `b`: tagged values.

    Returns the integer `b - a`.
  */
  diff = a: b: b.value - a.value;

  /*
    Step to the following value, for iterating through the domain.

    `scalar`: tagged value.

    Returns the value one higher; throws when `scalar` is already at the
    upper bound.
  */
  next = scalar: add 1 scalar;

  /*
    Step to the preceding value, for iterating through the domain.

    `scalar`: tagged value.

    Returns the value one lower; throws when `scalar` is already at the
    lower bound.
  */
  prev = scalar: sub 1 scalar;
in
if lowestValue < 0 then
  throw "libnet.internal.boundedInt: lowestValue of ${typeName} must not be negative, since decimal text has no sign: ${builtins.toString lowestValue}"
else
  {
    inherit
      compare
      eq
      fromInt
      ge
      gt
      highestValue
      is
      isValid
      le
      lowestValue
      lt
      max
      min
      parse
      toInt
      toString
      tryParse
      ;
  }
  // (
    if arithmetic then
      {
        inherit
          add
          diff
          next
          prev
          sub
          ;
      }
    else
      { }
  )
