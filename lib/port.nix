let
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  portMax = 65535;

  mk = v: {
    _type = "port";
    value = v;
  };

  # ===== Conversion =====

  fromInt =
    n:
    if !(builtins.isInt n) || n < 0 || n > portMax then
      builtins.throw "libnet.port.fromInt: out of range [0, 65535]: ${builtins.toString n}"
    else
      mk n;

  toInt = pt: pt.value;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.port.parse: input must be a string"
    else
      let
        n = parse'.decimal s;
      in
      if n == null then
        types.tryErr "libnet.port.parse: not a decimal number: \"${s}\""
      else if n > portMax then
        types.tryErr "libnet.port.parse: out of range [0, 65535]: ${s}"
      else
        types.tryOk (mk n);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString = pt: builtins.toString pt.value;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isPort;

  isWellKnown = pt: pt.value >= 0 && pt.value <= 1023;
  isRegistered = pt: pt.value >= 1024 && pt.value <= 49151;
  isDynamic = pt: pt.value >= 49152 && pt.value <= portMax;
  isEphemeral = isDynamic;
  isReserved = pt: pt.value == 0;

  # ===== Arithmetic =====

  add =
    n: pt:
    let
      r = pt.value + n;
    in
    if r < 0 || r > portMax then builtins.throw "libnet.port.add: result out of range" else mk r;

  sub = n: pt: add (0 - n) pt;
  diff = a: b: b.value - a.value;
  next = add 1;
  prev = sub 1;

  # ===== Comparison =====

  eq = a: b: a.value == b.value;
  lt = a: b: a.value < b.value;
  le = a: b: a.value <= b.value;
  gt = a: b: a.value > b.value;
  ge = a: b: a.value >= b.value;

  compare =
    a: b:
    if a.value < b.value then
      -1
    else if a.value > b.value then
      1
    else
      0;

  min = a: b: if a.value <= b.value then a else b;
  max = a: b: if a.value >= b.value then a else b;

  # ===== Boundary values (raw ints, not Port values) =====

  wellKnownMax = 1023;
  registeredMax = 49151;
  lowestValue = 0;
  highestValue = portMax;
in
{
  inherit
    fromInt
    toInt
    parse
    tryParse
    toString
    ;
  inherit
    isValid
    is
    isWellKnown
    isRegistered
    isDynamic
    isEphemeral
    isReserved
    ;
  inherit
    add
    sub
    diff
    next
    prev
    ;
  inherit
    eq
    lt
    le
    gt
    ge
    compare
    min
    max
    ;
  inherit
    wellKnownMax
    registeredMax
    lowestValue
    highestValue
    ;
}
