{ harness }:
let
  vlanId = import ../lib/vlan-id.nix;
  _ = harness; # harness not used directly; tests are all pure predicates.
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
}
