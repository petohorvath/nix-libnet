{ harness }:
let
  ipEndpoint = import ../lib/ip-endpoint.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  port = import ../lib/port.nix;
  inherit (harness) throws;
  parse = ipEndpoint.parse;
in
{
  # ===== Parse =====
  testParseV4 = {
    expr = ipEndpoint.toString (parse "1.2.3.4:80");
    expected = "1.2.3.4:80";
  };
  testParseV6 = {
    expr = ipEndpoint.toString (parse "[::1]:80");
    expected = "[::1]:80";
  };
  testParseV6Documentation = {
    expr = ipEndpoint.toString (parse "[2001:db8::1]:443");
    expected = "[2001:db8::1]:443";
  };
  testParseV4MaxPort = {
    expr = ipEndpoint.toString (parse "1.2.3.4:65535");
    expected = "1.2.3.4:65535";
  };
  testParseV4Port0 = {
    expr = ipEndpoint.toString (parse "1.2.3.4:0");
    expected = "1.2.3.4:0";
  };

  # ===== Reject =====
  testRejectUnbracketedV6 = {
    expr = throws (parse "::1:80");
    expected = true;
  };
  testRejectNoPort = {
    expr = throws (parse "1.2.3.4");
    expected = true;
  };
  testRejectBracketedV4 = {
    expr = throws (parse "[1.2.3.4]:80");
    expected = true;
  };
  testRejectEmptyPort = {
    expr = throws (parse "1.2.3.4:");
    expected = true;
  };
  testRejectNoAddress = {
    expr = throws (parse ":80");
    expected = true;
  };
  testRejectPortOutOfRange = {
    expr = throws (parse "1.2.3.4:70000");
    expected = true;
  };
  testRejectBadV6 = {
    expr = throws (parse "[:::1]:80");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (ipEndpoint.parse 123);
    expected = true;
  };

  # ===== tryParse =====
  testTryParseOk = {
    expr = (ipEndpoint.tryParse "1.2.3.4:80").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (ipEndpoint.tryParse "bad").success;
    expected = false;
  };

  # ===== Round-trip =====
  testRoundTripV4 = {
    expr = ipEndpoint.toString (parse (ipEndpoint.toString (parse "1.2.3.4:80")));
    expected = "1.2.3.4:80";
  };
  testRoundTripV6 = {
    expr = ipEndpoint.toString (parse (ipEndpoint.toString (parse "[::1]:80")));
    expected = "[::1]:80";
  };

  # ===== make / accessors =====
  testMakeV4 = {
    expr = ipEndpoint.toString (ipEndpoint.make (ipv4.parse "1.2.3.4") (port.fromInt 80));
    expected = "1.2.3.4:80";
  };
  testMakeV6 = {
    expr = ipEndpoint.toString (ipEndpoint.make (ipv6.parse "::1") (port.fromInt 443));
    expected = "[::1]:443";
  };
  testAddressAccessor = {
    expr = ipv4.toString (ipEndpoint.address (parse "1.2.3.4:80"));
    expected = "1.2.3.4";
  };
  testPortAccessor = {
    expr = port.toInt (ipEndpoint.port (parse "1.2.3.4:80"));
    expected = 80;
  };
  testVersionV4 = {
    expr = ipEndpoint.version (parse "1.2.3.4:80");
    expected = 4;
  };
  testVersionV6 = {
    expr = ipEndpoint.version (parse "[::1]:80");
    expected = 6;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = ipEndpoint.is (parse "1.2.3.4:80");
    expected = true;
  };
  testIsString = {
    expr = ipEndpoint.is "1.2.3.4:80";
    expected = false;
  };
  testIsIpv4V4 = {
    expr = ipEndpoint.isIpv4 (parse "1.2.3.4:80");
    expected = true;
  };
  testIsIpv6V6 = {
    expr = ipEndpoint.isIpv6 (parse "[::1]:80");
    expected = true;
  };
  testIsValidOk = {
    expr = ipEndpoint.isValid "1.2.3.4:80";
    expected = true;
  };
  testIsValidBad = {
    expr = ipEndpoint.isValid "bad";
    expected = false;
  };

  # ===== Forwarded predicates =====
  testForwardedLoopbackV4 = {
    expr = ipEndpoint.isLoopback (parse "127.0.0.1:80");
    expected = true;
  };
  testForwardedLoopbackV6 = {
    expr = ipEndpoint.isLoopback (parse "[::1]:80");
    expected = true;
  };
  testForwardedLoopbackNo = {
    expr = ipEndpoint.isLoopback (parse "8.8.8.8:80");
    expected = false;
  };
  testForwardedGlobalV4 = {
    expr = ipEndpoint.isGlobal (parse "8.8.8.8:80");
    expected = true;
  };
  testForwardedLinkLocalV6 = {
    expr = ipEndpoint.isLinkLocal (parse "[fe80::1]:80");
    expected = true;
  };
  testForwardedBogonV4 = {
    expr = ipEndpoint.isBogon (parse "10.0.0.1:80");
    expected = true;
  };
  testForwardedBogonV6 = {
    expr = ipEndpoint.isBogon (parse "[fc00::1]:80");
    expected = true;
  };
  testForwardedBogonNo = {
    expr = ipEndpoint.isBogon (parse "8.8.8.8:80");
    expected = false;
  };
  testForwardedToArpaV4 = {
    expr = ipEndpoint.toArpa (parse "1.2.3.4:80");
    expected = "4.3.2.1.in-addr.arpa";
  };
  testForwardedToArpaV6 = {
    expr = ipEndpoint.toArpa (parse "[::1]:80");
    expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa";
  };

  testForwardedUnspecifiedV4 = {
    expr = ipEndpoint.isUnspecified (parse "0.0.0.0:80");
    expected = true;
  };
  testForwardedMulticastV4 = {
    expr = ipEndpoint.isMulticast (parse "224.0.0.1:80");
    expected = true;
  };
  testForwardedDocumentationV4 = {
    expr = ipEndpoint.isDocumentation (parse "192.0.2.1:80");
    expected = true;
  };

  # ===== Comparison helpers =====
  testCompareLe = {
    expr = ipEndpoint.le (parse "1.2.3.4:80") (parse "1.2.3.4:81");
    expected = true;
  };
  testCompareGt = {
    expr = ipEndpoint.gt (parse "1.2.3.4:81") (parse "1.2.3.4:80");
    expected = true;
  };
  testCompareGe = {
    expr = ipEndpoint.ge (parse "1.2.3.4:81") (parse "1.2.3.4:80");
    expected = true;
  };
  testCompareMax = {
    expr = ipEndpoint.toString (ipEndpoint.max (parse "1.2.3.4:80") (parse "1.2.3.4:81"));
    expected = "1.2.3.4:81";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = ipEndpoint.eq (parse "1.2.3.4:80") (parse "1.2.3.4:80");
    expected = true;
  };
  testEqDifferentPort = {
    expr = ipEndpoint.eq (parse "1.2.3.4:80") (parse "1.2.3.4:81");
    expected = false;
  };
  testEqDifferentAddress = {
    expr = ipEndpoint.eq (parse "1.2.3.4:80") (parse "1.2.3.5:80");
    expected = false;
  };
  testEqCrossFamily = {
    expr = ipEndpoint.eq (parse "1.2.3.4:80") (parse "[::1]:80");
    expected = false;
  };

  testCompareV4V6 = {
    expr = ipEndpoint.compare (parse "1.2.3.4:80") (parse "[::1]:80");
    expected = -1;
  };
  testCompareSame = {
    expr = ipEndpoint.compare (parse "1.2.3.4:80") (parse "1.2.3.4:80");
    expected = 0;
  };
  testCompareAddress = {
    expr = ipEndpoint.compare (parse "1.2.3.4:80") (parse "1.2.3.5:80");
    expected = -1;
  };
  testComparePort = {
    expr = ipEndpoint.compare (parse "1.2.3.4:80") (parse "1.2.3.4:81");
    expected = -1;
  };
  testLtYes = {
    expr = ipEndpoint.lt (parse "1.2.3.4:80") (parse "1.2.3.4:81");
    expected = true;
  };
  testMinSmaller = {
    expr = ipEndpoint.toString (ipEndpoint.min (parse "1.2.3.4:80") (parse "1.2.3.4:81"));
    expected = "1.2.3.4:80";
  };
}
