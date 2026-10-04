{ harness }:
let
  port = import ../lib/port.nix;
  inherit (harness) throws;
  parse = port.parse;
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
    expr = throws (parse "-1");
    expected = true;
  };
  testRejectPlusSign = {
    expr = throws (parse "+80");
    expected = true;
  };
  testRejectAboveMax = {
    expr = throws (parse "65536");
    expected = true;
  };
  testRejectHex = {
    expr = throws (parse "0x50");
    expected = true;
  };
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectLeadingWhitespace = {
    expr = throws (parse " 80");
    expected = true;
  };
  testRejectTrailingWhitespace = {
    expr = throws (parse "80 ");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (port.parse 80);
    expected = true;
  };

  testTryParseOk = {
    expr = (port.tryParse "80").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (port.tryParse "65536").success;
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
    expr = throws (port.fromInt (-1));
    expected = true;
  };
  testFromIntRejectAboveMax = {
    expr = throws (port.fromInt 65536);
    expected = true;
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
  testIsReserved1 = {
    expr = port.isReserved (parse "1");
    expected = false;
  };
  testIsEphemeralAlias = {
    expr = port.isEphemeral (parse "49152");
    expected = true;
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
    expr = throws (port.add 1 (parse "65535"));
    expected = true;
  };
  testSubUnderflow = {
    expr = throws (port.sub 1 (parse "0"));
    expected = true;
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

  # Boundary-value ints
  testWellKnownMax = {
    expr = port.wellKnownMax;
    expected = 1023;
  };
  testRegisteredMax = {
    expr = port.registeredMax;
    expected = 49151;
  };
  testLowestValue = {
    expr = port.lowestValue;
    expected = 0;
  };
  testHighestValue = {
    expr = port.highestValue;
    expected = 65535;
  };
}
