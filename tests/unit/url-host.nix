{ helpers, libnet, ... }:
let
  inherit (libnet) urlHost;
  inherit (helpers) throws;
  inherit (urlHost) tryParse;
  parseValue = input: (urlHost.tryParse input).value;
in
{
  # ===== tryParse: standard record =====
  testTryParseOkSuccess = {
    expr = (tryParse "example.com").success;
    expected = true;
  };
  testTryParseBadSuccess = {
    expr = (tryParse "bad host").success;
    expected = false;
  };
  testTryParseErrorString = {
    expr = builtins.isString (tryParse "bad host").error;
    expected = true;
  };
  testParseOk = {
    expr = urlHost.parse "example.com";
    expected = libnet.regName.parse "example.com";
  };
  testParseThrows = {
    expr = throws (urlHost.parse "bad host");
    expected = true;
  };

  # ===== Parse: kinds =====
  testIpv4 = {
    expr = parseValue "1.2.3.4";
    expected = libnet.ipv4.parse "1.2.3.4";
  };
  testIpv6Bracketed = {
    expr = parseValue "[::1]";
    expected = libnet.ipv6.parse "::1";
  };
  testIpv6BracketedRoundTrip = {
    expr = urlHost.toString (parseValue "[2001:db8::1]");
    expected = "[2001:db8::1]";
  };
  # A dotted quad is an IPv4 address, not a four-label registered name.
  testDottedQuadIsIp = {
    expr = (parseValue "192.0.2.1")._type;
    expected = "ipv4";
  };
  testIpv6UnbracketedRejected = {
    expr = (tryParse "::1").success;
    expected = false;
  };
  testRegName = {
    expr = parseValue "example.com";
    expected = {
      _type = "regName";
      value = "example.com";
    };
  };
  testRegNameUnderscore = {
    expr = urlHost.toString (parseValue "my_host");
    expected = "my_host";
  };
  testRegNameSubDelimiters = {
    expr = (parseValue "a+b!c")._type;
    expected = "regName";
  };
  testRegNamePercentEncoded = {
    expr = (parseValue "a%20b")._type;
    expected = "regName";
  };
  # Not a valid IPv4 address, so the registered-name grammar applies.
  testOutOfRangeQuadIsRegName = {
    expr = (parseValue "256.0.0.1")._type;
    expected = "regName";
  };

  # ===== Reject =====
  testRejectEmpty = {
    expr = (tryParse "").success;
    expected = false;
  };
  testRejectSpace = {
    expr = (tryParse "bad host").success;
    expected = false;
  };
  testRejectBadBracket = {
    expr = (tryParse "[::xyz]").success;
    expected = false;
  };
  testRejectUnclosedBracket = {
    expr = (tryParse "[::1").success;
    expected = false;
  };

  # ===== toString / predicates =====
  testToStringRegNamePreservesCase = {
    expr = urlHost.toString (parseValue "Example.COM");
    expected = "Example.COM";
  };
  testToStringIpv4 = {
    expr = urlHost.toString (parseValue "1.2.3.4");
    expected = "1.2.3.4";
  };
  testToStringBracketsIpv6Value = {
    expr = urlHost.toString (libnet.ipv6.parse "fe80::1");
    expected = "[fe80::1]";
  };
  testToStringRejectsDomain = {
    expr = throws (urlHost.toString (libnet.domain.parse "example.com"));
    expected = true;
  };
  testIsValidOk = {
    expr = urlHost.isValid "example.com";
    expected = true;
  };
  testIsValidBad = {
    expr = urlHost.isValid "bad host";
    expected = false;
  };
  testIsYes = {
    expr = urlHost.is (parseValue "1.2.3.4");
    expected = true;
  };
  testIsIpv6Value = {
    expr = urlHost.is (libnet.ipv6.parse "::1");
    expected = true;
  };
  testIsRegNameValue = {
    expr = urlHost.is (libnet.regName.parse "my_host");
    expected = true;
  };
  testIsDomainNo = {
    expr = urlHost.is (libnet.domain.parse "example.com");
    expected = false;
  };
  testIsNo = {
    expr = urlHost.is "x";
    expected = false;
  };
  testIsIpYes = {
    expr = urlHost.isIp (parseValue "1.2.3.4");
    expected = true;
  };
  testIsIpNo = {
    expr = urlHost.isIp (parseValue "example.com");
    expected = false;
  };
  testIsIpIpv6 = {
    expr = urlHost.isIp (parseValue "[::1]");
    expected = true;
  };
  testIsRegNameYes = {
    expr = urlHost.isRegName (parseValue "example.com");
    expected = true;
  };
  testIsRegNameNo = {
    expr = urlHost.isRegName (parseValue "1.2.3.4");
    expected = false;
  };

  # ===== toHost (bridge to libnet.host) =====
  testToHostIp = {
    expr = urlHost.toHost (parseValue "1.2.3.4");
    expected = libnet.ipv4.parse "1.2.3.4";
  };
  testToHostHostname = {
    expr = (urlHost.toHost (parseValue "nas"))._type;
    expected = "hostname";
  };
  testToHostDomain = {
    expr = (urlHost.toHost (parseValue "example.com"))._type;
    expected = "domain";
  };
  testToHostUnderscoreNull = {
    expr = urlHost.toHost (parseValue "my_host") == null;
    expected = true;
  };

  # ===== Comparison =====
  testEqIp = {
    expr = urlHost.eq (parseValue "1.2.3.4") (parseValue "1.2.3.4");
    expected = true;
  };
  testEqRegNameCaseInsensitive = {
    expr = urlHost.eq (parseValue "Example.COM") (parseValue "example.com");
    expected = true;
  };
  testEqIpv6 = {
    expr = urlHost.eq (parseValue "[::1]") (parseValue "[0::1]");
    expected = true;
  };
  testEqCrossKind = {
    expr = urlHost.eq (parseValue "1.2.3.4") (parseValue "example.com");
    expected = false;
  };
  testEqCrossFamily = {
    expr = urlHost.eq (parseValue "0.0.0.1") (parseValue "[::1]");
    expected = false;
  };
  testEqRegNameVsDomain = {
    expr = urlHost.eq (parseValue "example.com") (libnet.domain.parse "example.com");
    expected = false;
  };
  testCompareIpBeforeRegName = {
    expr = urlHost.compare (parseValue "1.2.3.4") (parseValue "example.com");
    expected = -1;
  };
  testCompareRegNameAfterIpv6 = {
    expr = urlHost.compare (parseValue "a") (parseValue "[::1]");
    expected = 1;
  };
  testCompareIpv4BeforeIpv6 = {
    expr = urlHost.compare (parseValue "255.255.255.255") (parseValue "[::]");
    expected = -1;
  };
  testCompareRegNameOrder = {
    expr = urlHost.compare (parseValue "alpha.com") (parseValue "beta.com");
    expected = -1;
  };
  testCompareCaseInsensitiveEqual = {
    expr = urlHost.compare (parseValue "Example.COM") (parseValue "example.com");
    expected = 0;
  };
  testLt = {
    expr = urlHost.lt (parseValue "alpha.com") (parseValue "beta.com");
    expected = true;
  };
  testLe = {
    expr = urlHost.le (parseValue "alpha.com") (parseValue "beta.com");
    expected = true;
  };
  testGt = {
    expr = urlHost.gt (parseValue "beta.com") (parseValue "alpha.com");
    expected = true;
  };
  testGe = {
    expr = urlHost.ge (parseValue "beta.com") (parseValue "alpha.com");
    expected = true;
  };
  testMin = {
    expr = urlHost.toString (urlHost.min (parseValue "alpha.com") (parseValue "beta.com"));
    expected = "alpha.com";
  };
  testMax = {
    expr = urlHost.toString (urlHost.max (parseValue "alpha.com") (parseValue "beta.com"));
    expected = "beta.com";
  };
}
