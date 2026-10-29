{ libnet, ... }:
let
  inherit (libnet) ip;
  inherit (ip) parse;
in
{
  # ===== Dispatch parse =====
  testParseV4 = {
    expr = ip.version (parse "1.2.3.4");
    expected = 4;
  };
  testParseV6 = {
    expr = ip.version (parse "::1");
    expected = 6;
  };
  testParseRejectsBad = {
    expr = parse "bogus";
    expectedError.msg = "^libnet\\.ip\\.parse: must have 4 octets, got 1: \"bogus\"$";
  };
  # A union names itself and keeps its member's detail.
  testParseInvalidOctetNamesIp = {
    expr = parse "300.1.1.1";
    expectedError.msg = "^libnet\\.ip\\.parse: invalid octet in \"300\\.1\\.1\\.1\"$";
  };
  # Colon text that is not plausibly IPv6 names the syntax it belongs to.
  testParseIpv4WithPortNamesEndpointSyntax = {
    expr = parse "1.2.3.4:5";
    expectedError.msg = "^libnet\\.ip\\.parse: \"1\\.2\\.3\\.4:5\" reads as host:port, which is endpoint syntax$";
  };
  testParseNameWithPortNamesEndpointSyntax = {
    expr = parse "nas:80";
    expectedError.msg = "^libnet\\.ip\\.parse: \"nas:80\" reads as host:port, which is endpoint syntax$";
  };
  testParseBracketedNamesUrlSyntax = {
    expr = parse "[::1]";
    expectedError.msg = "^libnet\\.ip\\.parse: \"\\[::1]\" is bracketed, which is URL and endpoint syntax$";
  };
  testParseBracketedWithPortNamesUrlSyntax = {
    expr = parse "[::1]:80";
    expectedError.msg = "^libnet\\.ip\\.parse: \"\\[::1]:80\" is bracketed, which is URL and endpoint syntax$";
  };
  # A hex group before the colon is plausibly IPv6, so the detail stays.
  testParseHexGroupWithPortKeepsIpv6Detail = {
    expr = parse "cafe:80";
    expectedError.msg = "^libnet\\.ip\\.parse: must have 8 groups, got 2: \"cafe:80\"$";
  };
  testParseBadIpv6KeepsDetail = {
    expr = parse "::1:g";
    expectedError.msg = "^libnet\\.ip\\.parse: invalid group \"g\" in \"::1:g\"$";
  };
  testParseNonStringNamesIp = {
    expr = ip.parse 1;
    expectedError.msg = "^libnet\\.ip\\.parse: expected string, got int$";
  };
  testTryParseV4 = {
    expr = (ip.tryParse "1.2.3.4").success;
    expected = true;
  };
  testTryParseV6 = {
    expr = (ip.tryParse "::1").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (ip.tryParse "bad").success;
    expected = false;
  };
  testTryParseErrorNamesIp = {
    expr = (ip.tryParse "300.1.1.1").error;
    expected = "libnet.ip.parse: invalid octet in \"300.1.1.1\"";
  };
  testTryParseIpv6ErrorNamesIp = {
    expr = (ip.tryParse "::1::").error;
    expected = "libnet.ip.parse: more than one \"::\" in \"::1::\"";
  };

  # ===== version / is predicates =====
  testIsIpv4V4 = {
    expr = ip.isIpv4 (parse "1.2.3.4");
    expected = true;
  };
  testIsIpv4V6 = {
    expr = ip.isIpv4 (parse "::1");
    expected = false;
  };
  testIsIpv6V6 = {
    expr = ip.isIpv6 (parse "::1");
    expected = true;
  };
  testIsString = {
    expr = ip.is "1.2.3.4";
    expected = false;
  };
  testIsParsed = {
    expr = ip.is (parse "1.2.3.4");
    expected = true;
  };
  testIsValidV4 = {
    expr = ip.isValid "192.0.2.1";
    expected = true;
  };
  testIsValidV6 = {
    expr = ip.isValid "::1";
    expected = true;
  };
  testIsValidBad = {
    expr = ip.isValid "nope";
    expected = false;
  };

  testToStringV4 = {
    expr = ip.toString (parse "1.2.3.4");
    expected = "1.2.3.4";
  };
  testToStringV6 = {
    expr = ip.toString (parse "2001:db8::1");
    expected = "2001:db8::1";
  };

  # ===== Forwarded predicates: dispatch by family =====
  testLoopbackV4 = {
    expr = ip.isLoopback (parse "127.0.0.1");
    expected = true;
  };
  testLoopbackV6 = {
    expr = ip.isLoopback (parse "::1");
    expected = true;
  };
  testNotLoopbackV4 = {
    expr = ip.isLoopback (parse "8.8.8.8");
    expected = false;
  };
  testNotLoopbackV6 = {
    expr = ip.isLoopback (parse "2001:db8::1");
    expected = false;
  };

  testUnspecifiedV4 = {
    expr = ip.isUnspecified (parse "0.0.0.0");
    expected = true;
  };
  testUnspecifiedV6 = {
    expr = ip.isUnspecified (parse "::");
    expected = true;
  };

  testLinkLocalV4 = {
    expr = ip.isLinkLocal (parse "169.254.1.1");
    expected = true;
  };
  testLinkLocalV6 = {
    expr = ip.isLinkLocal (parse "fe80::1");
    expected = true;
  };

  testMulticastV4 = {
    expr = ip.isMulticast (parse "224.0.0.1");
    expected = true;
  };
  testMulticastV6 = {
    expr = ip.isMulticast (parse "ff00::1");
    expected = true;
  };

  testDocumentationV4 = {
    expr = ip.isDocumentation (parse "192.0.2.1");
    expected = true;
  };
  testDocumentationV6 = {
    expr = ip.isDocumentation (parse "2001:db8::1");
    expected = true;
  };

  testGlobalV4 = {
    expr = ip.isGlobal (parse "8.8.8.8");
    expected = true;
  };
  testGlobalV6 = {
    expr = ip.isGlobal (parse "2606:4700:4700::1111");
    expected = true;
  };

  testBogonV4 = {
    expr = ip.isBogon (parse "127.0.0.1");
    expected = true;
  };
  testBogonV6 = {
    expr = ip.isBogon (parse "::1");
    expected = true;
  };
  testNotBogonPublicV4 = {
    expr = ip.isBogon (parse "8.8.8.8");
    expected = false;
  };

  testArpaV4 = {
    expr = ip.toArpa (parse "1.2.3.4");
    expected = "4.3.2.1.in-addr.arpa";
  };
  testArpaV6 = {
    expr = ip.toArpa (parse "::1");
    expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa";
  };

  # ===== Comparison helpers =====
  testComparisonLe = {
    expr = ip.le (parse "1.2.3.4") (parse "1.2.3.5");
    expected = true;
  };
  testComparisonGt = {
    expr = ip.gt (parse "1.2.3.5") (parse "1.2.3.4");
    expected = true;
  };
  testComparisonGe = {
    expr = ip.ge (parse "1.2.3.5") (parse "1.2.3.4");
    expected = true;
  };

  # ===== Comparison =====
  testEqV4V4 = {
    expr = ip.eq (parse "1.2.3.4") (parse "1.2.3.4");
    expected = true;
  };
  testEqV4V6 = {
    expr = ip.eq (parse "1.2.3.4") (parse "::1");
    expected = false;
  };
  testEqV6V6 = {
    expr = ip.eq (parse "::1") (parse "::1");
    expected = true;
  };

  testCompareV4V6 = {
    expr = ip.compare (parse "255.255.255.255") (parse "::");
    expected = -1;
  }; # v4 < v6
  testCompareV6V4 = {
    expr = ip.compare (parse "::") (parse "0.0.0.0");
    expected = 1;
  };
  testCompareSameV4 = {
    expr = ip.compare (parse "1.2.3.4") (parse "1.2.3.4");
    expected = 0;
  };
  testLtCrossFamily = {
    expr = ip.lt (parse "255.255.255.255") (parse "::");
    expected = true;
  };

  testMinCrossFamily = {
    expr = ip.toString (ip.min (parse "1.2.3.4") (parse "::1"));
    expected = "1.2.3.4";
  };
  testMaxCrossFamily = {
    expr = ip.toString (ip.max (parse "1.2.3.4") (parse "::1"));
    expected = "::1";
  };

  # ===== Arithmetic dispatch =====
  testAddV4 = {
    expr = ip.toString (ip.add 1 (parse "1.2.3.4"));
    expected = "1.2.3.5";
  };
  testAddV6 = {
    expr = ip.toString (ip.add 1 (parse "::1"));
    expected = "::2";
  };
  testSubV4 = {
    expr = ip.toString (ip.sub 1 (parse "1.2.3.5"));
    expected = "1.2.3.4";
  };
  testNextV4 = {
    expr = ip.toString (ip.next (parse "1.2.3.4"));
    expected = "1.2.3.5";
  };
  testNextV6 = {
    expr = ip.toString (ip.next (parse "::1"));
    expected = "::2";
  };
  testPrevV4 = {
    expr = ip.toString (ip.prev (parse "1.2.3.5"));
    expected = "1.2.3.4";
  };
  testDiffV4 = {
    expr = ip.diff (parse "1.2.3.4") (parse "1.2.3.10");
    expected = 6;
  };
  testDiffV6 = {
    expr = ip.diff (parse "::1") (parse "::10");
    expected = 15;
  };
  testDiffCrossFamilyThrows = {
    expr = ip.diff (parse "1.2.3.4") (parse "::1");
    expectedError.msg = "^libnet\\.ip\\.diff: cross-family difference is undefined$";
  };
  testDiffV6Smallest = {
    expr = ip.diff (parse "::8000:0:0:0") (parse "::");
    expected = -9223372036854775807 - 1;
  };
  testDiffV6OutOfRangeNamesIp = {
    expr = ip.diff (parse "::") (parse "1::");
    expectedError.msg = "^libnet\\.ip\\.diff: difference out of the Nix integer range: 1:: - ::$";
  };
  testDiffRejectsNonIp = {
    expr = ip.diff (parse "::") (libnet.cidr.parse "::/0");
    expectedError.msg = "^libnet\\.ip\\.diff: expected ipv4 or ipv6 value, got cidr value$";
  };
  # Range errors name the `ip` function called, not the family's.
  testAddV4OverflowNamesIp = {
    expr = ip.add 1 (parse "255.255.255.255");
    expectedError.msg = "^libnet\\.ip\\.add: out of range: 255\\.255\\.255\\.255 \\+ 1$";
  };
  testSubV6UnderflowNamesIp = {
    expr = ip.sub 1 (parse "::");
    expectedError.msg = "^libnet\\.ip\\.sub: out of range: :: - 1$";
  };
  testNextV6OverflowNamesIp = {
    expr = ip.next (parse "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff");
    expectedError.msg = "^libnet\\.ip\\.next: out of range: ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff \\+ 1$";
  };
  testPrevV4UnderflowNamesIp = {
    expr = ip.prev (parse "0.0.0.0");
    expectedError.msg = "^libnet\\.ip\\.prev: out of range: 0\\.0\\.0\\.0 - 1$";
  };
  testAddRejectsFloatOffset = {
    expr = ip.add 1.5 (parse "::1");
    expectedError.msg = "^libnet\\.ip\\.add: expected int, got float$";
  };
  testAddV4LargestIntegerOffset = {
    expr = ip.add 9223372036854775807 (parse "0.0.0.1");
    expectedError.msg = "^libnet\\.ip\\.add: out of range: 0\\.0\\.0\\.1 \\+ 9223372036854775807$";
  };
  testSubV6SmallestIntegerOffset = {
    expr = ip.toString (ip.sub (-9223372036854775807 - 1) (parse "::"));
    expected = "::8000:0:0:0";
  };
  testSubV6 = {
    expr = ip.toString (ip.sub 1 (parse "::2"));
    expected = "::1";
  };
  testPrevV6 = {
    expr = ip.toString (ip.prev (parse "::2"));
    expected = "::1";
  };

  # ===== Non-IP input throws (dispatch / accessor guards) =====
  testToStringNonIpThrows = {
    expr = ip.toString 42;
    expectedError.msg = "^libnet\\.ip\\.toString: expected ipv4 or ipv6 value, got int$";
  };
  testVersionNonIpThrows = {
    expr = ip.version "nope";
    expectedError.msg = "^libnet\\.ip\\.version: expected ipv4 or ipv6 value, got string$";
  };
  testIsLoopbackNonIpThrows = {
    expr = ip.isLoopback 42;
    expectedError.msg = "^libnet\\.ip\\.isLoopback: expected ipv4 or ipv6 value, got int$";
  };
  testAddNonIpThrows = {
    expr = ip.add 1 "nope";
    expectedError.msg = "^libnet\\.ip\\.add: expected ipv4 or ipv6 value, got string$";
  };
  testCompareRejectsPort = {
    expr = ip.compare (parse "1.2.3.4") (libnet.port.fromInt 80);
    expectedError.msg = "^libnet\\.ip\\.compare: expected ipv4 or ipv6 value, got port value$";
  };
  testGtRejectsString = {
    expr = ip.gt "1.2.3.4" (parse "1.2.3.4");
    expectedError.msg = "^libnet\\.ip\\.gt: expected ipv4 or ipv6 value, got string$";
  };
  testMaxRejectsNull = {
    expr = ip.max (parse "::1") null;
    expectedError.msg = "^libnet\\.ip\\.max: expected ipv4 or ipv6 value, got null$";
  };
  testIsIpv4AcceptsAnyValue = {
    expr = map ip.isIpv4 [
      1
      "1.2.3.4"
      null
      { }
      (parse "::1")
    ];
    expected = [
      false
      false
      false
      false
      false
    ];
  };
  testIsIpv6AcceptsAnyValue = {
    expr = map ip.isIpv6 [
      1
      "::1"
      null
      { }
      (parse "1.2.3.4")
    ];
    expected = [
      false
      false
      false
      false
      false
    ];
  };

  # ===== Sort mixed list (stable v4-before-v6) =====
  testSortMixedFamilies = {
    expr = map ip.toString (
      builtins.sort (a: b: ip.lt a b) [
        (parse "::1")
        (parse "1.2.3.4")
        (parse "::")
        (parse "0.0.0.1")
      ]
    );
    expected = [
      "0.0.0.1"
      "1.2.3.4"
      "::"
      "::1"
    ];
  };
}
