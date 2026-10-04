{ harness }:
let
  urlHost = import ../lib/url-host.nix;
  inherit (harness) throws;
  tryParse = urlHost.tryParse;
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
    expr = (urlHost.parse "example.com").kind;
    expected = "regName";
  };
  testParseThrows = {
    expr = throws (urlHost.parse "bad host");
    expected = true;
  };

  # ===== Parse: kinds =====
  testIpv4 = {
    expr = (parseValue "1.2.3.4").kind;
    expected = "ip";
  };
  testIpv6Bracketed = {
    expr = urlHost.toString (parseValue "[::1]");
    expected = "[::1]";
  };
  testIpv6UnbracketedRejected = {
    expr = (tryParse "::1").success;
    expected = false;
  };
  testRegName = {
    expr = (parseValue "example.com").kind;
    expected = "regName";
  };
  testRegNameUnderscore = {
    expr = (parseValue "my_host").name;
    expected = "my_host";
  };
  testRegNameSubDelimiters = {
    expr = (parseValue "a+b!c").kind;
    expected = "regName";
  };
  testRegNamePercentEncoded = {
    expr = (parseValue "a%20b").kind;
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
  testIsRegNameYes = {
    expr = urlHost.isRegName (parseValue "example.com");
    expected = true;
  };

  # ===== toHost (bridge to libnet.host) =====
  testToHostIp = {
    expr = (urlHost.toHost (parseValue "1.2.3.4"))._type;
    expected = "ipv4";
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
  testEqCrossKind = {
    expr = urlHost.eq (parseValue "1.2.3.4") (parseValue "example.com");
    expected = false;
  };
  testCompareIpBeforeRegName = {
    expr = urlHost.compare (parseValue "1.2.3.4") (parseValue "example.com");
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
