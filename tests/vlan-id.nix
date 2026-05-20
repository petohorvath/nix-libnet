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
