/*
  Shared implementation for int-only scalar modules. Each domain supplies
  its tag and inclusive bounds; arithmetic is opt-in because it does not
  describe meaningful operations on ICMP message types.

  Keep validation separate from tag inspection: `is` recognizes a tag
  without forcing the payload, while `isValid` checks a bare integer.
*/
{
  typeName,
  lowestValue,
  highestValue,
  arithmetic ? false,
}:
let
  types = import ./types.nix;
  range = "[${builtins.toString lowestValue}, ${builtins.toString highestValue}]";

  mk = value: {
    _type = typeName;
    inherit value;
  };

  isValid = v: builtins.isInt v && v >= lowestValue && v <= highestValue;
  is = types.hasTag typeName;

  fromInt =
    n:
    if !(isValid n) then
      builtins.throw "libnet.${typeName}.fromInt: out of range ${range}: ${builtins.toString n}"
    else
      mk n;

  toInt = v: v.value;
  toString = v: builtins.toString v.value;

  eq = a: b: a._type == b._type && a.value == b.value;

  compare =
    a: b:
    if a.value < b.value then
      -1
    else if a.value > b.value then
      1
    else
      0;

  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;

  add =
    n: v:
    let
      r = v.value + n;
    in
    if !(isValid r) then
      builtins.throw "libnet.${typeName}.add: result out of range ${range}: ${builtins.toString r}"
    else
      mk r;

  sub = n: v: add (0 - n) v;
  # All scalar modules define diff as the second argument minus the first.
  diff = a: b: b.value - a.value;
  next = add 1;
  prev = sub 1;
in
{
  inherit
    fromInt
    toInt
    toString
    isValid
    is
    eq
    lt
    le
    gt
    ge
    compare
    min
    max
    lowestValue
    highestValue
    ;
}
// (
  if arithmetic then
    {
      inherit
        add
        sub
        diff
        next
        prev
        ;
    }
  else
    { }
)
