{ libnet, ... }:
let
  inherit (libnet) port;
  inherit (port) parse;
in
{
  # ===== Parse =====
  testParseZero = {
    expr = port.toInt (parse "0");
    expected = 0;
  };
  testParseOne = {
    expr = port.toInt (parse "1");
    expected = 1;
  };
  testParseHttp = {
    expr = port.toInt (parse "80");
    expected = 80;
  };
  testParseMax = {
    expr = port.toInt (parse "65535");
    expected = 65535;
  };

  testRejectNegative = {
    expr = parse "-1";
    expectedError.msg = "^libnet\\.port\\.parse: not a decimal number: \"-1\"$";
  };
  testRejectPlusSign = {
    expr = parse "+80";
    expectedError.msg = "^libnet\\.port\\.parse: not a decimal number: \"\\+80\"$";
  };
  testRejectAboveMax = {
    expr = parse "65536";
    expectedError.msg = "^libnet\\.port\\.parse: out of range \\[0, 65535\\]: 65536$";
  };
  testRejectHex = {
    expr = parse "0x50";
    expectedError.msg = "^libnet\\.port\\.parse: not a decimal number: \"0x50\"$";
  };
  testRejectEmpty = {
    expr = parse "";
    expectedError.msg = "^libnet\\.port\\.parse: not a decimal number: \"\"$";
  };
  testRejectLeadingWhitespace = {
    expr = parse " 80";
    expectedError.msg = "^libnet\\.port\\.parse: not a decimal number: \" 80\"$";
  };
  testRejectTrailingWhitespace = {
    expr = parse "80 ";
    expectedError.msg = "^libnet\\.port\\.parse: not a decimal number: \"80 \"$";
  };
  testRejectLeadingZero = {
    expr = parse "0080";
    expectedError.msg = "^libnet\\.port\\.parse: leading zero in \"0080\"$";
  };
  testRejectNotString = {
    expr = port.parse 80;
    expectedError.msg = "^libnet\\.port\\.parse: expected string, got int$";
  };

  testTryParseOk = {
    expr = (port.tryParse "80").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (port.tryParse "65536").success;
    expected = false;
  };

  testTryParseErrorNamesParse = {
    expr = (port.tryParse "65536").error;
    expected = "libnet.port.parse: out of range [0, 65535]: 65536";
  };
  testTryParseNonStringError = {
    expr = (port.tryParse { }).error;
    expected = "libnet.port.parse: expected string, got set";
  };
  testTryParseOverlong = {
    expr = (port.tryParse "99999999999999999999").success;
    expected = false;
  };

  # ===== Round-trip =====
  testRoundTripString = {
    expr = port.toString (parse "80");
    expected = "80";
  };
  testRoundTripInt = {
    expr = port.toInt (port.fromInt 80);
    expected = 80;
  };

  testFromIntRejectNegative = {
    expr = port.fromInt (-1);
    expectedError.msg = "^libnet\\.port\\.fromInt: out of range \\[0, 65535\\]: -1$";
  };
  testFromIntRejectAboveMax = {
    expr = port.fromInt 65536;
    expectedError.msg = "^libnet\\.port\\.fromInt: out of range \\[0, 65535\\]: 65536$";
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = port.is (parse "80");
    expected = true;
  };
  testIsRawInt = {
    expr = port.is 80;
    expected = false;
  };
  testIsValidOk = {
    expr = port.isValid "80";
    expected = true;
  };
  testIsValidBad = {
    expr = port.isValid "0x50";
    expected = false;
  };

  testIsWellKnown22 = {
    expr = port.isWellKnown (parse "22");
    expected = true;
  };
  testIsWellKnown1024 = {
    expr = port.isWellKnown (parse "1024");
    expected = false;
  };
  testIsWellKnown0 = {
    # 0 is reserved AND well-known — the classes overlap (not a partition).
    expr = port.isWellKnown (parse "0");
    expected = true;
  };
  testIsRegistered1024 = {
    expr = port.isRegistered (parse "1024");
    expected = true;
  };
  testIsRegistered49152 = {
    expr = port.isRegistered (parse "49152");
    expected = false;
  };
  testIsDynamic49152 = {
    expr = port.isDynamic (parse "49152");
    expected = true;
  };
  testIsDynamic49151 = {
    expr = port.isDynamic (parse "49151");
    expected = false;
  };
  testIsReserved0 = {
    expr = port.isReserved (parse "0");
    expected = true;
  };
  testIsWellKnownRejectsInt = {
    expr = port.isWellKnown 80;
    expectedError.msg = "^libnet\\.port\\.isWellKnown: expected port value, got int$";
  };
  testIsRegisteredRejectsInt = {
    expr = port.isRegistered 1024;
    expectedError.msg = "^libnet\\.port\\.isRegistered: expected port value, got int$";
  };
  testIsDynamicRejectsVlanId = {
    expr = port.isDynamic (libnet.vlanId.fromInt 100);
    expectedError.msg = "^libnet\\.port\\.isDynamic: expected port value, got vlanId value$";
  };
  testIsReservedRejectsNull = {
    expr = port.isReserved null;
    expectedError.msg = "^libnet\\.port\\.isReserved: expected port value, got null$";
  };
  testIsReserved1 = {
    expr = port.isReserved (parse "1");
    expected = false;
  };

  # ===== Arithmetic =====
  testAddOne = {
    expr = port.toInt (port.add 1 (parse "80"));
    expected = 81;
  };
  testSubOne = {
    expr = port.toInt (port.sub 1 (parse "80"));
    expected = 79;
  };
  testDiffPositive = {
    expr = port.diff (parse "80") (parse "90");
    expected = 10;
  };
  testDiffNegative = {
    expr = port.diff (parse "90") (parse "80");
    expected = -10;
  };
  testDiffZero = {
    expr = port.diff (parse "80") (parse "80");
    expected = 0;
  };
  testNextOk = {
    expr = port.toInt (port.next (parse "80"));
    expected = 81;
  };
  testPrevOk = {
    expr = port.toInt (port.prev (parse "80"));
    expected = 79;
  };
  testAddOverflow = {
    expr = port.add 1 (parse "65535");
    expectedError.msg = "^libnet\\.port\\.add: out of range \\[0, 65535\\]: 65535 \\+ 1$";
  };
  testSubUnderflow = {
    expr = port.sub 1 (parse "0");
    expectedError.msg = "^libnet\\.port\\.sub: out of range \\[0, 65535\\]: 0 - 1$";
  };
  testNextAtMaxNamesNext = {
    expr = port.next (parse "65535");
    expectedError.msg = "^libnet\\.port\\.next: out of range \\[0, 65535\\]: 65535 \\+ 1$";
  };
  testPrevAtMinNamesPrev = {
    expr = port.prev (parse "0");
    expectedError.msg = "^libnet\\.port\\.prev: out of range \\[0, 65535\\]: 0 - 1$";
  };
  # Offsets near the integer limits throw before any arithmetic, since the
  # sum would overflow, and Nix 2.18 wraps overflow silently.
  testAddLargestIntegerOffset = {
    expr = port.add 9223372036854775807 (parse "1");
    expectedError.msg = "^libnet\\.port\\.add: out of range \\[0, 65535\\]: 1 \\+ 9223372036854775807$";
  };
  testAddSmallestIntegerOffset = {
    expr = port.add (-9223372036854775807 - 1) (parse "65535");
    expectedError.msg = "^libnet\\.port\\.add: out of range \\[0, 65535\\]: 65535 \\+ -9223372036854775808$";
  };
  testSubLargestIntegerOffset = {
    expr = port.sub 9223372036854775807 (parse "0");
    expectedError.msg = "^libnet\\.port\\.sub: out of range \\[0, 65535\\]: 0 - 9223372036854775807$";
  };
  # Negating this offset would overflow.
  testSubSmallestIntegerOffset = {
    expr = port.sub (-9223372036854775807 - 1) (parse "1");
    expectedError.msg = "^libnet\\.port\\.sub: out of range \\[0, 65535\\]: 1 - -9223372036854775808$";
  };
  testAddToUpperBound = {
    expr = port.toInt (port.add 65535 (parse "0"));
    expected = 65535;
  };
  testSubToLowerBound = {
    expr = port.toInt (port.sub 65535 (parse "65535"));
    expected = 0;
  };

  # ===== Comparison helpers =====
  testLe = {
    expr = port.le (parse "80") (parse "81");
    expected = true;
  };
  testGt = {
    expr = port.gt (parse "81") (parse "80");
    expected = true;
  };
  testGe = {
    expr = port.ge (parse "81") (parse "80");
    expected = true;
  };

  # ===== Comparison =====
  testEqSame = {
    expr = port.eq (parse "80") (parse "80");
    expected = true;
  };
  testEqDifferent = {
    expr = port.eq (parse "80") (parse "81");
    expected = false;
  };
  testLt = {
    expr = port.lt (parse "80") (parse "81");
    expected = true;
  };
  testCompareLt = {
    expr = port.compare (parse "80") (parse "81");
    expected = -1;
  };
  testCompareEq = {
    expr = port.compare (parse "80") (parse "80");
    expected = 0;
  };
  testCompareGt = {
    expr = port.compare (parse "81") (parse "80");
    expected = 1;
  };
  testMinSmaller = {
    expr = port.toInt (port.min (parse "80") (parse "81"));
    expected = 80;
  };
  testMaxLarger = {
    expr = port.toInt (port.max (parse "80") (parse "81"));
    expected = 81;
  };

  # ===== Constants =====
  testMinValue = {
    expr = port.minValue;
    expected = 0;
  };
  testMaxValue = {
    expr = port.maxValue;
    expected = 65535;
  };
  testRemovedConstants = {
    expr = builtins.filter (name: port ? ${name}) [
      "lowestValue"
      "highestValue"
      "wellKnownMax"
      "registeredMax"
    ];
    expected = [ ];
  };
}
