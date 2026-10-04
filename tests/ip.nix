{ harness }:
let
  ip = import ../lib/ip.nix;
  inherit (harness) throws;
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
    expr = throws (parse "bogus");
    expected = true;
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
    expr = throws (ip.diff (parse "1.2.3.4") (parse "::1"));
    expected = true;
  };

  # ===== Non-IP input throws (dispatch / accessor guards) =====
  testToStringNonIpThrows = {
    expr = throws (ip.toString 42);
    expected = true;
  };
  testVersionNonIpThrows = {
    expr = throws (ip.version "nope");
    expected = true;
  };
  testIsLoopbackNonIpThrows = {
    expr = throws (ip.isLoopback 42);
    expected = true;
  };
  testAddNonIpThrows = {
    expr = throws (ip.add 1 "nope");
    expected = true;
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
