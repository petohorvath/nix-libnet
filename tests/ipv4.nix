{ harness }:
let
  ipv4 = import ../lib/ipv4.nix;
  inherit (harness) throws;

  parse = ipv4.parse;
in
{
  # ===== Parse: positive =====
  testParseZero = {
    expr = ipv4.toInt (parse "0.0.0.0");
    expected = 0;
  };
  testParseMax = {
    expr = ipv4.toInt (parse "255.255.255.255");
    expected = 4294967295;
  };
  testParseGeneric = {
    expr = ipv4.toInt (parse "1.2.3.4");
    expected = 16909060;
  };
  testParseLoopback = {
    expr = ipv4.toInt (parse "127.0.0.1");
    expected = 2130706433;
  };
  testParseOctetZero = {
    expr = ipv4.toInt (parse "1.0.0.1");
    expected = 16777217;
  };

  # ===== Parse: negative =====
  testParseEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testParse3Octets = {
    expr = throws (parse "1.2.3");
    expected = true;
  };
  testParse5Octets = {
    expr = throws (parse "1.2.3.4.5");
    expected = true;
  };
  testParseOctet256 = {
    expr = throws (parse "1.2.3.256");
    expected = true;
  };
  testParseLeadingZero = {
    expr = throws (parse "01.2.3.4");
    expected = true;
  };
  testParseLeadingZeroSecondOctet = {
    expr = throws (parse "1.02.3.4");
    expected = true;
  };
  testParseNegative = {
    expr = throws (parse "1.2.3.-1");
    expected = true;
  };
  testParseLeadingWhitespace = {
    expr = throws (parse " 1.2.3.4");
    expected = true;
  };
  testParseTrailingWhitespace = {
    expr = throws (parse "1.2.3.4 ");
    expected = true;
  };
  testParseNonDigit = {
    expr = throws (parse "a.b.c.d");
    expected = true;
  };
  testParseHex = {
    expr = throws (parse "0x1.2.3.4");
    expected = true;
  };
  testParseEmptyOctet = {
    expr = throws (parse "1..3.4");
    expected = true;
  };
  testParseNonString = {
    expr = throws (ipv4.parse 123);
    expected = true;
  };

  # ===== tryParse =====
  testTryParseOk = {
    expr = (ipv4.tryParse "1.2.3.4").success;
    expected = true;
  };
  testTryParseFail = {
    expr = (ipv4.tryParse "bad").success;
    expected = false;
  };
  testTryParseErrorMessage = {
    expr = builtins.isString (ipv4.tryParse "bad").error;
    expected = true;
  };
  testTryParseNullValue = {
    expr = (ipv4.tryParse "bad").value == null;
    expected = true;
  };

  # ===== Round-trip =====
  testRoundTripString = {
    expr = ipv4.toString (parse "1.2.3.4");
    expected = "1.2.3.4";
  };
  testRoundTripStringZero = {
    expr = ipv4.toString (parse "0.0.0.0");
    expected = "0.0.0.0";
  };
  testRoundTripStringMax = {
    expr = ipv4.toString (parse "255.255.255.255");
    expected = "255.255.255.255";
  };
  testRoundTripInt = {
    expr = ipv4.toInt (ipv4.fromInt 16909060);
    expected = 16909060;
  };
  testRoundTripOctets = {
    expr = ipv4.toOctets (
      ipv4.fromOctets [
        1
        2
        3
        4
      ]
    );
    expected = [
      1
      2
      3
      4
    ];
  };
  testRoundTripStringThroughOctets = {
    expr = ipv4.toString (ipv4.fromOctets (ipv4.toOctets (parse "10.0.0.1")));
    expected = "10.0.0.1";
  };

  # ===== fromInt / toInt =====
  testFromIntZero = {
    expr = ipv4.toString (ipv4.fromInt 0);
    expected = "0.0.0.0";
  };
  testFromIntMax = {
    expr = ipv4.toString (ipv4.fromInt 4294967295);
    expected = "255.255.255.255";
  };
  testFromIntOverflow = {
    expr = throws (ipv4.fromInt 4294967296);
    expected = true;
  };
  testFromIntNegative = {
    expr = throws (ipv4.fromInt (-1));
    expected = true;
  };
  testFromIntNotInt = {
    expr = throws (ipv4.fromInt "42");
    expected = true;
  };

  # ===== fromOctets / toOctets =====
  testFromOctetsZero = {
    expr = ipv4.toString (
      ipv4.fromOctets [
        0
        0
        0
        0
      ]
    );
    expected = "0.0.0.0";
  };
  testFromOctetsMax = {
    expr = ipv4.toString (
      ipv4.fromOctets [
        255
        255
        255
        255
      ]
    );
    expected = "255.255.255.255";
  };
  testFromOctetsShort = {
    expr = throws (
      ipv4.fromOctets [
        1
        2
        3
      ]
    );
    expected = true;
  };
  testFromOctetsLong = {
    expr = throws (
      ipv4.fromOctets [
        1
        2
        3
        4
        5
      ]
    );
    expected = true;
  };
  testFromOctetsOver255 = {
    expr = throws (
      ipv4.fromOctets [
        1
        2
        3
        256
      ]
    );
    expected = true;
  };
  testFromOctetsNegative = {
    expr = throws (
      ipv4.fromOctets [
        1
        2
        3
        (-1)
      ]
    );
    expected = true;
  };

  # ===== fromBytes / toBytes (aliases) =====
  testFromBytesAlias = {
    expr = ipv4.toString (
      ipv4.fromBytes [
        10
        0
        0
        1
      ]
    );
    expected = "10.0.0.1";
  };
  testToBytesAlias = {
    expr = ipv4.toBytes (parse "10.0.0.1");
    expected = [
      10
      0
      0
      1
    ];
  };

  # ===== toArpa =====
  testArpaSimple = {
    expr = ipv4.toArpa (parse "1.2.3.4");
    expected = "4.3.2.1.in-addr.arpa";
  };
  testArpaZero = {
    expr = ipv4.toArpa (parse "0.0.0.0");
    expected = "0.0.0.0.in-addr.arpa";
  };
  testArpaLoopback = {
    expr = ipv4.toArpa (parse "127.0.0.1");
    expected = "1.0.0.127.in-addr.arpa";
  };

  # ===== Predicates: is / isValid =====
  testIsValidGood = {
    expr = ipv4.isValid "1.2.3.4";
    expected = true;
  };
  testIsValidBad = {
    expr = ipv4.isValid "1.2.3";
    expected = false;
  };
  testIsParsed = {
    expr = ipv4.is (parse "1.2.3.4");
    expected = true;
  };
  testIsString = {
    expr = ipv4.is "1.2.3.4";
    expected = false;
  };
  testIsInt = {
    expr = ipv4.is 123;
    expected = false;
  };
  testIsWrongType = {
    expr = ipv4.is { _type = "ipv6"; };
    expected = false;
  };

  # ===== Predicates: loopback =====
  testLoopbackPositive = {
    expr = ipv4.isLoopback (parse "127.0.0.1");
    expected = true;
  };
  testLoopbackPositiveLow = {
    expr = ipv4.isLoopback (parse "127.0.0.0");
    expected = true;
  };
  testLoopbackPositiveHigh = {
    expr = ipv4.isLoopback (parse "127.255.255.255");
    expected = true;
  };
  testLoopbackNegative = {
    expr = ipv4.isLoopback (parse "128.0.0.1");
    expected = false;
  };
  testLoopbackNegativeLow = {
    expr = ipv4.isLoopback (parse "126.255.255.255");
    expected = false;
  };

  # ===== Predicates: private (RFC 1918) =====
  testPrivate10 = {
    expr = ipv4.isPrivate (parse "10.0.0.1");
    expected = true;
  };
  testPrivate10Last = {
    expr = ipv4.isPrivate (parse "10.255.255.255");
    expected = true;
  };
  testPrivate11Negative = {
    expr = ipv4.isPrivate (parse "11.0.0.1");
    expected = false;
  };
  testPrivate17216 = {
    expr = ipv4.isPrivate (parse "172.16.0.1");
    expected = true;
  };
  testPrivate17231 = {
    expr = ipv4.isPrivate (parse "172.31.255.255");
    expected = true;
  };
  testPrivate17215Negative = {
    expr = ipv4.isPrivate (parse "172.15.255.255");
    expected = false;
  };
  testPrivate17232Negative = {
    expr = ipv4.isPrivate (parse "172.32.0.0");
    expected = false;
  };
  testPrivate192168 = {
    expr = ipv4.isPrivate (parse "192.168.0.1");
    expected = true;
  };
  testPrivate192169Negative = {
    expr = ipv4.isPrivate (parse "192.169.0.0");
    expected = false;
  };
  testPrivatePublicNegative = {
    expr = ipv4.isPrivate (parse "8.8.8.8");
    expected = false;
  };

  # ===== Predicates: linkLocal =====
  testLinkLocalPositive = {
    expr = ipv4.isLinkLocal (parse "169.254.1.1");
    expected = true;
  };
  testLinkLocalPositiveLow = {
    expr = ipv4.isLinkLocal (parse "169.254.0.0");
    expected = true;
  };
  testLinkLocalPositiveHigh = {
    expr = ipv4.isLinkLocal (parse "169.254.255.255");
    expected = true;
  };
  testLinkLocalNegative = {
    expr = ipv4.isLinkLocal (parse "169.253.255.255");
    expected = false;
  };

  # ===== Predicates: multicast =====
  testMulticast224 = {
    expr = ipv4.isMulticast (parse "224.0.0.1");
    expected = true;
  };
  testMulticast239 = {
    expr = ipv4.isMulticast (parse "239.255.255.255");
    expected = true;
  };
  testMulticast223Negative = {
    expr = ipv4.isMulticast (parse "223.255.255.255");
    expected = false;
  };
  testMulticast240Negative = {
    expr = ipv4.isMulticast (parse "240.0.0.0");
    expected = false;
  };

  # ===== Predicates: broadcast / unspecified =====
  testBroadcastPositive = {
    expr = ipv4.isBroadcast (parse "255.255.255.255");
    expected = true;
  };
  testBroadcastNegative = {
    expr = ipv4.isBroadcast (parse "255.255.255.254");
    expected = false;
  };
  testUnspecifiedPositive = {
    expr = ipv4.isUnspecified (parse "0.0.0.0");
    expected = true;
  };
  testUnspecifiedNegative = {
    expr = ipv4.isUnspecified (parse "0.0.0.1");
    expected = false;
  };

  # ===== Predicates: reserved =====
  testReservedPositive = {
    expr = ipv4.isReserved (parse "240.0.0.1");
    expected = true;
  };
  testReservedPositiveLow = {
    expr = ipv4.isReserved (parse "240.0.0.0");
    expected = true;
  };
  testReservedExcludesBroadcast = {
    expr = ipv4.isReserved (parse "255.255.255.255");
    expected = false;
  };
  testReservedNegative = {
    expr = ipv4.isReserved (parse "239.255.255.255");
    expected = false;
  };

  # ===== Predicates: documentation =====
  testDocumentationTestNet1 = {
    expr = ipv4.isDocumentation (parse "192.0.2.1");
    expected = true;
  };
  testDocumentationTestNet2 = {
    expr = ipv4.isDocumentation (parse "198.51.100.5");
    expected = true;
  };
  testDocumentationTestNet3 = {
    expr = ipv4.isDocumentation (parse "203.0.113.10");
    expected = true;
  };
  testDocumentationNegative = {
    expr = ipv4.isDocumentation (parse "192.0.3.1");
    expected = false;
  };

  # ===== Predicates: special-use (RFC 6890) =====
  testThisNetworkPositive = {
    expr = ipv4.isThisNetwork (parse "0.1.2.3");
    expected = true;
  };
  testThisNetworkPositiveZero = {
    expr = ipv4.isThisNetwork (parse "0.0.0.0");
    expected = true;
  };
  testThisNetworkNegative = {
    expr = ipv4.isThisNetwork (parse "1.0.0.0");
    expected = false;
  };
  testSharedPositive = {
    expr = ipv4.isSharedAddressSpace (parse "100.64.0.1");
    expected = true;
  };
  testSharedPositiveHigh = {
    expr = ipv4.isSharedAddressSpace (parse "100.127.255.255");
    expected = true;
  };
  testSharedNegativeBelow = {
    expr = ipv4.isSharedAddressSpace (parse "100.63.255.255");
    expected = false;
  };
  testSharedNegativeAbove = {
    expr = ipv4.isSharedAddressSpace (parse "100.128.0.0");
    expected = false;
  };
  testProtocolPositive = {
    expr = ipv4.isProtocolAssignment (parse "192.0.0.8");
    expected = true;
  };
  testProtocolNegativeAbove = {
    expr = ipv4.isProtocolAssignment (parse "192.0.1.0");
    expected = false;
  };
  testProtocolNegativeDocumentation = {
    expr = ipv4.isProtocolAssignment (parse "192.0.2.1");
    expected = false;
  };
  testBenchmarkingPositive = {
    expr = ipv4.isBenchmarking (parse "198.18.0.1");
    expected = true;
  };
  testBenchmarkingPositiveHigh = {
    expr = ipv4.isBenchmarking (parse "198.19.255.255");
    expected = true;
  };
  testBenchmarkingNegative = {
    expr = ipv4.isBenchmarking (parse "198.20.0.0");
    expected = false;
  };
  testBogonShared = {
    expr = ipv4.isBogon (parse "100.64.0.1");
    expected = true;
  };
  testBogonBenchmarking = {
    expr = ipv4.isBogon (parse "198.18.0.1");
    expected = true;
  };
  testGlobalNegativeShared = {
    expr = ipv4.isGlobal (parse "100.64.0.1");
    expected = false;
  };

  # ===== Predicates: global / bogon =====
  testGlobalPositive = {
    expr = ipv4.isGlobal (parse "8.8.8.8");
    expected = true;
  };
  testGlobalNegativeLoopback = {
    expr = ipv4.isGlobal (parse "127.0.0.1");
    expected = false;
  };
  testGlobalNegativePrivate = {
    expr = ipv4.isGlobal (parse "10.0.0.1");
    expected = false;
  };
  testBogonPositive = {
    expr = ipv4.isBogon (parse "127.0.0.1");
    expected = true;
  };
  testBogonNegative = {
    expr = ipv4.isBogon (parse "8.8.8.8");
    expected = false;
  };
  testBogonDocumentation = {
    expr = ipv4.isBogon (parse "192.0.2.1");
    expected = true;
  };

  # ===== Arithmetic =====
  testAddZero = {
    expr = ipv4.toString (ipv4.add 0 (parse "1.2.3.4"));
    expected = "1.2.3.4";
  };
  testAddOne = {
    expr = ipv4.toString (ipv4.add 1 (parse "1.2.3.4"));
    expected = "1.2.3.5";
  };
  testAddCarry = {
    expr = ipv4.toString (ipv4.add 1 (parse "1.2.3.255"));
    expected = "1.2.4.0";
  };
  testAddBig = {
    expr = ipv4.toString (ipv4.add 256 (parse "0.0.0.0"));
    expected = "0.0.1.0";
  };
  testAddOverflow = {
    expr = throws (ipv4.add 1 (parse "255.255.255.255"));
    expected = true;
  };
  testSubOne = {
    expr = ipv4.toString (ipv4.sub 1 (parse "1.2.3.4"));
    expected = "1.2.3.3";
  };
  testSubBorrow = {
    expr = ipv4.toString (ipv4.sub 1 (parse "1.2.3.0"));
    expected = "1.2.2.255";
  };
  testSubUnderflow = {
    expr = throws (ipv4.sub 1 (parse "0.0.0.0"));
    expected = true;
  };
  testNextOk = {
    expr = ipv4.toString (ipv4.next (parse "1.2.3.4"));
    expected = "1.2.3.5";
  };
  testNextOverflow = {
    expr = throws (ipv4.next (parse "255.255.255.255"));
    expected = true;
  };
  testPrevOk = {
    expr = ipv4.toString (ipv4.prev (parse "1.2.3.4"));
    expected = "1.2.3.3";
  };
  testPrevUnderflow = {
    expr = throws (ipv4.prev (parse "0.0.0.0"));
    expected = true;
  };
  testDiffPositive = {
    expr = ipv4.diff (parse "1.2.3.4") (parse "1.2.3.10");
    expected = 6;
  };
  testDiffNegative = {
    expr = ipv4.diff (parse "1.2.3.10") (parse "1.2.3.4");
    expected = -6;
  };
  testDiffSame = {
    expr = ipv4.diff (parse "1.2.3.4") (parse "1.2.3.4");
    expected = 0;
  };

  # ===== Comparison =====
  testEqSame = {
    expr = ipv4.eq (parse "1.2.3.4") (parse "1.2.3.4");
    expected = true;
  };
  testEqDifferent = {
    expr = ipv4.eq (parse "1.2.3.4") (parse "1.2.3.5");
    expected = false;
  };
  testLtYes = {
    expr = ipv4.lt (parse "1.2.3.4") (parse "1.2.3.5");
    expected = true;
  };
  testLtNo = {
    expr = ipv4.lt (parse "1.2.3.5") (parse "1.2.3.4");
    expected = false;
  };
  testLtEqual = {
    expr = ipv4.lt (parse "1.2.3.4") (parse "1.2.3.4");
    expected = false;
  };
  testLeEqual = {
    expr = ipv4.le (parse "1.2.3.4") (parse "1.2.3.4");
    expected = true;
  };
  testGtYes = {
    expr = ipv4.gt (parse "1.2.3.5") (parse "1.2.3.4");
    expected = true;
  };
  testGeEqual = {
    expr = ipv4.ge (parse "1.2.3.4") (parse "1.2.3.4");
    expected = true;
  };
  testCompareLess = {
    expr = ipv4.compare (parse "1.0.0.0") (parse "2.0.0.0");
    expected = -1;
  };
  testCompareEqual = {
    expr = ipv4.compare (parse "1.0.0.0") (parse "1.0.0.0");
    expected = 0;
  };
  testCompareGreater = {
    expr = ipv4.compare (parse "2.0.0.0") (parse "1.0.0.0");
    expected = 1;
  };
  testMinFirstLower = {
    expr = ipv4.toString (ipv4.min (parse "1.0.0.0") (parse "2.0.0.0"));
    expected = "1.0.0.0";
  };
  testMinSecondLower = {
    expr = ipv4.toString (ipv4.min (parse "2.0.0.0") (parse "1.0.0.0"));
    expected = "1.0.0.0";
  };
  testMaxSecondHigher = {
    expr = ipv4.toString (ipv4.max (parse "1.0.0.0") (parse "2.0.0.0"));
    expected = "2.0.0.0";
  };

  # ===== Constants =====
  testConstantUnspecified = {
    expr = ipv4.toString ipv4.unspecified;
    expected = "0.0.0.0";
  };
  testConstantBroadcast = {
    expr = ipv4.toString ipv4.broadcast;
    expected = "255.255.255.255";
  };
  testConstantLoopback = {
    expr = ipv4.toString ipv4.loopback;
    expected = "127.0.0.1";
  };

  # ===== Curry partial application =====
  testCurriedAdd = {
    expr = map (ipv4.toString) (
      map (ipv4.add 1) [
        (parse "1.0.0.0")
        (parse "2.0.0.0")
        (parse "3.0.0.0")
      ]
    );
    expected = [
      "1.0.0.1"
      "2.0.0.1"
      "3.0.0.1"
    ];
  };
}
