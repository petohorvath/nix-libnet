/*
  libnet.icmpType

  ICMP / ICMPv6 message type — a tagged int in `[0, 255]` (the 8-bit
  Type field, RFC 792 / RFC 4443). One family-agnostic type: v4 and
  v6 share the range, so family correctness is not range-checkable —
  type 3 is destination-unreachable in ICMP but time-exceeded in
  ICMPv6 — exactly like a UDP port in a TCP list. Named constants
  live in `libnet.registry.icmpTypes.{ipv4,ipv6}` (bare ints).

  Tagged like `libnet.port` so a validated ICMP type is
  distinguishable from a bare int (`is`). There is no string `parse`:
  ICMP types are written as integers, so the constructor is
  `fromInt`. The opt-in module type `libnet.types.icmpType` validates
  and returns a bare int (coerced, like `types.port`), so NixOS
  configs stay `icmpv4 = [ 8 ];`.

  Example:
    libnet.icmpType.fromInt 8     # => { _type = "icmpType"; value = 8; }
    libnet.icmpType.isValid 255   # => true   (reserved, but in range)
    libnet.icmpType.isValid 256   # => false  (the Type field is 8 bits)
*/
let
  types = import ./internal/types.nix;

  lowestValue = 0;
  highestValue = 255;

  mk = v: {
    _type = "icmpType";
    value = v;
  };

  # ===== Validation =====
  #
  # Int predicate (not String → Bool like other `isValid`): an ICMP
  # type has no string form, so this validates a bare int.
  isValid = v: builtins.isInt v && v >= lowestValue && v <= highestValue;

  # ===== Conversion =====

  fromInt =
    n:
    if !(isValid n) then
      builtins.throw "libnet.icmpType.fromInt: out of range [${builtins.toString lowestValue}, ${builtins.toString highestValue}]: ${builtins.toString n}"
    else
      mk n;

  toInt = v: v.value;

  toString = v: builtins.toString v.value;

  # ===== Predicates =====

  is = types.isIcmpType;

  # ===== Arithmetic =====
  #
  # None. Adjacent ICMP type numbers are unrelated messages (11 is
  # time-exceeded, 12 parameter-problem), so the `add` / `sub` /
  # `diff` / `next` / `prev` block `vlanId` / `mtu` carry would be
  # meaningless here. Comparison stays: RFC 4443 §2.1 orders ICMPv6
  # types into error (< 128) and informational (>= 128) classes.

  # ===== Comparison =====

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
