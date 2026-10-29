{ helpers, libnet, ... }:
let
  inherit (libnet) ipv4;
  inherit (helpers) throws;

  inherit (ipv4) parse;
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
    expr = parse "";
    expectedError.msg = "^libnet\\.ipv4\\.parse: must have 4 octets, got 1: \"\"$";
  };
  testParse3Octets = {
    expr = parse "1.2.3";
    expectedError.msg = "^libnet\\.ipv4\\.parse: must have 4 octets, got 3: \"1\\.2\\.3\"$";
  };
  testParse5Octets = {
    expr = parse "1.2.3.4.5";
    expectedError.msg = "^libnet\\.ipv4\\.parse: must have 4 octets, got 5: \"1\\.2\\.3\\.4\\.5\"$";
  };
  testParseOctet256 = {
    expr = parse "1.2.3.256";
    expectedError.msg = "^libnet\\.ipv4\\.parse: invalid octet in \"1\\.2\\.3\\.256\"$";
  };
  testParseLeadingZero = {
    expr = parse "01.2.3.4";
    expectedError.msg = "^libnet\\.ipv4\\.parse: invalid octet in \"01\\.2\\.3\\.4\"$";
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
    expr = ipv4.parse 123;
    expectedError.msg = "^libnet\\.ipv4\\.parse: expected string, got int$";
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
  testTryParseErrorNamesParse = {
    expr = (ipv4.tryParse "1.2.3").error;
    expected = "libnet.ipv4.parse: must have 4 octets, got 3: \"1.2.3\"";
  };
  testTryParseNonStringError = {
    expr = (ipv4.tryParse { }).error;
    expected = "libnet.ipv4.parse: expected string, got set";
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
  testRoundTripBytes = {
    expr = ipv4.toBytes (
      ipv4.fromBytes [
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
  testRoundTripStringThroughBytes = {
    expr = ipv4.toString (ipv4.fromBytes (ipv4.toBytes (parse "10.0.0.1")));
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
    expr = ipv4.fromInt 4294967296;
    expectedError.msg = "^libnet\\.ipv4\\.fromInt: out of range \\[0, 4294967295\\]: 4294967296$";
  };
  testFromIntNegative = {
    expr = ipv4.fromInt (-1);
    expectedError.msg = "^libnet\\.ipv4\\.fromInt: out of range \\[0, 4294967295\\]: -1$";
  };
  testFromIntNotInt = {
    expr = ipv4.fromInt "42";
    expectedError.msg = "^libnet\\.ipv4\\.fromInt: expected int, got string$";
  };

  # ===== fromBytes / toBytes =====
  testFromBytesZero = {
    expr = ipv4.toString (
      ipv4.fromBytes [
        0
        0
        0
        0
      ]
    );
    expected = "0.0.0.0";
  };
  testFromBytesMax = {
    expr = ipv4.toString (
      ipv4.fromBytes [
        255
        255
        255
        255
      ]
    );
    expected = "255.255.255.255";
  };
  testFromBytesShort = {
    expr = ipv4.fromBytes [
      1
      2
      3
    ];
    expectedError.msg = "^libnet\\.ipv4\\.fromBytes: expected 4 bytes, got 3$";
  };
  testFromBytesLong = {
    expr = ipv4.fromBytes [
      1
      2
      3
      4
      5
    ];
    expectedError.msg = "^libnet\\.ipv4\\.fromBytes: expected 4 bytes, got 5$";
  };
  testFromBytesOver255 = {
    expr = ipv4.fromBytes [
      1
      2
      3
      256
    ];
    expectedError.msg = "^libnet\\.ipv4\\.fromBytes: byte out of range \\[0, 255\\]: 256$";
  };
  testFromBytesNegative = {
    expr = ipv4.fromBytes [
      1
      2
      3
      (-1)
    ];
    expectedError.msg = "^libnet\\.ipv4\\.fromBytes: byte out of range \\[0, 255\\]: -1$";
  };
  testFromBytesRejectsFloatByte = {
    expr = ipv4.fromBytes [
      1
      2
      3
      4.0
    ];
    expectedError.msg = "^libnet\\.ipv4\\.fromBytes: expected int byte, got float$";
  };
  testFromBytesRejectsSet = {
    expr = ipv4.fromBytes { };
    expectedError.msg = "^libnet\\.ipv4\\.fromBytes: expected list, got set$";
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

  testIsGlobalNamesIsGlobal = {
    expr = ipv4.isGlobal "8.8.8.8";
    expectedError.msg = "^libnet\\.ipv4\\.isGlobal: expected ipv4 value, got string$";
  };
  testToBytesRejectsInt = {
    expr = ipv4.toBytes 16909060;
    expectedError.msg = "^libnet\\.ipv4\\.toBytes: expected ipv4 value, got int$";
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
    expr = ipv4.add 1 (parse "255.255.255.255");
    expectedError.msg = "^libnet\\.ipv4\\.add: out of range: 255\\.255\\.255\\.255 \\+ 1$";
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
    expr = ipv4.sub 1 (parse "0.0.0.0");
    expectedError.msg = "^libnet\\.ipv4\\.sub: out of range: 0\\.0\\.0\\.0 - 1$";
  };
  testNextOk = {
    expr = ipv4.toString (ipv4.next (parse "1.2.3.4"));
    expected = "1.2.3.5";
  };
  testNextOverflow = {
    expr = ipv4.next (parse "255.255.255.255");
    expectedError.msg = "^libnet\\.ipv4\\.next: out of range: 255\\.255\\.255\\.255 \\+ 1$";
  };
  testPrevOk = {
    expr = ipv4.toString (ipv4.prev (parse "1.2.3.4"));
    expected = "1.2.3.3";
  };
  testPrevUnderflow = {
    expr = ipv4.prev (parse "0.0.0.0");
    expectedError.msg = "^libnet\\.ipv4\\.prev: out of range: 0\\.0\\.0\\.0 - 1$";
  };
  testAddToUpperBound = {
    expr = ipv4.toString (ipv4.add 4294967295 (parse "0.0.0.0"));
    expected = "255.255.255.255";
  };
  testSubToLowerBound = {
    expr = ipv4.toString (ipv4.sub 4294967295 (parse "255.255.255.255"));
    expected = "0.0.0.0";
  };
  testAddNegativeOffset = {
    expr = ipv4.toString (ipv4.add (-1) (parse "1.2.3.4"));
    expected = "1.2.3.3";
  };
  testSubNegativeOffset = {
    expr = ipv4.toString (ipv4.sub (-1) (parse "1.2.3.4"));
    expected = "1.2.3.5";
  };
  testAddRejectsFloatOffset = {
    expr = ipv4.add 1.5 (parse "1.2.3.4");
    expectedError.msg = "^libnet\\.ipv4\\.add: expected int, got float$";
  };
  # Offsets near the integer limits throw before any arithmetic, since the
  # sum would overflow, and Nix 2.18 wraps overflow silently.
  testAddLargestIntegerOffset = {
    expr = ipv4.add 9223372036854775807 (parse "0.0.0.1");
    expectedError.msg = "^libnet\\.ipv4\\.add: out of range: 0\\.0\\.0\\.1 \\+ 9223372036854775807$";
  };
  testAddSmallestIntegerOffset = {
    expr = ipv4.add (-9223372036854775807 - 1) (parse "255.255.255.255");
    expectedError.msg = "^libnet\\.ipv4\\.add: out of range: 255\\.255\\.255\\.255 \\+ -9223372036854775808$";
  };
  testSubLargestIntegerOffset = {
    expr = ipv4.sub 9223372036854775807 (parse "255.255.255.255");
    expectedError.msg = "^libnet\\.ipv4\\.sub: out of range: 255\\.255\\.255\\.255 - 9223372036854775807$";
  };
  # Negating this offset would overflow.
  testSubSmallestIntegerOffset = {
    expr = ipv4.sub (-9223372036854775807 - 1) (parse "0.0.0.1");
    expectedError.msg = "^libnet\\.ipv4\\.sub: out of range: 0\\.0\\.0\\.1 - -9223372036854775808$";
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
  # A single-family namespace orders only its own family; `ip` orders
  # IPv4 before IPv6.
  testCompareRejectsIpv6 = {
    expr = ipv4.compare (parse "1.2.3.4") (libnet.ipv6.parse "::1");
    expectedError.msg = "^libnet\\.ipv4\\.compare: expected ipv4 value, got ipv6 value$";
  };
  testLtRejectsIpv6 = {
    expr = ipv4.lt (libnet.ipv6.parse "::1") (parse "1.2.3.4");
    expectedError.msg = "^libnet\\.ipv4\\.lt: expected ipv4 value, got ipv6 value$";
  };
  testMaxRejectsIpv6 = {
    expr = ipv4.max (parse "1.2.3.4") (libnet.ipv6.parse "::1");
    expectedError.msg = "^libnet\\.ipv4\\.max: expected ipv4 value, got ipv6 value$";
  };
  testEqIpv6IsFalse = {
    expr = ipv4.eq (parse "0.0.0.1") (libnet.ipv6.parse "::1");
    expected = false;
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
    expr = map ipv4.toString (
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
