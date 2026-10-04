{ harness }:
let
  icmpType = import ../lib/icmp-type.nix;
  inherit (harness) throws;
in
{
  # ===== valid range =====
  testIsValidMin = {
    expr = icmpType.isValid 0;
    expected = true;
  };
  testIsValidTypical = {
    expr = icmpType.isValid 8;
    expected = true;
  };
  testIsValidMid = {
    expr = icmpType.isValid 128;
    expected = true;
  };
  testIsValidMax = {
    expr = icmpType.isValid 255;
    expected = true;
  };

  # ===== boundary rejects =====
  testIsValidNegative = {
    expr = icmpType.isValid (-1);
    expected = false;
  };
  testIsValid256 = {
    expr = icmpType.isValid 256;
    expected = false;
  };
  testIsValidLarge = {
    expr = icmpType.isValid 65535;
    expected = false;
  };

  # ===== type rejects =====
  testIsValidString = {
    expr = icmpType.isValid "8";
    expected = false;
  };
  testIsValidNull = {
    expr = icmpType.isValid null;
    expected = false;
  };
  testIsValidFloat = {
    expr = icmpType.isValid 8.5;
    expected = false;
  };
  testIsValidBool = {
    expr = icmpType.isValid true;
    expected = false;
  };
  testIsValidList = {
    expr = icmpType.isValid [ 8 ];
    expected = false;
  };

  # ===== Constants =====
  testLowestValue = {
    expr = icmpType.lowestValue;
    expected = 0;
  };
  testHighestValue = {
    expr = icmpType.highestValue;
    expected = 255;
  };

  # ===== Tagged value =====
  testFromIntTagged = {
    expr = (icmpType.fromInt 8)._type;
    expected = "icmpType";
  };
  testFromIntValue = {
    expr = (icmpType.fromInt 8).value;
    expected = 8;
  };
  testFromIntMin = {
    expr = icmpType.toInt (icmpType.fromInt 0);
    expected = 0;
  };
  testFromIntRoundTrip = {
    expr = icmpType.toInt (icmpType.fromInt 255);
    expected = 255;
  };
  testFromIntRejectsNonInts = {
    expr = builtins.all (value: throws (icmpType.fromInt value)) [
      "8"
      8.0
      null
      true
      [ 8 ]
    ];
    expected = true;
  };
  testFromIntNegativeThrows = {
    expr = throws (icmpType.fromInt (-1));
    expected = true;
  };
  testFromInt256Throws = {
    expr = throws (icmpType.fromInt 256);
    expected = true;
  };
  testToStringRenders = {
    expr = icmpType.toString (icmpType.fromInt 8);
    expected = "8";
  };

  # ===== is (structural) =====
  testIsTagged = {
    expr = icmpType.is (icmpType.fromInt 8);
    expected = true;
  };
  testIsBareInt = {
    expr = icmpType.is 8;
    expected = false;
  };
  testIsUntagged = {
    expr = icmpType.is { value = 8; };
    expected = false;
  };
  testIsTagOnly = {
    expr = icmpType.is { _type = "icmpType"; };
    expected = true;
  };
  testIsDoesNotForceValue = {
    expr = icmpType.is {
      _type = "icmpType";
      value = throw "is must only inspect the tag";
    };
    expected = true;
  };
  testEqForeignDoesNotForceValue = {
    expr = icmpType.eq {
      _type = "icmpType";
      value = throw "eq must compare tags before values";
    } { _type = "foreign"; };
    expected = false;
  };

  # Adjacent ICMP type numbers are unrelated messages.
  testArithmeticAbsent = {
    expr = builtins.any (name: builtins.hasAttr name icmpType) [
      "add"
      "sub"
      "diff"
      "next"
      "prev"
    ];
    expected = false;
  };

  # ===== Comparison helpers =====
  testLt = {
    expr = icmpType.lt (icmpType.fromInt 8) (icmpType.fromInt 128);
    expected = true;
  };
  testLe = {
    expr = icmpType.le (icmpType.fromInt 8) (icmpType.fromInt 128);
    expected = true;
  };
  testGt = {
    expr = icmpType.gt (icmpType.fromInt 128) (icmpType.fromInt 8);
    expected = true;
  };
  testGe = {
    expr = icmpType.ge (icmpType.fromInt 128) (icmpType.fromInt 8);
    expected = true;
  };

  # ===== Comparison =====
  testEqSame = {
    expr = icmpType.eq (icmpType.fromInt 8) (icmpType.fromInt 8);
    expected = true;
  };
  testEqDifferent = {
    expr = icmpType.eq (icmpType.fromInt 8) (icmpType.fromInt 128);
    expected = false;
  };
  testCompareLt = {
    expr = icmpType.compare (icmpType.fromInt 8) (icmpType.fromInt 128);
    expected = -1;
  };
  testCompareGt = {
    expr = icmpType.compare (icmpType.fromInt 128) (icmpType.fromInt 8);
    expected = 1;
  };
  testCompareEq = {
    expr = icmpType.compare (icmpType.fromInt 8) (icmpType.fromInt 8);
    expected = 0;
  };
  testMinPick = {
    expr = icmpType.toInt (icmpType.min (icmpType.fromInt 128) (icmpType.fromInt 8));
    expected = 8;
  };
  testMaxPick = {
    expr = icmpType.toInt (icmpType.max (icmpType.fromInt 128) (icmpType.fromInt 8));
    expected = 128;
  };
}
