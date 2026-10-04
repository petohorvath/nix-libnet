/*
  libnet.port

  Validate and manipulate TCP/UDP port numbers (0..65535). Predicates
  classify ports as well-known (0..1023), registered (1024..49151),
  or dynamic / ephemeral (49152..65535).

  Note: `diff a b` returns `toInt b - toInt a` (second arg minus first),
  matching the other scalar modules (ipv4, ipv6, mac) for consistency.

  Example:
    libnet.port.parse "8080"
    => { _type = "port"; value = 8080; }

    libnet.port.isDynamic (libnet.port.parse "50000")
    => true
*/
let
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  portMax = 65535;

  mk = value: {
    _type = "port";
    inherit value;
  };

  # ===== Conversion =====

  /*
    Lift a raw integer into a port value, for ports computed or written
    as numbers.

    `n`: integer in [0, 65535].

    Returns a port value; throws on a non-integer or out-of-range input.
  */
  fromInt =
    n:
    if !(builtins.isInt n) || n < 0 || n > portMax then
      throw "libnet.port.fromInt: out of range [0, 65535]: ${builtins.toString n}"
    else
      mk n;

  /*
    Unwrap a port value to its integer number.

    `port`: port value.

    Returns the port number as an integer.
  */
  toInt = port: port.value;

  # ===== Parsing =====

  /*
    Parse a port from its decimal string form without throwing, so
    callers can handle invalid input themselves.

    `input`: decimal string in [0, 65535], without sign or whitespace.

    Returns a tryResult: `{ success = true; value = <port>; }` or
    `{ success = false; error = <message>; }`.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.port.parse: input must be a string"
    else
      let
        number = parsing.decimal input;
      in
      if number == null then
        types.tryErr "libnet.port.parse: not a decimal number: \"${input}\""
      else if number > portMax then
        types.tryErr "libnet.port.parse: out of range [0, 65535]: ${input}"
      else
        types.tryOk (mk number);

  /*
    Parse a port from its decimal string form, for configuration values
    written as text.

    `input`: decimal string in [0, 65535], without sign or whitespace.

    Returns a port value; throws on malformed or out-of-range input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Format a port as its decimal string.

    `port`: port value.

    Returns the decimal string, such as "8080".
  */
  toString = port: builtins.toString port.value;

  # ===== Predicates =====

  /*
    Check whether a string parses as a port.

    `input`: candidate string.

    Returns true when `tryParse input` succeeds.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a port value.

    `value`: any value.

    Returns true when `value` is tagged `_type = "port"`.
  */
  is = value: types.isPort value;

  /*
    Check whether a port is in the RFC 6335 well-known range.

    `port`: port value.

    Returns true for ports 0..1023.
  */
  isWellKnown = port: port.value >= 0 && port.value <= 1023;

  /*
    Check whether a port is in the RFC 6335 registered range.

    `port`: port value.

    Returns true for ports 1024..49151.
  */
  isRegistered = port: port.value >= 1024 && port.value <= 49151;

  /*
    Check whether a port is in the RFC 6335 dynamic (ephemeral) range.

    `port`: port value.

    Returns true for ports 49152..65535.
  */
  isDynamic = port: port.value >= 49152 && port.value <= portMax;

  /*
    Alias of `isDynamic` under the common "ephemeral" name.

    `port`: port value.

    Returns true for ports 49152..65535.
  */
  isEphemeral = port: isDynamic port;

  /*
    Check whether a port is the reserved port 0 (RFC 6335). Port 0 also
    satisfies `isWellKnown`; these classes are not a partition.

    `port`: port value.

    Returns true only for port 0.
  */
  isReserved = port: port.value == 0;

  # ===== Arithmetic =====

  /*
    Offset a port by an integer, parallel to `ipv4.add`.

    `n`: integer offset; may be negative.
    `port`: port value.

    Returns the offset port; throws when the result leaves [0, 65535].
  */
  add =
    n: port:
    let
      result = port.value + n;
    in
    if result < 0 || result > portMax then
      throw "libnet.port.add: result out of range [0, 65535]: ${builtins.toString result}"
    else
      mk result;

  /*
    Offset a port downward by an integer.

    `n`: integer to subtract; may be negative.
    `port`: port value.

    Returns the offset port; throws when the result leaves [0, 65535].
  */
  sub = n: port: add (0 - n) port;

  /*
    Measure the signed distance between two ports.

    `a`: starting port value.
    `b`: ending port value.

    Returns `toInt b - toInt a`.
  */
  diff = a: b: b.value - a.value;

  /*
    Step to the following port.

    `port`: port value.

    Returns the port one higher; throws at 65535.
  */
  next = port: add 1 port;

  /*
    Step to the preceding port.

    `port`: port value.

    Returns the port one lower; throws at 0.
  */
  prev = port: sub 1 port;

  # ===== Comparison =====

  /*
    Test two port values for equality.

    `a`, `b`: port values.

    Returns true when both have the same type tag and number.
  */
  eq = a: b: a._type == b._type && a.value == b.value;

  /*
    Order two ports numerically.

    `a`, `b`: port values.

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
    Test whether one port sorts before another.

    `a`, `b`: port values.

    Returns true when `a < b`.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether one port sorts before or equal to another.

    `a`, `b`: port values.

    Returns true when `a <= b`.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether one port sorts after another.

    `a`, `b`: port values.

    Returns true when `a > b`.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether one port sorts after or equal to another.

    `a`, `b`: port values.

    Returns true when `a >= b`.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lower of two ports.

    `a`, `b`: port values.

    Returns the smaller port; `a` when they are equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the higher of two ports.

    `a`, `b`: port values.

    Returns the larger port; `a` when they are equal.
  */
  max = a: b: if ge a b then a else b;

  # ===== Boundary values (raw ints, not Port values) =====

  wellKnownMax = 1023;
  registeredMax = 49151;
  lowestValue = 0;
  highestValue = portMax;
in
{
  inherit
    add
    compare
    diff
    eq
    fromInt
    ge
    gt
    highestValue
    is
    isDynamic
    isEphemeral
    isRegistered
    isReserved
    isValid
    isWellKnown
    le
    lowestValue
    lt
    max
    min
    next
    parse
    prev
    registeredMax
    sub
    toInt
    toString
    tryParse
    wellKnownMax
    ;
}
