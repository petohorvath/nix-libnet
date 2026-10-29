/*
  Shared implementation for bounded-integer modules. Each domain supplies
  its tag and inclusive bounds; arithmetic is opt-in because it does not
  describe meaningful operations on ICMP message types.

  The text form is unsigned decimal, so `minValue` must not be
  negative. Keep validation separate from tag inspection: `is` recognizes
  a tag without forcing the payload, while `isValid` checks text.

  The public `port`, `vlanId`, `mtu`, and `icmpType` modules export these
  functions, so their headers describe public API. `scalar` below means
  a value tagged with `typeName`. Every function except `is`, `eq`,
  `isValid` and `tryParse` throws for an argument of the wrong kind.
*/
{
  typeName,
  minValue,
  maxValue,
  arithmetic ? false,
}:
let
  errors = import ./errors.nix;
  parsing = import ./parse.nix;
  types = import ./types.nix;
  rangeText = "[${builtins.toString minValue}, ${builtins.toString maxValue}]";

  mk = value: {
    _type = typeName;
    inherit value;
  };

  inRange = n: n >= minValue && n <= maxValue;

  # Unwrap a scalar argument of `function`, throwing for any other kind.
  valueOf = function: scalar: (errors.expectKind "${typeName}.${function}" typeName scalar).value;

  intArgument = function: errors.expectType "${typeName}.${function}" "int";

  outOfRange =
    function: text: errors.fail "${typeName}.${function}" "out of range ${rangeText}: ${text}";

  parseError = detail: types.tryErr (errors.message "${typeName}.parse" detail);

  # The comparison and offset logic shared by the public functions, each
  # taking the name of the public function its errors report.
  compareFor =
    function: a: b:
    let
      left = valueOf function a;
      right = valueOf function b;
    in
    if left < right then
      -1
    else if left > right then
      1
    else
      0;

  # Bound the offset, not the result: both bounds lie within a domain
  # width of zero, so no check can overflow a Nix integer, which Nix 2.18
  # would wrap silently.
  addFor =
    function: n: scalar:
    let
      offset = intArgument function n;
      value = valueOf function scalar;
    in
    if offset < minValue - value || offset > maxValue - value then
      outOfRange function "${builtins.toString value} + ${builtins.toString offset}"
    else
      mk (value + offset);

  subFor =
    function: n: scalar:
    let
      offset = intArgument function n;
      value = valueOf function scalar;
    in
    if offset < value - maxValue || offset > value - minValue then
      outOfRange function "${builtins.toString value} - ${builtins.toString offset}"
    else
      mk (value - offset);

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
      parseError "expected string, got ${errors.describe input}"
    else
      let
        number = parsing.decimal maxValue input;
      in
      if builtins.match "0[0-9]+" input != null then
        parseError "leading zero in \"${input}\""
      else if !(parsing.isDecimal input) then
        parseError "not a decimal number: \"${input}\""
      else if number == null || !(inRange number) then
        parseError "out of range ${rangeText}: ${input}"
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
    let
      checked = intArgument "fromInt" n;
    in
    if inRange checked then mk checked else outOfRange "fromInt" (builtins.toString checked);

  /*
    Unwrap a value to the bare integer it holds.

    `scalar`: tagged value.

    Returns the integer.
  */
  toInt = valueOf "toInt";

  /*
    Render a value in decimal.

    `scalar`: tagged value.

    Returns the decimal string.
  */
  toString = scalar: builtins.toString (valueOf "toString" scalar);

  /*
    Test two values for equality, including their tags.

    `a`, `b`: tagged values.

    Returns true when both tags and integers match.
  */
  eq = a: b: types.bothHaveTag typeName a b && a.value == b.value;

  /*
    Order two values numerically.

    `a`, `b`: tagged values.

    Returns -1, 0, or 1 as `a` is less than, equal to, or greater than `b`.
  */
  compare = compareFor "compare";

  /*
    Test whether `a` is less than `b`.

    `a`, `b`: tagged values.

    Returns a Boolean.
  */
  lt = a: b: compareFor "lt" a b == -1;

  /*
    Test whether `a` is less than or equal to `b`.

    `a`, `b`: tagged values.

    Returns a Boolean.
  */
  le = a: b: compareFor "le" a b <= 0;

  /*
    Test whether `a` is greater than `b`.

    `a`, `b`: tagged values.

    Returns a Boolean.
  */
  gt = a: b: compareFor "gt" a b == 1;

  /*
    Test whether `a` is greater than or equal to `b`.

    `a`, `b`: tagged values.

    Returns a Boolean.
  */
  ge = a: b: compareFor "ge" a b >= 0;

  /*
    Select the smaller of two values.

    `a`, `b`: tagged values.

    Returns the smaller value, or `a` when they are equal.
  */
  min = a: b: if compareFor "min" a b <= 0 then a else b;

  /*
    Select the larger of two values.

    `a`, `b`: tagged values.

    Returns the larger value, or `a` when they are equal.
  */
  max = a: b: if compareFor "max" a b >= 0 then a else b;

  /*
    Offset a value by an integer, staying within the domain.

    `n`: integer offset; may be negative.
    `scalar`: tagged value.

    Returns the offset value; throws when `n` is not an integer or the
    result is out of range.
  */
  add = addFor "add";

  /*
    Offset a value downward by an integer, the inverse of `add`.

    `n`: integer to subtract; may be negative.
    `scalar`: tagged value.

    Returns the offset value; throws when `n` is not an integer or the
    result is out of range.
  */
  sub = subFor "sub";

  /*
    Measure the distance between two values. All scalar modules define
    `diff` as the second argument minus the first.

    `a`, `b`: tagged values.

    Returns the integer `b - a`.
  */
  diff = a: b: valueOf "diff" b - valueOf "diff" a;

  /*
    Step to the following value, for iterating through the domain.

    `scalar`: tagged value.

    Returns the value one higher; throws when `scalar` is already at the
    upper bound.
  */
  next = addFor "next" 1;

  /*
    Step to the preceding value, for iterating through the domain.

    `scalar`: tagged value.

    Returns the value one lower; throws when `scalar` is already at the
    lower bound.
  */
  prev = subFor "prev" 1;
in
if minValue < 0 then
  throw "libnet.internal.boundedInt: minValue of ${typeName} must not be negative, since decimal text has no sign: ${builtins.toString minValue}"
else
  {
    inherit
      compare
      eq
      fromInt
      ge
      gt
      is
      isValid
      le
      lt
      max
      maxValue
      min
      minValue
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
