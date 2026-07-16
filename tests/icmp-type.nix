{ harness }:
let
  icmpType = import ../lib/icmp-type.nix;
  inherit (harness) throws;
in
{
  # ===== valid range =====
  isValid-min = {
    expr = icmpType.isValid 0;
    expected = true;
  };
  isValid-typical = {
    expr = icmpType.isValid 8;
    expected = true;
  };
  isValid-mid = {
    expr = icmpType.isValid 128;
    expected = true;
  };
  isValid-max = {
    expr = icmpType.isValid 255;
    expected = true;
  };

  # ===== boundary rejects =====
  isValid-negative = {
    expr = icmpType.isValid (-1);
    expected = false;
  };
  isValid-256 = {
    expr = icmpType.isValid 256;
    expected = false;
  };
  isValid-large = {
    expr = icmpType.isValid 65535;
    expected = false;
  };

  # ===== type rejects =====
  isValid-string = {
    expr = icmpType.isValid "8";
    expected = false;
  };
  isValid-null = {
    expr = icmpType.isValid null;
    expected = false;
  };
  isValid-float = {
    expr = icmpType.isValid 8.5;
    expected = false;
  };
  isValid-bool = {
    expr = icmpType.isValid true;
    expected = false;
  };
  isValid-list = {
    expr = icmpType.isValid [ 8 ];
    expected = false;
  };

  # ===== Constants =====
  lowestValue = {
    expr = icmpType.lowestValue;
    expected = 0;
  };
  highestValue = {
    expr = icmpType.highestValue;
    expected = 255;
  };

  # ===== Tagged value =====
  fromInt-tagged = {
    expr = (icmpType.fromInt 8)._type;
    expected = "icmpType";
  };
  fromInt-value = {
    expr = (icmpType.fromInt 8).value;
    expected = 8;
  };
  fromInt-min = {
    expr = icmpType.toInt (icmpType.fromInt 0);
    expected = 0;
  };
  fromInt-roundtrip = {
    expr = icmpType.toInt (icmpType.fromInt 255);
    expected = 255;
  };
  fromInt-negative-throws = {
    expr = throws (icmpType.fromInt (-1));
    expected = true;
  };
  fromInt-256-throws = {
    expr = throws (icmpType.fromInt 256);
    expected = true;
  };
  toString-renders = {
    expr = icmpType.toString (icmpType.fromInt 8);
    expected = "8";
  };

  # ===== is (structural) =====
  is-tagged = {
    expr = icmpType.is (icmpType.fromInt 8);
    expected = true;
  };
  is-bare-int = {
    expr = icmpType.is 8;
    expected = false;
  };
  is-untagged = {
    expr = icmpType.is { value = 8; };
    expected = false;
  };

  # ===== Comparison helpers =====
  cmp-lt = {
    expr = icmpType.lt (icmpType.fromInt 8) (icmpType.fromInt 128);
    expected = true;
  };
  cmp-le = {
    expr = icmpType.le (icmpType.fromInt 8) (icmpType.fromInt 128);
    expected = true;
  };
  cmp-gt = {
    expr = icmpType.gt (icmpType.fromInt 128) (icmpType.fromInt 8);
    expected = true;
  };
  cmp-ge = {
    expr = icmpType.ge (icmpType.fromInt 128) (icmpType.fromInt 8);
    expected = true;
  };

  # ===== Comparison =====
  eq-same = {
    expr = icmpType.eq (icmpType.fromInt 8) (icmpType.fromInt 8);
    expected = true;
  };
  eq-diff = {
    expr = icmpType.eq (icmpType.fromInt 8) (icmpType.fromInt 128);
    expected = false;
  };
  compare-lt = {
    expr = icmpType.compare (icmpType.fromInt 8) (icmpType.fromInt 128);
    expected = -1;
  };
  compare-gt = {
    expr = icmpType.compare (icmpType.fromInt 128) (icmpType.fromInt 8);
    expected = 1;
  };
  compare-eq = {
    expr = icmpType.compare (icmpType.fromInt 8) (icmpType.fromInt 8);
    expected = 0;
  };
  min-pick = {
    expr = icmpType.toInt (icmpType.min (icmpType.fromInt 128) (icmpType.fromInt 8));
    expected = 8;
  };
  max-pick = {
    expr = icmpType.toInt (icmpType.max (icmpType.fromInt 128) (icmpType.fromInt 8));
    expected = 128;
  };
}
