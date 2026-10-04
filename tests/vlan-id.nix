{ harness }:
let
  vlanId = import ../lib/vlan-id.nix;
  inherit (harness) throws;
in
{
  # ===== valid range =====
  testIsValidMin = {
    expr = vlanId.isValid 1;
    expected = true;
  };
  testIsValidLow = {
    expr = vlanId.isValid 2;
    expected = true;
  };
  testIsValidTypical = {
    expr = vlanId.isValid 100;
    expected = true;
  };
  testIsValidMid = {
    expr = vlanId.isValid 2000;
    expected = true;
  };
  testIsValidMax = {
    expr = vlanId.isValid 4094;
    expected = true;
  };

  # ===== boundary rejects =====
  testIsValidZero = {
    expr = vlanId.isValid 0;
    expected = false;
  };
  testIsValid4095 = {
    expr = vlanId.isValid 4095;
    expected = false;
  };
  testIsValidNegative = {
    expr = vlanId.isValid (-1);
    expected = false;
  };
  testIsValidLarge = {
    expr = vlanId.isValid 65535;
    expected = false;
  };

  # ===== type rejects =====
  testIsValidString = {
    expr = vlanId.isValid "100";
    expected = false;
  };
  testIsValidNull = {
    expr = vlanId.isValid null;
    expected = false;
  };
  testIsValidFloat = {
    expr = vlanId.isValid 100.5;
    expected = false;
  };
  testIsValidBool = {
    expr = vlanId.isValid true;
    expected = false;
  };
  testIsValidList = {
    expr = vlanId.isValid [ 100 ];
    expected = false;
  };

  # ===== Constants =====
  testLowestValue = {
    expr = vlanId.lowestValue;
    expected = 1;
  };
  testHighestValue = {
    expr = vlanId.highestValue;
    expected = 4094;
  };

  # ===== Tagged value =====
  testFromIntTagged = {
    expr = (vlanId.fromInt 100)._type;
    expected = "vlanId";
  };
  testFromIntValue = {
    expr = (vlanId.fromInt 100).value;
    expected = 100;
  };
  testFromIntRoundTrip = {
    expr = vlanId.toInt (vlanId.fromInt 4094);
    expected = 4094;
  };
  testFromIntMin = {
    expr = vlanId.fromInt 1;
    expected = {
      _type = "vlanId";
      value = 1;
    };
  };
  testFromIntRejectsNonInts = {
    expr = builtins.all (value: throws (vlanId.fromInt value)) [
      "100"
      100.0
      null
      true
      [ 100 ]
    ];
    expected = true;
  };
  testFromIntZeroThrows = {
    expr = throws (vlanId.fromInt 0);
    expected = true;
  };
  testFromInt4095Throws = {
    expr = throws (vlanId.fromInt 4095);
    expected = true;
  };
  testToStringRenders = {
    expr = vlanId.toString (vlanId.fromInt 100);
    expected = "100";
  };

  # ===== is (structural) =====
  testIsTagged = {
    expr = vlanId.is (vlanId.fromInt 100);
    expected = true;
  };
  testIsBareInt = {
    expr = vlanId.is 100;
    expected = false;
  };
  testIsUntagged = {
    expr = vlanId.is { value = 100; };
    expected = false;
  };
  testIsTagOnly = {
    expr = vlanId.is { _type = "vlanId"; };
    expected = true;
  };
  testIsDoesNotForceValue = {
    expr = vlanId.is {
      _type = "vlanId";
      value = throw "is must only inspect the tag";
    };
    expected = true;
  };
  testEqForeignDoesNotForceValue = {
    expr = vlanId.eq {
      _type = "vlanId";
      value = throw "eq must compare tags before values";
    } { _type = "foreign"; };
    expected = false;
  };

  # ===== Arithmetic =====
  testAddOk = {
    expr = vlanId.toInt (vlanId.add 5 (vlanId.fromInt 100));
    expected = 105;
  };
  testSubOk = {
    expr = vlanId.toInt (vlanId.sub 5 (vlanId.fromInt 100));
    expected = 95;
  };
  testAddNegativeToMin = {
    expr = vlanId.toInt (vlanId.add (-99) (vlanId.fromInt 100));
    expected = 1;
  };
  testSubNegativeToMax = {
    expr = vlanId.toInt (vlanId.sub (-3994) (vlanId.fromInt 100));
    expected = 4094;
  };
  testAddFloatThrows = {
    expr = throws (vlanId.add 1.0 (vlanId.fromInt 100));
    expected = true;
  };
  testSubBelowMinThrows = {
    expr = throws (vlanId.sub 100 (vlanId.fromInt 100));
    expected = true;
  };
  testNextOk = {
    expr = vlanId.toInt (vlanId.next (vlanId.fromInt 100));
    expected = 101;
  };
  testPrevOk = {
    expr = vlanId.toInt (vlanId.prev (vlanId.fromInt 100));
    expected = 99;
  };
  testDiffOk = {
    expr = vlanId.diff (vlanId.fromInt 100) (vlanId.fromInt 150);
    expected = 50;
  };
  testDiffNegative = {
    expr = vlanId.diff (vlanId.fromInt 150) (vlanId.fromInt 100);
    expected = -50;
  };
  testDiffZero = {
    expr = vlanId.diff (vlanId.fromInt 100) (vlanId.fromInt 100);
    expected = 0;
  };
  testNextAtMaxThrows = {
    expr = throws (vlanId.next (vlanId.fromInt 4094));
    expected = true;
  };
  testPrevAtMinThrows = {
    expr = throws (vlanId.prev (vlanId.fromInt 1));
    expected = true;
  };
  testAddOverThrows = {
    expr = throws (vlanId.add 1 (vlanId.fromInt 4094));
    expected = true;
  };

  # ===== Comparison helpers =====
  testLt = {
    expr = vlanId.lt (vlanId.fromInt 100) (vlanId.fromInt 200);
    expected = true;
  };
  testLe = {
    expr = vlanId.le (vlanId.fromInt 100) (vlanId.fromInt 200);
    expected = true;
  };
  testGt = {
    expr = vlanId.gt (vlanId.fromInt 200) (vlanId.fromInt 100);
    expected = true;
  };
  testGe = {
    expr = vlanId.ge (vlanId.fromInt 200) (vlanId.fromInt 100);
    expected = true;
  };

  # ===== Comparison =====
  testEqSame = {
    expr = vlanId.eq (vlanId.fromInt 100) (vlanId.fromInt 100);
    expected = true;
  };
  testEqDifferent = {
    expr = vlanId.eq (vlanId.fromInt 100) (vlanId.fromInt 200);
    expected = false;
  };
  testCompareLt = {
    expr = vlanId.compare (vlanId.fromInt 100) (vlanId.fromInt 200);
    expected = -1;
  };
  testCompareGt = {
    expr = vlanId.compare (vlanId.fromInt 200) (vlanId.fromInt 100);
    expected = 1;
  };
  testCompareEq = {
    expr = vlanId.compare (vlanId.fromInt 100) (vlanId.fromInt 100);
    expected = 0;
  };
  testMinPick = {
    expr = vlanId.toInt (vlanId.min (vlanId.fromInt 200) (vlanId.fromInt 100));
    expected = 100;
  };
  testMaxPick = {
    expr = vlanId.toInt (vlanId.max (vlanId.fromInt 200) (vlanId.fromInt 100));
    expected = 200;
  };
}
