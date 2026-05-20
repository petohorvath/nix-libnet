{ harness }:
let
  mtu = import ../lib/mtu.nix;
  inherit (harness) throws;
in
{
  # ===== valid range =====
  isValid-min = {
    expr = mtu.isValid 68;
    expected = true;
  };
  isValid-ethernet = {
    expr = mtu.isValid 1500;
    expected = true;
  };
  isValid-ipv6-min = {
    expr = mtu.isValid 1280;
    expected = true;
  };
  isValid-wg-typical = {
    expr = mtu.isValid 1420;
    expected = true;
  };
  isValid-jumbo = {
    expr = mtu.isValid 9000;
    expected = true;
  };
  isValid-loopback = {
    expr = mtu.isValid 65536; # one above max
    expected = false;
  };
  isValid-max = {
    expr = mtu.isValid 65535;
    expected = true;
  };

  # ===== boundary rejects =====
  isValid-below-min = {
    expr = mtu.isValid 67;
    expected = false;
  };
  isValid-tiny = {
    expr = mtu.isValid 5;
    expected = false;
  };
  isValid-zero = {
    expr = mtu.isValid 0;
    expected = false;
  };
  isValid-negative = {
    expr = mtu.isValid (-1);
    expected = false;
  };
  isValid-huge = {
    expr = mtu.isValid 100000;
    expected = false;
  };

  # ===== type rejects =====
  isValid-string = {
    expr = mtu.isValid "1500";
    expected = false;
  };
  isValid-null = {
    expr = mtu.isValid null;
    expected = false;
  };
  isValid-float = {
    expr = mtu.isValid 1500.5;
    expected = false;
  };
  isValid-bool = {
    expr = mtu.isValid true;
    expected = false;
  };
  isValid-list = {
    expr = mtu.isValid [ 1500 ];
    expected = false;
  };

  # ===== Constants =====
  lowestValue = {
    expr = mtu.lowestValue;
    expected = 68;
  };
  highestValue = {
    expr = mtu.highestValue;
    expected = 65535;
  };

  # ===== Tagged value =====
  fromInt-tagged = {
    expr = (mtu.fromInt 1500)._type;
    expected = "mtu";
  };
  fromInt-value = {
    expr = (mtu.fromInt 1500).value;
    expected = 1500;
  };
  fromInt-roundtrip = {
    expr = mtu.toInt (mtu.fromInt 9000);
    expected = 9000;
  };
  fromInt-below-throws = {
    expr = throws (mtu.fromInt 67);
    expected = true;
  };
  fromInt-above-throws = {
    expr = throws (mtu.fromInt 65536);
    expected = true;
  };
  toString-renders = {
    expr = mtu.toString (mtu.fromInt 1500);
    expected = "1500";
  };

  # ===== is (structural) =====
  is-tagged = {
    expr = mtu.is (mtu.fromInt 1500);
    expected = true;
  };
  is-bare-int = {
    expr = mtu.is 1500;
    expected = false;
  };
  is-untagged = {
    expr = mtu.is { value = 1500; };
    expected = false;
  };

  # ===== Comparison =====
  eq-same = {
    expr = mtu.eq (mtu.fromInt 1500) (mtu.fromInt 1500);
    expected = true;
  };
  eq-diff = {
    expr = mtu.eq (mtu.fromInt 1500) (mtu.fromInt 9000);
    expected = false;
  };
  compare-lt = {
    expr = mtu.compare (mtu.fromInt 1280) (mtu.fromInt 1500);
    expected = -1;
  };
  compare-gt = {
    expr = mtu.compare (mtu.fromInt 9000) (mtu.fromInt 1500);
    expected = 1;
  };
  compare-eq = {
    expr = mtu.compare (mtu.fromInt 1500) (mtu.fromInt 1500);
    expected = 0;
  };
  min-pick = {
    expr = mtu.toInt (mtu.min (mtu.fromInt 9000) (mtu.fromInt 1500));
    expected = 1500;
  };
  max-pick = {
    expr = mtu.toInt (mtu.max (mtu.fromInt 9000) (mtu.fromInt 1500));
    expected = 9000;
  };
}
