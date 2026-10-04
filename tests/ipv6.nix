{ harness }:
let
  ipv6 = import ../lib/ipv6.nix;
  ipv4 = import ../lib/ipv4.nix;
  mac = import ../lib/mac.nix;
  inherit (harness) throws;

  parse = ipv6.parse;
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
    expr = throws (parse "");
    expected = true;
  };
  testRejectTripleColon = {
    expr = throws (parse ":::");
    expected = true;
  };
  testRejectTwoCompressions = {
    expr = throws (parse "::1::");
    expected = true;
  };
  testRejectNineGroups = {
    expr = throws (parse "1:2:3:4:5:6:7:8:9");
    expected = true;
  };
  testRejectOversizeGroup = {
    expr = throws (parse "12345::");
    expected = true;
  };
  testRejectNonHex = {
    expr = throws (parse "gggg::");
    expected = true;
  };
  testRejectV4InLeft = {
    expr = throws (parse "1.2.3.4::1");
    expected = true;
  };
  testRejectWhitespace = {
    expr = throws (parse " ::1");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (ipv6.parse 123);
    expected = true;
  };
  testRejectCompressionWithEightGroups = {
    expr = throws (parse "1:2:3:4::5:6:7:8");
    expected = true;
  }; # 8 groups + :: invalid

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

  # ===== toStringCompressed / Expanded / Bracketed =====
  testFormatCompressed = {
    expr = ipv6.toStringCompressed (parse "2001:db8:0:0:0:0:0:1");
    expected = "2001:db8::1";
  };
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
    expr = throws (
      ipv6.fromWords [
        1
        2
        3
      ]
    );
    expected = true;
  };
  testFromWordsOverflow = {
    expr = throws (
      ipv6.fromWords [
        4294967296
        0
        0
        0
      ]
    );
    expected = true;
  };
  testFromGroupsShort = {
    expr = throws (
      ipv6.fromGroups [
        1
        2
        3
        4
      ]
    );
    expected = true;
  };
  testFromGroupsOverflow = {
    expr = throws (
      ipv6.fromGroups [
        65536
        0
        0
        0
        0
        0
        0
        0
      ]
    );
    expected = true;
  };
  testFromBytesShort = {
    expr = throws (ipv6.fromBytes [ 0 ]);
    expected = true;
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

  testGlobalPositive = {
    expr = ipv6.isGlobal (parse "2606:4700:4700::1111");
    expected = true;
  };
  testGlobalNegativeLoopback = {
    expr = ipv6.isGlobal (parse "::1");
    expected = false;
  };
  # isGlobal is stricter than !isBogon: IPv4-mapped, IPv4-compatible, and
  # 6to4 addresses are also not global.
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
  # isBogon stays narrower: 6to4 and IPv4-mapped addresses are not bogons.
  testBogonExcludes6to4 = {
    expr = ipv6.isBogon (parse "2002::1");
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
  testFromIpv4Mapped = {
    expr = ipv6.toString (ipv6.fromIpv4Mapped (ipv4.parse "1.2.3.4"));
    expected = "::ffff:1.2.3.4";
  };
  testToIpv4Mapped = {
    expr = ipv4.toString (ipv6.toIpv4Mapped (parse "::ffff:1.2.3.4"));
    expected = "1.2.3.4";
  };
  testToIpv4MappedRejectsNonMapped = {
    expr = throws (ipv6.toIpv4Mapped (parse "::1"));
    expected = true;
  };
  testFromIpv4MappedRejectsIpv6 = {
    expr = throws (ipv6.fromIpv4Mapped (parse "::1"));
    expected = true;
  };

  # ===== EUI-64 =====
  # 2001:db8::/64 + aa:bb:cc:dd:ee:ff → 2001:db8::a8bb:ccff:fedd:eeff
  testEui64Vector = {
    expr = ipv6.toString (
      ipv6.fromEui64 {
        _type = "cidr";
        address = parse "2001:db8::";
        prefix = 64;
      } (mac.parse "aa:bb:cc:dd:ee:ff")
    );
    expected = "2001:db8::a8bb:ccff:fedd:eeff";
  };
  testEui64PrefixTooBig = {
    expr = throws (
      ipv6.fromEui64 {
        _type = "cidr";
        address = parse "2001:db8::";
        prefix = 96;
      } (mac.parse "aa:bb:cc:dd:ee:ff")
    );
    expected = true;
  };
  testEui64WrongType = {
    expr = throws (ipv6.fromEui64 (parse "::1") (mac.parse "aa:bb:cc:dd:ee:ff"));
    expected = true;
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
    expr = throws (ipv6.add 1 (parse "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"));
    expected = true;
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
    expr = throws (ipv6.sub 1 (parse "::"));
    expected = true;
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
