/*
  libnet.mtu

  IP MTU — a tagged int in `[68, 65535]`. 68 is the IPv4 minimum
  forwarding MTU (RFC 791 §3.1, and the floor Linux's `ip link set
  mtu` accepts); 65535 is the IPv4 / IPv6 wire-format maximum (the
  16-bit Total Length field). This is a syntactic floor (the kernel
  will accept it), not a semantic recommendation — real-world MTUs are
  typically in `[1280, 9000]`.

  Tagged like `libnet.port` so a validated MTU is distinguishable from
  a bare int (`is`). There is no string `parse`: MTUs are written as
  integers, so the constructor is `fromInt`. The opt-in module type
  `libnet.types.mtu` validates and returns a bare int (coerced, like
  `types.port`), so NixOS configs stay `mtu = 1500;`.

  Example:
    libnet.mtu.fromInt 1500   # => { _type = "mtu"; value = 1500; }
    libnet.mtu.isValid 9000   # => true   (jumbo frames)
    libnet.mtu.isValid 67     # => false  (below RFC 791 floor)
*/
let
  types = import ./internal/types.nix;

  lowestValue = 68;
  highestValue = 65535;

  mk = v: {
    _type = "mtu";
    value = v;
  };

  # ===== Validation =====
  #
  # Int predicate (not String → Bool like other `isValid`): an MTU has
  # no string form, so this validates a bare int.
  isValid = v: builtins.isInt v && v >= lowestValue && v <= highestValue;

  # ===== Conversion =====

  fromInt =
    n:
    if !(isValid n) then
      builtins.throw "libnet.mtu.fromInt: out of range [${builtins.toString lowestValue}, ${builtins.toString highestValue}]: ${builtins.toString n}"
    else
      mk n;

  toInt = v: v.value;

  toString = v: builtins.toString v.value;

  # ===== Predicates =====

  is = types.isMtu;

  # ===== Arithmetic =====

  add =
    n: v:
    let
      r = v.value + n;
    in
    if !(isValid r) then
      builtins.throw "libnet.mtu.add: result out of range [${builtins.toString lowestValue}, ${builtins.toString highestValue}]: ${builtins.toString r}"
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
