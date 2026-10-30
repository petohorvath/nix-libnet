{ libnet, ... }:
let
  inherit (libnet) ipv4 ipv6 mac;

  inherit (ipv6) parse;

  # Globally reachable allocations inside 2001::/23 (IANA, 2025-10-09),
  # with the edges of each block.
  reachableInProtocolBlock = [
    "2001:1::1"
    "2001:1::2"
    "2001:1::3"
    "2001:3::"
    "2001:3:ffff:ffff:ffff:ffff:ffff:ffff"
    "2001:4:112::"
    "2001:4:112:ffff:ffff:ffff:ffff:ffff"
    "2001:20::"
    "2001:20::1"
    "2001:2f:ffff:ffff:ffff:ffff:ffff:ffff"
    "2001:30::"
    "2001:3f:ffff:ffff:ffff:ffff:ffff:ffff"
  ];
in
{
  # ===== Parse: positive (compression) =====
  testParseAllZero = {
    expr = ipv6.toWords (parse "::");
    expected = [
      0
      0
      0
      0
    ];
  };
  testParseLoopback = {
    expr = ipv6.toWords (parse "::1");
    expected = [
      0
      0
      0
      1
    ];
  };
  testParseTrailingCompression = {
    expr = ipv6.toWords (parse "1::");
    expected = [
      65536
      0
      0
      0
    ];
  };
  testParseCompressionBetweenSingleGroups = {
    expr = ipv6.toWords (parse "1::2");
    expected = [
      65536
      0
      0
      2
    ];
  };
  testParseMiddleCompression = {
    expr = ipv6.toWords (parse "1:2::3:4");
    expected = [
      65538
      0
      0
      196612
    ];
  };
  testParseDocumentation = {
    expr = ipv6.toWords (parse "2001:db8::1");
    expected = [
      536939960
      0
      0
      1
    ];
  };
  testParseFullExpanded = {
    expr = ipv6.toWords (parse "2001:0db8:0000:0000:0000:0000:0000:0001");
    expected = [
      536939960
      0
      0
      1
    ];
  };

  # ===== Parse: uncompressed =====
  testParseAllExplicit = {
    expr = ipv6.toWords (parse "1:2:3:4:5:6:7:8");
    expected = [
      65538
      196612
      327686
      458760
    ];
  };

  # ===== Parse: IPv4-mapped / compatible =====
  # 0xffff is 65535 and 1.2.3.4 is 1*2^24 + 2*2^16 + 3*2^8 + 4 = 16909060.
  testParseV4Mapped = {
    expr = ipv6.toWords (parse "::ffff:1.2.3.4");
    expected = [
      0
      0
      65535
      16909060
    ];
  };
  # ::1.2.3.4 (IPv4-compatible, deprecated)
  testParseV4Compatible = {
    expr = ipv6.toWords (parse "::1.2.3.4");
    expected = [
      0
      0
      0
      16909060
    ];
  };
  testParseFullV4Embedded = {
    expr = ipv6.toWords (parse "1:2:3:4:5:6:1.2.3.4");
    expected = [
      65538
      196612
      327686
      16909060
    ];
  };

  # ===== Parse: case insensitive =====
  testParseUppercase = {
    expr = ipv6.toWords (parse "2001:DB8::1");
    expected = [
      536939960
      0
      0
      1
    ];
  };
  testParseMixedCase = {
    expr = ipv6.toWords (parse "2001:Db8::AbCd");
    expected = [
      536939960
      0
      0
      43981
    ];
  };

  # ===== Parse: negative =====
  testRejectEmpty = {
    expr = parse "";
    expectedError.msg = "^libnet\\.ipv6\\.parse: empty string$";
  };
  testRejectTripleColon = {
    expr = parse ":::";
    expectedError.msg = "^libnet\\.ipv6\\.parse: empty group in \":::\"$";
  };
  testRejectTrailingColon = {
    expr = parse "1:2:3:4:5:6:7:";
    expectedError.msg = "^libnet\\.ipv6\\.parse: empty group in \"1:2:3:4:5:6:7:\"$";
  };
  testRejectLeadingColon = {
    expr = parse ":1::";
    expectedError.msg = "^libnet\\.ipv6\\.parse: empty group in \":1::\"$";
  };
  testRejectTwoCompressions = {
    expr = parse "::1::";
    expectedError.msg = "^libnet\\.ipv6\\.parse: more than one \"::\" in \"::1::\"$";
  };
  testRejectNineGroups = {
    expr = parse "1:2:3:4:5:6:7:8:9";
    expectedError.msg = "^libnet\\.ipv6\\.parse: must have 8 groups, got 9: \"1:2:3:4:5:6:7:8:9\"$";
  };
  testRejectSevenGroups = {
    expr = parse "1:2:3:4:5:6:7";
    expectedError.msg = "^libnet\\.ipv6\\.parse: must have 8 groups, got 7: \"1:2:3:4:5:6:7\"$";
  };
  # The IPv4 part counts as two groups.
  testRejectSixGroupsWithV4 = {
    expr = parse "1:2:3:4:5:1.2.3.4";
    expectedError.msg = "^libnet\\.ipv6\\.parse: must have 8 groups, got 7: \"1:2:3:4:5:1\\.2\\.3\\.4\"$";
  };
  testRejectOversizeGroup = {
    expr = parse "12345::";
    expectedError.msg = "^libnet\\.ipv6\\.parse: invalid group \"12345\" in \"12345::\"$";
  };
  testRejectNonHex = {
    expr = parse "gggg::";
    expectedError.msg = "^libnet\\.ipv6\\.parse: invalid group \"gggg\" in \"gggg::\"$";
  };
  # The first invalid group is reported.
  testRejectNonHexRight = {
    expr = parse "1::g:h";
    expectedError.msg = "^libnet\\.ipv6\\.parse: invalid group \"g\" in \"1::g:h\"$";
  };
  testRejectV4InLeft = {
    expr = parse "1.2.3.4::1";
    expectedError.msg = "^libnet\\.ipv6\\.parse: invalid group \"1\\.2\\.3\\.4\" in \"1\\.2\\.3\\.4::1\"$";
  };
  testRejectV4NotLast = {
    expr = parse "::1.2.3.4:1";
    expectedError.msg = "^libnet\\.ipv6\\.parse: invalid group \"1\\.2\\.3\\.4\" in \"::1\\.2\\.3\\.4:1\"$";
  };
  testRejectBadV4Part = {
    expr = parse "::ffff:1.2.3";
    expectedError.msg = "^libnet\\.ipv6\\.parse: invalid IPv4 part \"1\\.2\\.3\" in \"::ffff:1\\.2\\.3\"$";
  };
  testRejectV4PartLeadingZero = {
    expr = parse "::ffff:1.2.3.04";
    expectedError.msg = "^libnet\\.ipv6\\.parse: invalid IPv4 part \"1\\.2\\.3\\.04\" in \"::ffff:1\\.2\\.3\\.04\"$";
  };
  testRejectWhitespace = {
    expr = parse " ::1";
    expectedError.msg = "^libnet\\.ipv6\\.parse: invalid group \" \" in \" ::1\"$";
  };
  testRejectNotString = {
    expr = ipv6.parse 123;
    expectedError.msg = "^libnet\\.ipv6\\.parse: expected string, got int$";
  };
  testTryParseErrorNamesParse = {
    expr = (ipv6.tryParse "::1::").error;
    expected = "libnet.ipv6.parse: more than one \"::\" in \"::1::\"";
  };
  testTryParseNonStringError = {
    expr = (ipv6.tryParse { }).error;
    expected = "libnet.ipv6.parse: expected string, got set";
  };
  # "::" stands for at least one zero group.
  testRejectCompressionWithEightGroups = {
    expr = parse "1:2:3:4::5:6:7:8";
    expectedError.msg = "^libnet\\.ipv6\\.parse: must have at most 7 groups with \"::\", got 8: \"1:2:3:4::5:6:7:8\"$";
  };
  testRejectCompressionWithV4Overflow = {
    expr = parse "1:2:3:4:5::6:1.2.3.4";
    expectedError.msg = "^libnet\\.ipv6\\.parse: must have at most 7 groups with \"::\", got 8: \"1:2:3:4:5::6:1\\.2\\.3\\.4\"$";
  };
  testAcceptCompressionWithSevenGroups = {
    expr = ipv6.toString (parse "1:2:3::4:5:6:7");
    expected = "1:2:3:0:4:5:6:7";
  };

  # ===== tryParse =====
  testTryParseOk = {
    expr = (ipv6.tryParse "::1").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (ipv6.tryParse "bad").success;
    expected = false;
  };

  # ===== toString (RFC 5952) =====
  testFormatLoopback = {
    expr = ipv6.toString (parse "::1");
    expected = "::1";
  };
  testFormatUnspecified = {
    expr = ipv6.toString (parse "::");
    expected = "::";
  };
  testFormatTrailingCompression = {
    expr = ipv6.toString (parse "1::");
    expected = "1::";
  };
  testFormatMiddleCompression = {
    expr = ipv6.toString (parse "1:2::3:4");
    expected = "1:2::3:4";
  };
  testFormatDocumentation = {
    expr = ipv6.toString (parse "2001:0db8:0000:0000:0000:0000:0000:0001");
    expected = "2001:db8::1";
  };
  testFormatNoCompression = {
    expr = ipv6.toString (parse "1:2:3:4:5:6:7:8");
    expected = "1:2:3:4:5:6:7:8";
  };
  testFormatFirstRunWins = {
    expr = ipv6.toString (parse "1:0:0:2:3:0:0:4");
    expected = "1::2:3:0:0:4";
  }; # first tied run wins
  testFormatSingleZero = {
    expr = ipv6.toString (parse "1:0:2:0:3:0:4:5");
    expected = "1:0:2:0:3:0:4:5";
  }; # no run of >=2, no compression

  # ===== toStringExpanded / Bracketed =====
  testFormatExpanded = {
    expr = ipv6.toStringExpanded (parse "::1");
    expected = "0000:0000:0000:0000:0000:0000:0000:0001";
  };
  testFormatBracketed = {
    expr = ipv6.toStringBracketed (parse "::1");
    expected = "[::1]";
  };
  testFormatBracketedDocumentation = {
    expr = ipv6.toStringBracketed (parse "2001:db8::1");
    expected = "[2001:db8::1]";
  };

  # ===== toArpa =====
  testArpaDocumentation = {
    expr = ipv6.toArpa (parse "2001:db8::1");
    expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa";
  };
  testArpaLoopback = {
    expr = ipv6.toArpa (parse "::1");
    expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa";
  };

  # ===== Round-trip =====
  testRoundTripWords = {
    expr = ipv6.toWords (
      ipv6.fromWords [
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
  testRoundTripGroups = {
    expr = ipv6.toGroups (
      ipv6.fromGroups [
        1
        2
        3
        4
        5
        6
        7
        8
      ]
    );
    expected = [
      1
      2
      3
      4
      5
      6
      7
      8
    ];
  };
  testRoundTripBytes = {
    expr = ipv6.toBytes (
      ipv6.fromBytes [
        0
        1
        0
        2
        0
        3
        0
        4
        0
        5
        0
        6
        0
        7
        0
        8
      ]
    );
    expected = [
      0
      1
      0
      2
      0
      3
      0
      4
      0
      5
      0
      6
      0
      7
      0
      8
    ];
  };
  testRoundTripString = {
    expr = ipv6.toString (parse (ipv6.toString (parse "2001:db8::1")));
    expected = "2001:db8::1";
  };

  # ===== fromWords / fromGroups / fromBytes errors =====
  testFromWordsShort = {
    expr = ipv6.fromWords [
      1
      2
      3
    ];
    expectedError.msg = "^libnet\\.ipv6\\.fromWords: expected 4 words, got 3$";
  };
  testFromWordsOverflow = {
    expr = ipv6.fromWords [
      4294967296
      0
      0
      0
    ];
    expectedError.msg = "^libnet\\.ipv6\\.fromWords: word out of range \\[0, 4294967295\\]: 4294967296$";
  };
  testFromGroupsShort = {
    expr = ipv6.fromGroups [
      1
      2
      3
      4
    ];
    expectedError.msg = "^libnet\\.ipv6\\.fromGroups: expected 8 groups, got 4$";
  };
  testFromGroupsOverflow = {
    expr = ipv6.fromGroups [
      65536
      0
      0
      0
      0
      0
      0
      0
    ];
    expectedError.msg = "^libnet\\.ipv6\\.fromGroups: group out of range \\[0, 65535\\]: 65536$";
  };
  testFromBytesShort = {
    expr = ipv6.fromBytes [ 0 ];
    expectedError.msg = "^libnet\\.ipv6\\.fromBytes: expected 16 bytes, got 1$";
  };
  testFromWordsRejectsSet = {
    expr = ipv6.fromWords { };
    expectedError.msg = "^libnet\\.ipv6\\.fromWords: expected list, got set$";
  };
  testFromGroupsRejectsStringGroup = {
    expr = ipv6.fromGroups [
      0
      0
      0
      0
      0
      0
      0
      "1"
    ];
    expectedError.msg = "^libnet\\.ipv6\\.fromGroups: expected int group, got string$";
  };
  testFromBytesRejectsFloatByte = {
    expr = ipv6.fromBytes (builtins.genList (_: 0) 15 ++ [ 1.0 ]);
    expectedError.msg = "^libnet\\.ipv6\\.fromBytes: expected int byte, got float$";
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = ipv6.is (parse "::1");
    expected = true;
  };
  testIsString = {
    expr = ipv6.is "::1";
    expected = false;
  };
  testIsValidOk = {
    expr = ipv6.isValid "::1";
    expected = true;
  };
  testIsValidBad = {
    expr = ipv6.isValid "bad";
    expected = false;
  };

  testLoopbackPositive = {
    expr = ipv6.isLoopback (parse "::1");
    expected = true;
  };
  testLoopbackNegative = {
    expr = ipv6.isLoopback (parse "::2");
    expected = false;
  };
  testUnspecifiedPositive = {
    expr = ipv6.isUnspecified (parse "::");
    expected = true;
  };
  testUnspecifiedNegative = {
    expr = ipv6.isUnspecified (parse "::1");
    expected = false;
  };
  testLinkLocalPositive = {
    expr = ipv6.isLinkLocal (parse "fe80::1");
    expected = true;
  };
  testLinkLocalPositiveHigh = {
    expr = ipv6.isLinkLocal (parse "febf:ffff::1");
    expected = true;
  };
  testLinkLocalNegative = {
    expr = ipv6.isLinkLocal (parse "fec0::1");
    expected = false;
  };
  testUniqueLocalPositive = {
    expr = ipv6.isUniqueLocal (parse "fc00::1");
    expected = true;
  };
  testUniqueLocalPositiveFd = {
    expr = ipv6.isUniqueLocal (parse "fd00::1");
    expected = true;
  };
  testUniqueLocalNegative = {
    expr = ipv6.isUniqueLocal (parse "fe00::1");
    expected = false;
  };
  testMulticastPositive = {
    expr = ipv6.isMulticast (parse "ff00::1");
    expected = true;
  };
  testMulticastNegative = {
    expr = ipv6.isMulticast (parse "fe00::1");
    expected = false;
  };
  testDocumentationPositive = {
    expr = ipv6.isDocumentation (parse "2001:db8::1");
    expected = true;
  };
  testDocumentation3fffPositive = {
    expr = ipv6.isDocumentation (parse "3fff::1");
    expected = true;
  };
  testDocumentationNegative = {
    expr = ipv6.isDocumentation (parse "2001:db9::1");
    expected = false;
  };
  testV4MappedPositive = {
    expr = ipv6.isIpv4Mapped (parse "::ffff:1.2.3.4");
    expected = true;
  };
  testV4MappedNegative = {
    expr = ipv6.isIpv4Mapped (parse "::1");
    expected = false;
  };
  testV4CompatiblePositive = {
    expr = ipv6.isIpv4Compatible (parse "::1.2.3.4");
    expected = true;
  };
  testV4CompatibleLoopback = {
    expr = ipv6.isIpv4Compatible (parse "::1");
    expected = true;
  }; # loopback is also in ::/96
  testV4CompatibleNegative = {
    expr = ipv6.isIpv4Compatible (parse "1::");
    expected = false;
  };
  test6to4Positive = {
    expr = ipv6.is6to4 (parse "2002::1");
    expected = true;
  };
  test6to4Negative = {
    expr = ipv6.is6to4 (parse "2001::1");
    expected = false;
  };

  # ===== Predicates: special-use (discard / deprecated) =====
  testDiscardPositive = {
    expr = ipv6.isDiscard (parse "100::1");
    expected = true;
  };
  testDiscardNegative = {
    expr = ipv6.isDiscard (parse "100:0:0:1::");
    expected = false;
  };
  testOrchidPositive = {
    expr = ipv6.isOrchid (parse "2001:10::1");
    expected = true;
  };
  testOrchidNegative = {
    expr = ipv6.isOrchid (parse "2001:20::1");
    expected = false;
  };
  testSiteLocalPositive = {
    expr = ipv6.isSiteLocal (parse "fec0::1");
    expected = true;
  };
  testSiteLocalPositiveHigh = {
    expr = ipv6.isSiteLocal (parse "feff:ffff::1");
    expected = true;
  };
  testSiteLocalNegative = {
    expr = ipv6.isSiteLocal (parse "fe80::1");
    expected = false;
  };
  testBogonDiscard = {
    expr = ipv6.isBogon (parse "100::1");
    expected = true;
  };
  testBogonOrchid = {
    expr = ipv6.isBogon (parse "2001:10::1");
    expected = true;
  };
  testBogonSiteLocal = {
    expr = ipv6.isBogon (parse "fec0::1");
    expected = true;
  };

  # ===== Predicates: special-use (IANA, 2025-10-09) =====
  testTeredoPositive = {
    expr = ipv6.isTeredo (parse "2001::1");
    expected = true;
  };
  testTeredoPositiveHigh = {
    expr = ipv6.isTeredo (parse "2001:0:ffff:ffff:ffff:ffff:ffff:ffff");
    expected = true;
  };
  testTeredoNegative = {
    expr = ipv6.isTeredo (parse "2001:1::");
    expected = false;
  };
  testLocalNat64PositiveLow = {
    expr = ipv6.isLocalNat64 (parse "64:ff9b:1::");
    expected = true;
  };
  testLocalNat64PositiveHigh = {
    expr = ipv6.isLocalNat64 (parse "64:ff9b:1:ffff:ffff:ffff:ffff:ffff");
    expected = true;
  };
  testLocalNat64NegativeWellKnown = {
    expr = ipv6.isLocalNat64 (parse "64:ff9b::1");
    expected = false;
  };
  testLocalNat64NegativeAbove = {
    expr = ipv6.isLocalNat64 (parse "64:ff9b:2::");
    expected = false;
  };
  testDummyPositiveLow = {
    expr = ipv6.isDummy (parse "100:0:0:1::");
    expected = true;
  };
  testDummyPositiveHigh = {
    expr = ipv6.isDummy (parse "100:0:0:1:ffff:ffff:ffff:ffff");
    expected = true;
  };
  testDummyNegativeDiscard = {
    expr = ipv6.isDummy (parse "100::1");
    expected = false;
  };
  testDummyNegativeAbove = {
    expr = ipv6.isDummy (parse "100:0:0:2::");
    expected = false;
  };
  testProtocolPositiveLow = {
    expr = ipv6.isProtocolAssignment (parse "2001:1::");
    expected = true;
  };
  testProtocolPositiveHigh = {
    expr = ipv6.isProtocolAssignment (parse "2001:1ff:ffff:ffff:ffff:ffff:ffff:ffff");
    expected = true;
  };
  testProtocolPositiveBenchmarking = {
    expr = ipv6.isProtocolAssignment (parse "2001:2::1");
    expected = true;
  };
  testProtocolPositiveOrchid = {
    expr = ipv6.isProtocolAssignment (parse "2001:10::1");
    expected = true;
  };
  testProtocolPositiveBelowAs112 = {
    expr = ipv6.isProtocolAssignment (parse "2001:4:111:ffff:ffff:ffff:ffff:ffff");
    expected = true;
  };
  testProtocolPositiveAboveAs112 = {
    expr = ipv6.isProtocolAssignment (parse "2001:4:113::");
    expected = true;
  };
  testProtocolPositiveAboveAnycast = {
    expr = ipv6.isProtocolAssignment (parse "2001:1::4");
    expected = true;
  };
  testProtocolPositiveBelowOrchidV2 = {
    expr = ipv6.isProtocolAssignment (parse "2001:1f:ffff:ffff:ffff:ffff:ffff:ffff");
    expected = true;
  };
  testProtocolPositiveAboveDet = {
    expr = ipv6.isProtocolAssignment (parse "2001:40::");
    expected = true;
  };
  testProtocolNegativeAbove = {
    expr = ipv6.isProtocolAssignment (parse "2001:200::");
    expected = false;
  };
  testProtocolNegativeBelow = {
    expr = ipv6.isProtocolAssignment (parse "2000:ffff:ffff:ffff:ffff:ffff:ffff:ffff");
    expected = false;
  };
  testProtocolNegativeTeredo = {
    expr = ipv6.isProtocolAssignment (parse "2001::1");
    expected = false;
  };
  # The globally reachable allocations inside 2001::/23 are neither
  # protocol assignments nor bogons, and are global.
  testProtocolExcludesReachable = {
    expr = builtins.any (input: ipv6.isProtocolAssignment (parse input)) reachableInProtocolBlock;
    expected = false;
  };
  testBogonExcludesReachable = {
    expr = builtins.any (input: ipv6.isBogon (parse input)) reachableInProtocolBlock;
    expected = false;
  };
  testGlobalReachable = {
    expr = builtins.all (input: ipv6.isGlobal (parse input)) reachableInProtocolBlock;
    expected = true;
  };
  testBenchmarkingPositiveLow = {
    expr = ipv6.isBenchmarking (parse "2001:2::");
    expected = true;
  };
  testBenchmarkingPositiveHigh = {
    expr = ipv6.isBenchmarking (parse "2001:2:0:ffff:ffff:ffff:ffff:ffff");
    expected = true;
  };
  testBenchmarkingNegativeAbove = {
    expr = ipv6.isBenchmarking (parse "2001:2:1::");
    expected = false;
  };
  testBenchmarkingNegativeBelow = {
    expr = ipv6.isBenchmarking (parse "2001:1:ffff:ffff:ffff:ffff:ffff:ffff");
    expected = false;
  };
  testSrv6SidPositiveLow = {
    expr = ipv6.isSrv6Sid (parse "5f00::");
    expected = true;
  };
  testSrv6SidPositiveHigh = {
    expr = ipv6.isSrv6Sid (parse "5f00:ffff:ffff:ffff:ffff:ffff:ffff:ffff");
    expected = true;
  };
  testSrv6SidNegativeBelow = {
    expr = ipv6.isSrv6Sid (parse "5eff:ffff:ffff:ffff:ffff:ffff:ffff:ffff");
    expected = false;
  };
  testSrv6SidNegativeAbove = {
    expr = ipv6.isSrv6Sid (parse "5f01::");
    expected = false;
  };
  testBogonLocalNat64 = {
    expr = ipv6.isBogon (parse "64:ff9b:1::1");
    expected = true;
  };
  testBogonDummy = {
    expr = ipv6.isBogon (parse "100:0:0:1::1");
    expected = true;
  };
  testBogonProtocolAssignment = {
    expr = ipv6.isBogon (parse "2001:5::1");
    expected = true;
  };
  testBogonBenchmarking = {
    expr = ipv6.isBogon (parse "2001:2::1");
    expected = true;
  };
  testBogonSrv6Sid = {
    expr = ipv6.isBogon (parse "5f00::1");
    expected = true;
  };
  testGlobalNegativeProtocolAssignment = {
    expr = ipv6.isGlobal (parse "2001:5::1");
    expected = false;
  };
  testGlobalNegativeSrv6Sid = {
    expr = ipv6.isGlobal (parse "5f00::1");
    expected = false;
  };
  # 64:ff9b::/96, the well-known NAT64 prefix, is globally reachable.
  testGlobalWellKnownNat64 = {
    expr = ipv6.isGlobal (parse "64:ff9b::1");
    expected = true;
  };
  testBogonExcludesWellKnownNat64 = {
    expr = ipv6.isBogon (parse "64:ff9b::1");
    expected = false;
  };

  testGlobalPositive = {
    expr = ipv6.isGlobal (parse "2606:4700:4700::1111");
    expected = true;
  };
  testGlobalNegativeLoopback = {
    expr = ipv6.isGlobal (parse "::1");
    expected = false;
  };
  # isGlobal is stricter than !isBogon: IPv4-mapped, IPv4-compatible,
  # 6to4, and Teredo addresses are also not global.
  testGlobalNegativeV4Mapped = {
    expr = ipv6.isGlobal (parse "::ffff:8.8.8.8");
    expected = false;
  };
  testGlobalNegativeV4Compatible = {
    expr = ipv6.isGlobal (parse "::1.2.3.4");
    expected = false;
  };
  testGlobalNegative6to4 = {
    expr = ipv6.isGlobal (parse "2002::1");
    expected = false;
  };
  testGlobalNegativeTeredo = {
    expr = ipv6.isGlobal (parse "2001::1");
    expected = false;
  };
  # isBogon stays narrower: transition forms are not bogons.
  testBogonExcludes6to4 = {
    expr = ipv6.isBogon (parse "2002::1");
    expected = false;
  };
  testBogonExcludesTeredo = {
    expr = ipv6.isBogon (parse "2001::1");
    expected = false;
  };
  testBogonPositive = {
    expr = ipv6.isBogon (parse "::1");
    expected = true;
  };
  testBogonNegative = {
    expr = ipv6.isBogon (parse "2606:4700:4700::1111");
    expected = false;
  };

  # ===== IPv4 interop =====
  testFromIpv4 = {
    expr = ipv6.toString (ipv6.fromIpv4 (ipv4.parse "1.2.3.4"));
    expected = "::ffff:1.2.3.4";
  };
  testToIpv4 = {
    expr = ipv4.toString (ipv6.toIpv4 (parse "::ffff:1.2.3.4"));
    expected = "1.2.3.4";
  };
  testToIpv4RejectsNonMapped = {
    expr = ipv6.toIpv4 (parse "::1");
    expectedError.msg = "^libnet\\.ipv6\\.toIpv4: address is not in ::ffff:0:0/96: ::1$";
  };
  testFromIpv4RejectsIpv6 = {
    expr = ipv6.fromIpv4 (parse "::1");
    expectedError.msg = "^libnet\\.ipv6\\.fromIpv4: expected ipv4 value, got ipv6 value$";
  };

  # ===== fromMac (modified EUI-64) =====
  # 2001:db8::/64 + aa:bb:cc:dd:ee:ff → 2001:db8::a8bb:ccff:fedd:eeff
  testFromMacVector = {
    expr = ipv6.toString (
      ipv6.fromMac {
        _type = "cidr";
        networkAddress = parse "2001:db8::";
        prefix = 64;
      } (mac.parse "aa:bb:cc:dd:ee:ff")
    );
    expected = "2001:db8::a8bb:ccff:fedd:eeff";
  };
  testFromMacPrefixTooBig = {
    expr = ipv6.fromMac {
      _type = "cidr";
      networkAddress = parse "2001:db8::";
      prefix = 96;
    } (mac.parse "aa:bb:cc:dd:ee:ff");
    expectedError.msg = "^libnet\\.ipv6\\.fromMac: CIDR prefix must be <= 64, got /96$";
  };
  testFromMacWrongType = {
    expr = ipv6.fromMac (parse "::1") (mac.parse "aa:bb:cc:dd:ee:ff");
    expectedError.msg = "^libnet\\.ipv6\\.fromMac: expected cidr value, got ipv6 value$";
  };
  testFromMacNonMac = {
    expr = ipv6.fromMac {
      _type = "cidr";
      networkAddress = parse "2001:db8::";
      prefix = 64;
    } "aa:bb:cc:dd:ee:ff";
    expectedError.msg = "^libnet\\.ipv6\\.fromMac: expected mac value, got string$";
  };
  testFromMacRejectsIpv4Cidr = {
    expr = ipv6.fromMac (libnet.cidr.parse "10.0.0.0/8") (mac.parse "aa:bb:cc:dd:ee:ff");
    expectedError.msg = "^libnet\\.ipv6\\.fromMac: expected an IPv6 cidr, got an IPv4 one$";
  };

  # ===== Arithmetic =====
  testAddOne = {
    expr = ipv6.toString (ipv6.add 1 (parse "::"));
    expected = "::1";
  };
  testAddOneWordCarry = {
    expr = ipv6.toString (ipv6.add 1 (parse "::ffff:ffff"));
    expected = "::1:0:0";
  };
  testAddZeroIdentity = {
    expr = ipv6.toString (ipv6.add 0 (parse "::1"));
    expected = "::1";
  };
  testAddOverflow = {
    expr = ipv6.add 1 (parse "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff");
    expectedError.msg = "^libnet\\.ipv6\\.add: out of range: ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff \\+ 1$";
  };
  testSubOne = {
    expr = ipv6.toString (ipv6.sub 1 (parse "::2"));
    expected = "::1";
  };
  # ::1:0:0:0 - 1 is ::ffff:ffff:ffff, which lies in ::ffff:0:0/96, so it
  # formats in IPv4-mapped mixed form.
  testSubBorrow = {
    expr = ipv6.toString (ipv6.sub 1 (parse "::1:0:0:0"));
    expected = "::ffff:255.255.255.255";
  };
  # A borrow case that stays outside the v4-mapped range
  testSubBorrowHex = {
    expr = ipv6.toString (ipv6.sub 1 (parse "::1:1:0:0:0"));
    expected = "::1:0:ffff:ffff:ffff";
  };
  # IPv4-mapped addresses format in mixed form.
  testFormatV4MappedMixed = {
    expr = ipv6.toString (parse "::ffff:c000:201");
    expected = "::ffff:192.0.2.1";
  };
  testSubUnderflow = {
    expr = ipv6.sub 1 (parse "::");
    expectedError.msg = "^libnet\\.ipv6\\.sub: out of range: :: - 1$";
  };
  testNext = {
    expr = ipv6.toString (ipv6.next (parse "::1"));
    expected = "::2";
  };
  testPrev = {
    expr = ipv6.toString (ipv6.prev (parse "::2"));
    expected = "::1";
  };
  testDiffPositive = {
    expr = ipv6.diff (parse "::1") (parse "::10");
    expected = 15;
  };
  testDiffZero = {
    expr = ipv6.diff (parse "::1") (parse "::1");
    expected = 0;
  };
  testDiffNegative = {
    expr = ipv6.diff (parse "::10") (parse "::1");
    expected = -15;
  };
  testNextAtMaxNamesNext = {
    expr = ipv6.next (parse "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff");
    expectedError.msg = "^libnet\\.ipv6\\.next: out of range: ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff \\+ 1$";
  };
  testPrevAtMinNamesPrev = {
    expr = ipv6.prev (parse "::");
    expectedError.msg = "^libnet\\.ipv6\\.prev: out of range: :: - 1$";
  };
  testAddRejectsFloatOffset = {
    expr = ipv6.add 1.5 (parse "::1");
    expectedError.msg = "^libnet\\.ipv6\\.add: expected int, got float$";
  };
  testAddNegativeOffset = {
    expr = ipv6.toString (ipv6.add (-1) (parse "::1:0:0"));
    expected = "::ffff:ffff";
  };
  testSubNegativeOffset = {
    expr = ipv6.toString (ipv6.sub (-1) (parse "::ffff:ffff"));
    expected = "::1:0:0";
  };
  testAddCarryAcrossEveryWord = {
    expr = ipv6.toString (ipv6.add 1 (parse "0:ffff:ffff:ffff:ffff:ffff:ffff:ffff"));
    expected = "1::";
  };
  # The offsets at the integer limits, 2^63 - 1 and -2^63, span the
  # lower two words.
  testAddLargestIntegerOffset = {
    expr = ipv6.toString (ipv6.add 9223372036854775807 (parse "::"));
    expected = "::7fff:ffff:ffff:ffff";
  };
  testAddSmallestIntegerOffset = {
    expr = ipv6.toString (ipv6.add (-9223372036854775807 - 1) (parse "::8000:0:0:0"));
    expected = "::";
  };
  testAddSmallestIntegerOffsetUnderflow = {
    expr = ipv6.add (-9223372036854775807 - 1) (parse "::7fff:ffff:ffff:ffff");
    expectedError.msg = "^libnet\\.ipv6\\.add: out of range: ::7fff:ffff:ffff:ffff \\+ -9223372036854775808$";
  };
  testAddLargestIntegerOffsetToMax = {
    expr = ipv6.toString (ipv6.add 9223372036854775807 (parse "ffff:ffff:ffff:ffff:8000::"));
    expected = "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff";
  };
  testAddLargestIntegerOffsetOverflow = {
    expr = ipv6.add 9223372036854775807 (parse "ffff:ffff:ffff:ffff:8000::1");
    expectedError.msg = "^libnet\\.ipv6\\.add: out of range: ffff:ffff:ffff:ffff:8000::1 \\+ 9223372036854775807$";
  };
  testSubLargestIntegerOffset = {
    expr = ipv6.toString (ipv6.sub 9223372036854775807 (parse "::7fff:ffff:ffff:ffff"));
    expected = "::";
  };
  # Negating this offset would overflow.
  testSubSmallestIntegerOffset = {
    expr = ipv6.toString (ipv6.sub (-9223372036854775807 - 1) (parse "::"));
    expected = "::8000:0:0:0";
  };
  testSubSmallestIntegerOffsetOverflow = {
    expr = ipv6.sub (-9223372036854775807 - 1) (parse "ffff:ffff:ffff:ffff:8000::");
    expectedError.msg = "^libnet\\.ipv6\\.sub: out of range: ffff:ffff:ffff:ffff:8000:: - -9223372036854775808$";
  };
  # A difference fits when it lies in [-2^63, 2^63 - 1].
  testDiffLargest = {
    expr = ipv6.diff (parse "::") (parse "::7fff:ffff:ffff:ffff");
    expected = 9223372036854775807;
  };
  testDiffSmallest = {
    expr = ipv6.diff (parse "::8000:0:0:0") (parse "::");
    expected = -9223372036854775807 - 1;
  };
  testDiffSmallestOffsetFromNonZero = {
    expr = ipv6.diff (parse "1::8000:0:0:1") (parse "1::1");
    expected = -9223372036854775807 - 1;
  };
  testDiffAboveLargest = {
    expr = ipv6.diff (parse "::") (parse "::8000:0:0:0");
    expectedError.msg = "^libnet\\.ipv6\\.diff: difference out of the Nix integer range: ::8000:0:0:0 - ::$";
  };
  testDiffBelowSmallest = {
    expr = ipv6.diff (parse "::8000:0:0:1") (parse "::");
    expectedError.msg = "^libnet\\.ipv6\\.diff: difference out of the Nix integer range: :: - ::8000:0:0:1$";
  };
  testDiffAcrossUpperWords = {
    expr = ipv6.diff (parse "::") (parse "1::");
    expectedError.msg = "^libnet\\.ipv6\\.diff: difference out of the Nix integer range: 1:: - ::$";
  };

  # ===== Comparison helpers =====
  testLeLess = {
    expr = ipv6.le (parse "::1") (parse "::2");
    expected = true;
  };
  testGtGreater = {
    expr = ipv6.gt (parse "::2") (parse "::1");
    expected = true;
  };
  testGeGreater = {
    expr = ipv6.ge (parse "::2") (parse "::1");
    expected = true;
  };

  # ===== Comparison =====
  testEqSame = {
    expr = ipv6.eq (parse "::1") (parse "::1");
    expected = true;
  };
  testEqDifferent = {
    expr = ipv6.eq (parse "::1") (parse "::2");
    expected = false;
  };
  testLtYes = {
    expr = ipv6.lt (parse "::1") (parse "::2");
    expected = true;
  };
  testLtNo = {
    expr = ipv6.lt (parse "::2") (parse "::1");
    expected = false;
  };
  testLtFirstWord = {
    expr = ipv6.lt (parse "1::") (parse "2::");
    expected = true;
  };
  testCompareLess = {
    expr = ipv6.compare (parse "::1") (parse "::2");
    expected = -1;
  };
  testCompareEqual = {
    expr = ipv6.compare (parse "::1") (parse "::1");
    expected = 0;
  };
  testCompareGreater = {
    expr = ipv6.compare (parse "::2") (parse "::1");
    expected = 1;
  };
  testMinSmaller = {
    expr = ipv6.toString (ipv6.min (parse "::1") (parse "::2"));
    expected = "::1";
  };
  testMaxLarger = {
    expr = ipv6.toString (ipv6.max (parse "::1") (parse "::2"));
    expected = "::2";
  };
  # A single-family namespace orders only its own family; `ip` orders
  # IPv4 before IPv6.
  testCompareRejectsIpv4 = {
    expr = ipv6.compare (parse "::1") (libnet.ipv4.parse "0.0.0.1");
    expectedError.msg = "^libnet\\.ipv6\\.compare: expected ipv6 value, got ipv4 value$";
  };
  testGeRejectsIpv4 = {
    expr = ipv6.ge (libnet.ipv4.parse "0.0.0.1") (parse "::1");
    expectedError.msg = "^libnet\\.ipv6\\.ge: expected ipv6 value, got ipv4 value$";
  };
  testMinRejectsIpv4 = {
    expr = ipv6.min (parse "::1") (libnet.ipv4.parse "0.0.0.1");
    expectedError.msg = "^libnet\\.ipv6\\.min: expected ipv6 value, got ipv4 value$";
  };
  testEqIpv4IsFalse = {
    expr = ipv6.eq (parse "::1") (libnet.ipv4.parse "0.0.0.1");
    expected = false;
  };

  # ===== Constants =====
  testConstantUnspecified = {
    expr = ipv6.toString ipv6.unspecified;
    expected = "::";
  };
  testConstantLoopback = {
    expr = ipv6.toString ipv6.loopback;
    expected = "::1";
  };

  # ===== Curry =====
  testCurriedAdd = {
    expr = map ipv6.toString (
      map (ipv6.add 1) [
        (parse "::")
        (parse "::10")
      ]
    );
    expected = [
      "::1"
      "::11"
    ];
  };
}
