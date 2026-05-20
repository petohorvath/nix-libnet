{ harness }:
let
  vlanId = import ../lib/vlan-id.nix;
  inherit (harness) throws;
in
{
  # ===== valid range =====
  isValid-min = {
    expr = vlanId.isValid 1;
    expected = true;
  };
  isValid-low = {
    expr = vlanId.isValid 2;
    expected = true;
  };
  isValid-typical = {
    expr = vlanId.isValid 100;
    expected = true;
  };
  isValid-mid = {
    expr = vlanId.isValid 2000;
    expected = true;
  };
  isValid-max = {
    expr = vlanId.isValid 4094;
    expected = true;
  };

  # ===== boundary rejects =====
  isValid-zero = {
    expr = vlanId.isValid 0;
    expected = false;
  };
  isValid-4095 = {
    expr = vlanId.isValid 4095;
    expected = false;
  };
  isValid-negative = {
    expr = vlanId.isValid (-1);
    expected = false;
  };
  isValid-large = {
    expr = vlanId.isValid 65535;
    expected = false;
  };

  # ===== type rejects =====
  isValid-string = {
    expr = vlanId.isValid "100";
    expected = false;
  };
  isValid-null = {
    expr = vlanId.isValid null;
    expected = false;
  };
  isValid-float = {
    expr = vlanId.isValid 100.5;
    expected = false;
  };
  isValid-bool = {
    expr = vlanId.isValid true;
    expected = false;
  };
  isValid-list = {
    expr = vlanId.isValid [ 100 ];
    expected = false;
  };

  # ===== Constants =====
  lowestValue = {
    expr = vlanId.lowestValue;
    expected = 1;
  };
  highestValue = {
    expr = vlanId.highestValue;
    expected = 4094;
  };

  # ===== Tagged value =====
  fromInt-tagged = {
    expr = (vlanId.fromInt 100)._type;
    expected = "vlanId";
  };
  fromInt-value = {
    expr = (vlanId.fromInt 100).value;
    expected = 100;
  };
  fromInt-roundtrip = {
    expr = vlanId.toInt (vlanId.fromInt 4094);
    expected = 4094;
  };
  fromInt-zero-throws = {
    expr = throws (vlanId.fromInt 0);
    expected = true;
  };
  fromInt-4095-throws = {
    expr = throws (vlanId.fromInt 4095);
    expected = true;
  };
  toString-renders = {
    expr = vlanId.toString (vlanId.fromInt 100);
    expected = "100";
  };

  # ===== is (structural) =====
  is-tagged = {
    expr = vlanId.is (vlanId.fromInt 100);
    expected = true;
  };
  is-bare-int = {
    expr = vlanId.is 100;
    expected = false;
  };
  is-untagged = {
    expr = vlanId.is { value = 100; };
    expected = false;
  };

  # ===== Arithmetic =====
  add-ok = {
    expr = vlanId.toInt (vlanId.add 5 (vlanId.fromInt 100));
    expected = 105;
  };
  sub-ok = {
    expr = vlanId.toInt (vlanId.sub 5 (vlanId.fromInt 100));
    expected = 95;
  };
  next-ok = {
    expr = vlanId.toInt (vlanId.next (vlanId.fromInt 100));
    expected = 101;
  };
  prev-ok = {
    expr = vlanId.toInt (vlanId.prev (vlanId.fromInt 100));
    expected = 99;
  };
  diff-ok = {
    expr = vlanId.diff (vlanId.fromInt 100) (vlanId.fromInt 150);
    expected = 50;
  };
  next-at-max-throws = {
    expr = throws (vlanId.next (vlanId.fromInt 4094));
    expected = true;
  };
  prev-at-min-throws = {
    expr = throws (vlanId.prev (vlanId.fromInt 1));
    expected = true;
  };
  add-over-throws = {
    expr = throws (vlanId.add 1 (vlanId.fromInt 4094));
    expected = true;
  };

  # ===== Comparison helpers =====
  cmp-lt = {
    expr = vlanId.lt (vlanId.fromInt 100) (vlanId.fromInt 200);
    expected = true;
  };
  cmp-le = {
    expr = vlanId.le (vlanId.fromInt 100) (vlanId.fromInt 200);
    expected = true;
  };
  cmp-gt = {
    expr = vlanId.gt (vlanId.fromInt 200) (vlanId.fromInt 100);
    expected = true;
  };
  cmp-ge = {
    expr = vlanId.ge (vlanId.fromInt 200) (vlanId.fromInt 100);
    expected = true;
  };

  # ===== Comparison =====
  eq-same = {
    expr = vlanId.eq (vlanId.fromInt 100) (vlanId.fromInt 100);
    expected = true;
  };
  eq-diff = {
    expr = vlanId.eq (vlanId.fromInt 100) (vlanId.fromInt 200);
    expected = false;
  };
  compare-lt = {
    expr = vlanId.compare (vlanId.fromInt 100) (vlanId.fromInt 200);
    expected = -1;
  };
  compare-gt = {
    expr = vlanId.compare (vlanId.fromInt 200) (vlanId.fromInt 100);
    expected = 1;
  };
  compare-eq = {
    expr = vlanId.compare (vlanId.fromInt 100) (vlanId.fromInt 100);
    expected = 0;
  };
  min-pick = {
    expr = vlanId.toInt (vlanId.min (vlanId.fromInt 200) (vlanId.fromInt 100));
    expected = 100;
  };
  max-pick = {
    expr = vlanId.toInt (vlanId.max (vlanId.fromInt 200) (vlanId.fromInt 100));
    expected = 200;
  };
}
