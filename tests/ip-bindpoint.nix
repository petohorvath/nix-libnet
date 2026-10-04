{ harness }:
let
  ipBindpoint = import ../lib/ip-bindpoint.nix;
  ipv4 = import ../lib/ipv4.nix;
  portRange = import ../lib/port-range.nix;
  ipEndpoint = import ../lib/ip-endpoint.nix;
  inherit (harness) throws;
  parse = ipBindpoint.parse;
in
{
  # ===== Parse =====
  testParseNullSingle = {
    expr = ipBindpoint.toString (parse ":8080");
    expected = ":8080";
  };
  testParseNullRange = {
    expr = ipBindpoint.toString (parse ":8080-8090");
    expected = ":8080-8090";
  };
  testParseWildcardStar = {
    expr = ipBindpoint.toString (parse "*:8080");
    expected = ":8080";
  };
  testParseWildcardAny = {
    expr = ipBindpoint.toString (parse "any:8080");
    expected = ":8080";
  };
  testParseV4Single = {
    expr = ipBindpoint.toString (parse "1.2.3.4:8080");
    expected = "1.2.3.4:8080";
  };
  testParseV4Range = {
    expr = ipBindpoint.toString (parse "1.2.3.4:5000-6000");
    expected = "1.2.3.4:5000-6000";
  };
  testParseV4Explicit = {
    expr = ipBindpoint.toString (parse "0.0.0.0:80");
    expected = "0.0.0.0:80";
  };
  testParseV6Range = {
    expr = ipBindpoint.toString (parse "[::1]:5000-6000");
    expected = "[::1]:5000-6000";
  };
  testParseV6Explicit = {
    expr = ipBindpoint.toString (parse "[::]:80");
    expected = "[::]:80";
  };
  testParseV6Single = {
    expr = ipBindpoint.toString (parse "[::1]:80");
    expected = "[::1]:80";
  };

  # ===== Reject =====
  testRejectUnbracketedV6 = {
    expr = throws (parse "::1:80");
    expected = true;
  };
  testRejectBadPort = {
    expr = throws (parse ":70000");
    expected = true;
  };
  testRejectOpenRange = {
    expr = throws (parse "1.2.3.4:5500-");
    expected = true;
  };
  testRejectReversedRange = {
    expr = throws (parse "1.2.3.4:6000-5500");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (ipBindpoint.parse 123);
    expected = true;
  };

  # ===== tryParse =====
  testTryParseOk = {
    expr = (ipBindpoint.tryParse ":80").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (ipBindpoint.tryParse "bad").success;
    expected = false;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = ipBindpoint.is (parse ":80");
    expected = true;
  };
  testIsString = {
    expr = ipBindpoint.is ":80";
    expected = false;
  };
  testIsValidOk = {
    expr = ipBindpoint.isValid ":80";
    expected = true;
  };

  # ===== isAnyAddress variants =====
  testIsAnyAddressNull = {
    expr = ipBindpoint.isAnyAddress (parse ":80");
    expected = true;
  };
  testIsAnyAddressStar = {
    expr = ipBindpoint.isAnyAddress (parse "*:80");
    expected = true;
  };
  testIsAnyAddressAny = {
    expr = ipBindpoint.isAnyAddress (parse "any:80");
    expected = true;
  };
  testIsAnyAddressV4Unspecified = {
    expr = ipBindpoint.isAnyAddress (parse "0.0.0.0:80");
    expected = true;
  };
  testIsAnyAddressV6Unspecified = {
    expr = ipBindpoint.isAnyAddress (parse "[::]:80");
    expected = true;
  };
  testIsAnyAddressNo = {
    expr = ipBindpoint.isAnyAddress (parse "1.2.3.4:80");
    expected = false;
  };
  testIsAnyAddressV6Loopback = {
    expr = ipBindpoint.isAnyAddress (parse "[::1]:80");
    expected = false;
  };
  testIsWildcardAlias = {
    expr = ipBindpoint.isWildcard (parse ":80");
    expected = true;
  };

  # ===== isRange =====
  testIsRangeSingle = {
    expr = ipBindpoint.isRange (parse ":80");
    expected = false;
  };
  testIsRangeRange = {
    expr = ipBindpoint.isRange (parse ":80-90");
    expected = true;
  };

  # ===== Family =====
  testIsIpv4V4 = {
    expr = ipBindpoint.isIpv4 (parse "1.2.3.4:80");
    expected = true;
  };
  testIsIpv4Null = {
    expr = ipBindpoint.isIpv4 (parse ":80");
    expected = false;
  };
  testIsIpv6V6 = {
    expr = ipBindpoint.isIpv6 (parse "[::1]:80");
    expected = true;
  };
  testVersionV4 = {
    expr = ipBindpoint.version (parse "1.2.3.4:80");
    expected = 4;
  };
  testVersionNull = {
    expr = ipBindpoint.version (parse ":80");
    expected = null;
  };

  # ===== Expansion =====
  testEndpoints = {
    expr = map ipEndpoint.toString (ipBindpoint.endpoints (parse "1.2.3.4:80-82"));
    expected = [
      "1.2.3.4:80"
      "1.2.3.4:81"
      "1.2.3.4:82"
    ];
  };
  testEndpointsV6 = {
    expr = map ipEndpoint.toString (ipBindpoint.endpoints (parse "[::1]:80-81"));
    expected = [
      "[::1]:80"
      "[::1]:81"
    ];
  };
  testEndpointsNull = {
    expr = throws (ipBindpoint.endpoints (parse ":80-82"));
    expected = true;
  };
  testEndpointsTooLarge = {
    expr = throws (ipBindpoint.endpoints (parse "1.2.3.4:0-5000"));
    expected = true;
  };

  testEndpointAt0 = {
    expr = ipEndpoint.toString (ipBindpoint.endpointAt 0 (parse "1.2.3.4:80-82"));
    expected = "1.2.3.4:80";
  };
  testEndpointAt2 = {
    expr = ipEndpoint.toString (ipBindpoint.endpointAt 2 (parse "1.2.3.4:80-82"));
    expected = "1.2.3.4:82";
  };
  testEndpointAtNegative = {
    expr = ipEndpoint.toString (ipBindpoint.endpointAt (-1) (parse "1.2.3.4:80-82"));
    expected = "1.2.3.4:82";
  };
  testEndpointAtOutOfRange = {
    expr = throws (ipBindpoint.endpointAt 3 (parse "1.2.3.4:80-82"));
    expected = true;
  };
  testEndpointAtNull = {
    expr = throws (ipBindpoint.endpointAt 0 (parse ":80-82"));
    expected = true;
  };

  # ===== Forwarded predicates =====
  testForwardedLoopbackV4 = {
    expr = ipBindpoint.isLoopback (parse "127.0.0.1:80");
    expected = true;
  };
  testForwardedLoopbackV6 = {
    expr = ipBindpoint.isLoopback (parse "[::1]:80");
    expected = true;
  };
  testForwardedLoopbackNo = {
    expr = ipBindpoint.isLoopback (parse "8.8.8.8:80");
    expected = false;
  };
  testForwardedLoopbackNull = {
    expr = ipBindpoint.isLoopback (parse ":80");
    expected = false;
  };
  testForwardedUnspecifiedNull = {
    expr = ipBindpoint.isUnspecified (parse ":80");
    expected = false;
  };
  testForwardedLinkLocalV6 = {
    expr = ipBindpoint.isLinkLocal (parse "[fe80::1]:80");
    expected = true;
  };
  testForwardedMulticastV4 = {
    expr = ipBindpoint.isMulticast (parse "224.0.0.1:80");
    expected = true;
  };
  testForwardedDocumentationV4 = {
    expr = ipBindpoint.isDocumentation (parse "192.0.2.1:80");
    expected = true;
  };
  testForwardedGlobalV4 = {
    expr = ipBindpoint.isGlobal (parse "8.8.8.8:80");
    expected = true;
  };
  testForwardedGlobalNull = {
    expr = ipBindpoint.isGlobal (parse ":80");
    expected = false;
  };
  testForwardedBogonV4 = {
    expr = ipBindpoint.isBogon (parse "10.0.0.1:80");
    expected = true;
  };
  testForwardedBogonV6 = {
    expr = ipBindpoint.isBogon (parse "[fc00::1]:80");
    expected = true;
  };
  testForwardedBogonNull = {
    expr = ipBindpoint.isBogon (parse ":80");
    expected = false;
  };
  testForwardedToArpaV4 = {
    expr = ipBindpoint.toArpa (parse "1.2.3.4:80");
    expected = "4.3.2.1.in-addr.arpa";
  };
  testForwardedToArpaV6 = {
    expr = ipBindpoint.toArpa (parse "[::1]:80");
    expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa";
  };
  testForwardedToArpaNull = {
    expr = throws (ipBindpoint.toArpa (parse ":80"));
    expected = true;
  };

  # ===== make / accessors / unbounded expansion =====
  testMakeOk = {
    expr = ipBindpoint.toString (ipBindpoint.make (ipv4.parse "1.2.3.4") (portRange.make 80 82));
    expected = "1.2.3.4:80-82";
  };
  testMakeNullAddress = {
    expr = ipBindpoint.toString (ipBindpoint.make null (portRange.make 80 80));
    expected = ":80";
  };
  testMakeBadAddress = {
    expr = throws (ipBindpoint.make "1.2.3.4" (portRange.make 80 80));
    expected = true;
  };
  testMakeBadPortRange = {
    expr = throws (ipBindpoint.make (ipv4.parse "1.2.3.4") 80);
    expected = true;
  };
  testEndpointsUnboundedLength = {
    expr = builtins.length (ipBindpoint.endpointsUnbounded (parse "1.2.3.4:0-5000"));
    expected = 5001;
  };
  testAddressAccessor = {
    expr = ipv4.toString (ipBindpoint.address (parse "1.2.3.4:80"));
    expected = "1.2.3.4";
  };
  testAddressNull = {
    expr = ipBindpoint.address (parse ":80");
    expected = null;
  };
  testPortRangeAccessor = {
    expr = portRange.toString (ipBindpoint.portRange (parse "1.2.3.4:80-90"));
    expected = "80-90";
  };

  # ===== Comparison helpers =====
  testCompareLe = {
    expr = ipBindpoint.le (parse ":80") (parse ":81");
    expected = true;
  };
  testCompareGt = {
    expr = ipBindpoint.gt (parse ":81") (parse ":80");
    expected = true;
  };
  testCompareGe = {
    expr = ipBindpoint.ge (parse ":81") (parse ":80");
    expected = true;
  };
  testCompareMin = {
    expr = ipBindpoint.toString (ipBindpoint.min (parse ":80") (parse ":81"));
    expected = ":80";
  };
  testCompareMax = {
    expr = ipBindpoint.toString (ipBindpoint.max (parse ":80") (parse ":81"));
    expected = ":81";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = ipBindpoint.eq (parse ":80") (parse ":80");
    expected = true;
  };
  testEqNullVsExplicit = {
    expr = ipBindpoint.eq (parse ":80") (parse "0.0.0.0:80");
    expected = false;
  };
  testCompareNullV4 = {
    expr = ipBindpoint.compare (parse ":80") (parse "0.0.0.0:80");
    expected = -1;
  };
  testCompareV4V6 = {
    expr = ipBindpoint.compare (parse "1.2.3.4:80") (parse "[::1]:80");
    expected = -1;
  };
  testCompareSame = {
    expr = ipBindpoint.compare (parse ":80") (parse ":80");
    expected = 0;
  };
  testLtNullFirst = {
    expr = ipBindpoint.lt (parse ":80") (parse "0.0.0.0:80");
    expected = true;
  };
}
