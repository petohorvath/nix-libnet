/*
  libnet.vlanId

  IEEE 802.1Q VLAN ID — a tagged int in `[1, 4094]`. The 12-bit VLAN
  tag has 4096 values, of which only 1..4094 are usable: 0 is the
  priority-tagged / untagged sentinel and 4095 is reserved.

  Tagged like `libnet.port` so a validated VLAN ID is distinguishable
  from a bare int (`is`). There is no string `parse`: VLAN IDs are
  written as integers, so the constructor is `fromInt`. The opt-in
  module type `libnet.types.vlanId` validates and returns a bare int
  (coerced, like `types.port`), so NixOS configs stay `vlanId = 100;`.

  Example:
    libnet.vlanId.fromInt 100   # => { _type = "vlanId"; value = 100; }
    libnet.vlanId.isValid 0     # => false  (priority-tagged sentinel)
    libnet.vlanId.isValid 4095  # => false  (reserved)
*/
let
  types = import ./internal/types.nix;

  lowestValue = 1;
  highestValue = 4094;

  mk = v: {
    _type = "vlanId";
    value = v;
  };

  # ===== Validation =====
  #
  # Int predicate (not String → Bool like other `isValid`): a VLAN ID
  # has no string form, so this validates a bare int.
  isValid = v: builtins.isInt v && v >= lowestValue && v <= highestValue;

  # ===== Conversion =====

  fromInt =
    n:
    if !(isValid n) then
      builtins.throw "libnet.vlanId.fromInt: out of range [${builtins.toString lowestValue}, ${builtins.toString highestValue}]: ${builtins.toString n}"
    else
      mk n;

  toInt = v: v.value;

  toString = v: builtins.toString v.value;

  # ===== Predicates =====

  is = types.isVlanId;

  # ===== Arithmetic =====

  add =
    n: v:
    let
      r = v.value + n;
    in
    if !(isValid r) then
      builtins.throw "libnet.vlanId.add: result out of range [${builtins.toString lowestValue}, ${builtins.toString highestValue}]: ${builtins.toString r}"
    else
      mk r;

  sub = n: v: add (0 - n) v;
  diff = a: b: b.value - a.value;
  next = add 1;
  prev = sub 1;

  # ===== Comparison =====

  eq = a: b: a.value == b.value;

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
in
{
  inherit
    fromInt
    toInt
    toString
    ;
  inherit
    isValid
    is
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
  inherit lowestValue highestValue;
}
