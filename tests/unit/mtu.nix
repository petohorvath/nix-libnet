{ helpers, libnet, ... }:
let
  inherit (libnet) mtu;
  inherit (helpers) throws;
in
{
  # ===== valid range =====
  testIsValidMin = {
    expr = mtu.isValid "68";
    expected = true;
  };
  testIsValidEthernet = {
    expr = mtu.isValid "1500";
    expected = true;
  };
  testIsValidIpv6Min = {
    expr = mtu.isValid "1280";
    expected = true;
  };
  testIsValidWireGuardTypical = {
    expr = mtu.isValid "1420";
    expected = true;
  };
  testIsValidJumbo = {
    expr = mtu.isValid "9000";
    expected = true;
  };
  testIsValidLoopbackAboveMax = {
    expr = mtu.isValid "65536"; # Linux loopback default, one above max
    expected = false;
  };
  testIsValidMax = {
    expr = mtu.isValid "65535";
    expected = true;
  };

  # ===== boundary rejects =====
  testIsValidBelowMin = {
    expr = mtu.isValid "67";
    expected = false;
  };
  testIsValidTiny = {
    expr = mtu.isValid "5";
    expected = false;
  };
  testIsValidZero = {
    expr = mtu.isValid "0";
    expected = false;
  };
  testIsValidNegative = {
    expr = mtu.isValid "-1";
    expected = false;
  };
  testIsValidHuge = {
    expr = mtu.isValid "100000";
    expected = false;
  };

  # ===== type rejects =====
  testIsValidInt = {
    expr = mtu.isValid 1500;
    expected = false;
  };
  testIsValidNull = {
    expr = mtu.isValid null;
    expected = false;
  };
  testIsValidFloat = {
    expr = mtu.isValid 1500.5;
    expected = false;
  };
  testIsValidBool = {
    expr = mtu.isValid true;
    expected = false;
  };
  testIsValidList = {
    expr = mtu.isValid [ 1500 ];
    expected = false;
  };

  # ===== Parsing =====
  testParseTypical = {
    expr = mtu.parse "1500";
    expected = {
      _type = "mtu";
      value = 1500;
    };
  };
  testParseBounds = {
    expr = map (input: mtu.toInt (mtu.parse input)) [
      "68"
      "65535"
    ];
    expected = [
      68
      65535
    ];
  };
  testParseRoundTrip = {
    expr = mtu.toString (mtu.parse "1500");
    expected = "1500";
  };
  testParseOutOfRangeThrows = {
    expr = builtins.all (input: throws (mtu.parse input)) [
      "67"
      "65536"
    ];
    expected = true;
  };
  testParseRejectsNonDecimal = {
    expr = builtins.all (input: throws (mtu.parse input)) [
      ""
      "-1"
      "+1500"
      " 1500"
      "0x1500"
    ];
    expected = true;
  };
  testParseRejectsLeadingZero = {
    expr = mtu.parse "01500";
    expectedError.msg = "^libnet\\.mtu\\.parse: leading zero in \"01500\"$";
  };
  testParseRejectsInt = {
    expr = mtu.parse 1500;
    expectedError.msg = "^libnet\\.mtu\\.parse: expected string, got int$";
  };
  testTryParseOk = {
    expr = mtu.toInt (mtu.tryParse "1500").value;
    expected = 1500;
  };
  testTryParseOutOfRange = {
    expr = (mtu.tryParse "65536").success;
    expected = false;
  };
  testParsePartialApplication = {
    expr = map (mtu.eq (mtu.parse "1500")) (
      map mtu.parse [
        "1500"
        "9000"
      ]
    );
    expected = [
      true
      false
    ];
  };

  # ===== Constants =====
  testMinValue = {
    expr = mtu.minValue;
    expected = 68;
  };
  testMaxValue = {
    expr = mtu.maxValue;
    expected = 65535;
  };

  # ===== Tagged value =====
  testFromIntTagged = {
    expr = (mtu.fromInt 1500)._type;
    expected = "mtu";
  };
  testFromIntValue = {
    expr = (mtu.fromInt 1500).value;
    expected = 1500;
  };
  testFromIntRoundTrip = {
    expr = mtu.toInt (mtu.fromInt 9000);
    expected = 9000;
  };
  testFromIntMin = {
    expr = mtu.fromInt 68;
    expected = {
      _type = "mtu";
      value = 68;
    };
  };
  testFromIntMax = {
    expr = mtu.toInt (mtu.fromInt 65535);
    expected = 65535;
  };
  testFromIntRejectsNonInts = {
    expr = builtins.all (value: throws (mtu.fromInt value)) [
      "1500"
      1500.0
      null
      true
      [ 1500 ]
    ];
    expected = true;
  };
  testFromIntBelowThrows = {
    expr = mtu.fromInt 67;
    expectedError.msg = "^libnet\\.mtu\\.fromInt: out of range \\[68, 65535\\]: 67$";
  };
  testFromIntAboveThrows = {
    expr = mtu.fromInt 65536;
    expectedError.msg = "^libnet\\.mtu\\.fromInt: out of range \\[68, 65535\\]: 65536$";
  };
  testToStringRenders = {
    expr = mtu.toString (mtu.fromInt 1500);
    expected = "1500";
  };

  # ===== is (structural) =====
  testIsTagged = {
    expr = mtu.is (mtu.fromInt 1500);
    expected = true;
  };
  testIsBareInt = {
    expr = mtu.is 1500;
    expected = false;
  };
  testIsUntagged = {
    expr = mtu.is { value = 1500; };
    expected = false;
  };
  testIsTagOnly = {
    expr = mtu.is { _type = "mtu"; };
    expected = true;
  };
  testIsDoesNotForceValue = {
    expr = mtu.is {
      _type = "mtu";
      value = throw "is must only inspect the tag";
    };
    expected = true;
  };
  testEqForeignDoesNotForceValue = {
    expr = mtu.eq {
      _type = "mtu";
      value = throw "eq must compare tags before values";
    } { _type = "foreign"; };
    expected = false;
  };

  # ===== Arithmetic =====
  testAddOk = {
    expr = mtu.toInt (mtu.add 100 (mtu.fromInt 1400));
    expected = 1500;
  };
  testSubOverhead = {
    expr = mtu.toInt (mtu.sub 80 (mtu.fromInt 1500));
    expected = 1420;
  };
  testAddNegativeToMin = {
    expr = mtu.toInt (mtu.add (-1432) (mtu.fromInt 1500));
    expected = 68;
  };
  testSubNegativeToMax = {
    expr = mtu.toInt (mtu.sub (-64035) (mtu.fromInt 1500));
    expected = 65535;
  };
  testSubFloatThrows = {
    expr = mtu.sub 1.0 (mtu.fromInt 1500);
    expectedError.msg = "^libnet\\.mtu\\.sub: expected int, got float$";
  };
  testNextOk = {
    expr = mtu.toInt (mtu.next (mtu.fromInt 1500));
    expected = 1501;
  };
  testPrevOk = {
    expr = mtu.toInt (mtu.prev (mtu.fromInt 1500));
    expected = 1499;
  };
  testDiffOk = {
    expr = mtu.diff (mtu.fromInt 1500) (mtu.fromInt 9000);
    expected = 7500;
  };
  testDiffNegative = {
    expr = mtu.diff (mtu.fromInt 9000) (mtu.fromInt 1500);
    expected = -7500;
  };
  testDiffZero = {
    expr = mtu.diff (mtu.fromInt 1500) (mtu.fromInt 1500);
    expected = 0;
  };
  testSubBelowFloorThrows = {
    expr = mtu.sub 1 (mtu.fromInt 68);
    expectedError.msg = "^libnet\\.mtu\\.sub: out of range \\[68, 65535\\]: 68 - 1$";
  };
  testAddOverMaxThrows = {
    expr = mtu.add 1 (mtu.fromInt 65535);
    expectedError.msg = "^libnet\\.mtu\\.add: out of range \\[68, 65535\\]: 65535 \\+ 1$";
  };
  testNextAtMaxThrows = {
    expr = mtu.next (mtu.fromInt 65535);
    expectedError.msg = "^libnet\\.mtu\\.next: out of range \\[68, 65535\\]: 65535 \\+ 1$";
  };
  testPrevAtMinThrows = {
    expr = mtu.prev (mtu.fromInt 68);
    expectedError.msg = "^libnet\\.mtu\\.prev: out of range \\[68, 65535\\]: 68 - 1$";
  };

  # ===== Comparison helpers =====
  testLt = {
    expr = mtu.lt (mtu.fromInt 1280) (mtu.fromInt 1500);
    expected = true;
  };
  testLe = {
    expr = mtu.le (mtu.fromInt 1280) (mtu.fromInt 1500);
    expected = true;
  };
  testGt = {
    expr = mtu.gt (mtu.fromInt 1500) (mtu.fromInt 1280);
    expected = true;
  };
  testGe = {
    expr = mtu.ge (mtu.fromInt 1500) (mtu.fromInt 1280);
    expected = true;
  };

  # ===== Comparison =====
  testEqSame = {
    expr = mtu.eq (mtu.fromInt 1500) (mtu.fromInt 1500);
    expected = true;
  };
  testEqDifferent = {
    expr = mtu.eq (mtu.fromInt 1500) (mtu.fromInt 9000);
    expected = false;
  };
  testCompareLt = {
    expr = mtu.compare (mtu.fromInt 1280) (mtu.fromInt 1500);
    expected = -1;
  };
  testCompareGt = {
    expr = mtu.compare (mtu.fromInt 9000) (mtu.fromInt 1500);
    expected = 1;
  };
  testCompareEq = {
    expr = mtu.compare (mtu.fromInt 1500) (mtu.fromInt 1500);
    expected = 0;
  };
  testMinPick = {
    expr = mtu.toInt (mtu.min (mtu.fromInt 9000) (mtu.fromInt 1500));
    expected = 1500;
  };
  testMaxPick = {
    expr = mtu.toInt (mtu.max (mtu.fromInt 9000) (mtu.fromInt 1500));
    expected = 9000;
  };
}
