/*
  Shared implementation for int-only scalar modules. Each domain supplies
  its tag and inclusive bounds; arithmetic is opt-in because it does not
  describe meaningful operations on ICMP message types.

  Keep validation separate from tag inspection: `is` recognizes a tag
  without forcing the payload, while `isValid` checks a bare integer.

  The public `vlanId`, `mtu`, and `icmpType` modules export these
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
  types = import ./types.nix;
  rangeText = "[${builtins.toString lowestValue}, ${builtins.toString highestValue}]";

  mk = value: {
    _type = typeName;
    inherit value;
  };

  /*
    Check a bare integer against the domain bounds, before constructing a
    value or when validating option input.

    `value`: any value.

    Returns true when `value` is an integer within the inclusive bounds.
  */
  isValid = value: builtins.isInt value && value >= lowestValue && value <= highestValue;

  /*
    Recognize a constructed value by its tag, without forcing its payload,
    so callers can dispatch on the kind of value.

    `value`: any value.

    Returns true when `value` is an attrset tagged with `typeName`.
  */
  is = value: types.hasTag typeName value;

  /*
    Construct a value from a bare integer; integers are the written form,
    so there is no string parser.

    `n`: integer within the inclusive bounds.

    Returns the tagged value; throws when `n` is out of range or not an
    integer.
  */
  fromInt =
    n:
    if !(isValid n) then
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
    if !(isValid result) then
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
    toInt
    toString
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
