{ helpers, libnet, ... }:
let
  inherit (libnet)
    domain
    host
    hostname
    ip
    ;
  inherit (helpers) throws;
  inherit (host) parse;
in
{
  # ===== Dispatch =====
  testParseIpv4Tagged = {
    expr = (parse "192.168.1.1")._type;
    expected = "ipv4";
  };
  testParseIpv6Tagged = {
    expr = (parse "::1")._type;
    expected = "ipv6";
  };
  testParseHostnameTagged = {
    expr = (parse "nas")._type;
    expected = "hostname";
  };
  testParseHostnameFoldsCase = {
    expr = parse "MyHost";
    expected = hostname.parse "myhost";
  };
  testParseDomainFoldsCase = {
    expr = parse "Example.COM";
    expected = domain.parse "example.com";
  };
  testParseDomainTagged = {
    expr = (parse "example.com")._type;
    expected = "domain";
  };
  testParseDeepDomainTagged = {
    expr = (parse "a.b.c.example.com")._type;
    expected = "domain";
  };
  # Dispatch order: IP wins over domain for dotted-quad strings.
  testParseDottedQuadAsIp = {
    expr = (parse "10.0.0.1")._type;
    expected = "ipv4";
  };
  testParseIpv4Value = {
    expr = ip.toString (parse "192.168.1.1");
    expected = "192.168.1.1";
  };
  testParseHostnameValue = {
    expr = (parse "nas").value;
    expected = "nas";
  };
  testParseDomainValue = {
    expr = (parse "example.com").value;
    expected = "example.com";
  };

  # ===== Reject =====
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectUnderscore = {
    expr = throws (parse "host_name");
    expected = true;
  };
  testRejectTrailingDot = {
    expr = throws (parse "example.com.");
    expected = true;
  };
  testRejectLeadingDot = {
    expr = throws (parse ".example.com");
    expected = true;
  };
  testRejectWhitespace = {
    expr = throws (parse "my host");
    expected = true;
  };
  testRejectNotString = {
    expr = host.parse 42;
    expectedError.msg = "^libnet\\.host\\.parse: expected string, got int$";
  };
  # Not an `ip`, yet `inet_aton` reads each as an address (ADR 0021).
  testRejectLeadingZeroQuad = {
    expr = parse "010.0.0.1";
    expectedError.msg = "^libnet\\.host\\.parse: invalid octet in \"010\\.0\\.0\\.1\"$";
  };
  testRejectShortQuad = {
    expr = parse "127.1";
    expectedError.msg = "^libnet\\.host\\.parse: must have 4 octets, got 2: \"127\\.1\"$";
  };
  testRejectHexQuadKeepsNameDetail = {
    expr = parse "0x7f.0.0.1";
    expectedError.msg = "^libnet\\.host\\.parse: \"0x7f\\.0\\.0\\.1\" reads as an IPv4 address, not a DNS name$";
  };
  testRejectBadIpv6KeepsDetail = {
    expr = parse "::g";
    expectedError.msg = "^libnet\\.host\\.parse: invalid group \"g\" in \"::g\"$";
  };
  # No DNS name holds a colon or brackets, so the error names the syntax
  # the text belongs to.
  testRejectNameWithPort = {
    expr = parse "example.com:80";
    expectedError.msg = "^libnet\\.host\\.parse: \"example\\.com:80\" reads as host:port, which is endpoint syntax$";
  };
  testRejectBracketed = {
    expr = parse "[::1]";
    expectedError.msg = "^libnet\\.host\\.parse: \"\\[::1]\" is bracketed, which is URL and endpoint syntax$";
  };
  testRejectNumericHostname = {
    expr = map host.isValid [
      "2130706433"
      "0x7f"
      "0x7f.0.0.1"
    ];
    expected = [
      false
      false
      false
    ];
  };
  testRejectInvalidNamesHost = {
    expr = parse "host_name";
    expectedError.msg = "^libnet\\.host\\.parse: invalid hostname \"host_name\" \\(expected ";
  };

  testTryParseOkIp = {
    expr = (host.tryParse "192.168.1.1").success;
    expected = true;
  };
  testTryParseOkHostname = {
    expr = (host.tryParse "nas").success;
    expected = true;
  };
  testTryParseOkDomain = {
    expr = (host.tryParse "example.com").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (host.tryParse "host_name").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = (host.tryParse "host_name").error;
    expected = "libnet.host.parse: invalid hostname \"host_name\" (expected 1-63 ASCII alphanumerics or hyphens, starting and ending with alphanumeric)";
  };
  # Text with a colon or only digits and dots keeps the IP's detail.
  testTryParseColonKeepsIpDetail = {
    expr = (host.tryParse "nas::g").error;
    expected = "libnet.host.parse: invalid group \"nas\" in \"nas::g\"";
  };
  testTryParseDottedDigitsKeepsIpDetail = {
    expr = (host.tryParse "1.2.3.256").error;
    expected = "libnet.host.parse: invalid octet in \"1.2.3.256\"";
  };

  # ===== toString (dispatches) =====
  testToStringIpv4 = {
    expr = host.toString (parse "192.168.1.1");
    expected = "192.168.1.1";
  };
  testToStringIpv6 = {
    expr = host.toString (parse "::1");
    expected = "::1";
  };
  testToStringHostname = {
    expr = host.toString (parse "nas");
    expected = "nas";
  };
  testToStringDomain = {
    expr = host.toString (parse "example.com");
    expected = "example.com";
  };
  testToStringHostnameLowercase = {
    expr = host.toString (parse "MyHost");
    expected = "myhost";
  };
  testToStringUntaggedThrows = {
    expr = host.toString { value = "nope"; };
    expectedError.msg = "^libnet\\.host\\.toString: expected ip, hostname or domain value, got set$";
  };

  # ===== Predicates =====
  testIsIp = {
    expr = host.is (parse "192.168.1.1");
    expected = true;
  };
  testIsHostname = {
    expr = host.is (parse "nas");
    expected = true;
  };
  testIsDomain = {
    expr = host.is (parse "example.com");
    expected = true;
  };
  testIsString = {
    expr = host.is "nas";
    expected = false;
  };
  testIsUntagged = {
    expr = host.is { value = "nas"; };
    expected = false;
  };

  testIsIpIp = {
    expr = host.isIp (parse "10.0.0.1");
    expected = true;
  };
  testIsIpHostname = {
    expr = host.isIp (parse "nas");
    expected = false;
  };
  testIsIpDomain = {
    expr = host.isIp (parse "example.com");
    expected = false;
  };

  testIsDnsNameHostname = {
    expr = host.isDnsName (parse "nas");
    expected = true;
  };
  testIsDnsNameDomain = {
    expr = host.isDnsName (parse "example.com");
    expected = true;
  };
  # `hostname.parse` accepts a numeric label, which no DNS name is
  # (ADR 0021).
  testIsDnsNameNumericHostname = {
    expr = host.isDnsName (hostname.parse "1234");
    expected = false;
  };
  testIsNumericHostname = {
    expr = host.is (hostname.parse "0x7f");
    expected = false;
  };
  testToStringRejectsNumericHostname = {
    expr = host.toString (hostname.parse "1234");
    expectedError.msg = "^libnet\\.host\\.toString: expected ip, hostname or domain value, got numeric hostname \"1234\", which reads as an IPv4 address$";
  };
  testIsDnsNameIp = {
    expr = host.isDnsName (parse "10.0.0.1");
    expected = false;
  };

  testIsValidIp = {
    expr = host.isValid "192.168.1.1";
    expected = true;
  };
  testIsValidHostname = {
    expr = host.isValid "nas";
    expected = true;
  };
  testIsValidDomain = {
    expr = host.isValid "example.com";
    expected = true;
  };
  testIsValidBad = {
    expr = host.isValid "host_name";
    expected = false;
  };
  testIsValidNotString = {
    expr = host.isValid 42;
    expected = false;
  };

  # ===== eq =====
  testEqSameIpv4 = {
    expr = host.eq (parse "10.0.0.1") (parse "10.0.0.1");
    expected = true;
  };
  testEqSameHostname = {
    expr = host.eq (parse "nas") (parse "nas");
    expected = true;
  };
  testEqSameDomain = {
    expr = host.eq (parse "example.com") (parse "example.com");
    expected = true;
  };
  testEqHostnameCaseInsensitive = {
    expr = host.eq (parse "NAS") (parse "nas");
    expected = true;
  };
  testEqDomainCaseInsensitive = {
    expr = host.eq (parse "EXAMPLE.COM") (parse "example.com");
    expected = true;
  };
  testEqIpVsHostname = {
    expr = host.eq (parse "10.0.0.1") (parse "nas");
    expected = false;
  };
  testEqHostnameVsDomain = {
    expr = host.eq (parse "nas") (parse "example.com");
    expected = false;
  };
  testEqIpv4VsIpv6 = {
    expr = host.eq (parse "0.0.0.0") (parse "::");
    expected = false;
  };
  testEqUntagged = {
    expr = host.eq (parse "nas") { value = "nas"; };
    expected = false;
  };

  # ===== compare =====
  testCompareIpBeforeHostname = {
    expr = host.compare (parse "10.0.0.1") (parse "nas");
    expected = -1;
  };
  testCompareHostnameBeforeDomain = {
    expr = host.compare (parse "nas") (parse "example.com");
    expected = -1;
  };
  testCompareDomainAfterIp = {
    expr = host.compare (parse "example.com") (parse "10.0.0.1");
    expected = 1;
  };
  testCompareIpv4BeforeIpv6 = {
    expr = host.compare (parse "10.0.0.1") (parse "::1");
    expected = -1;
  };
  testCompareSameIpv4Equal = {
    expr = host.compare (parse "10.0.0.1") (parse "10.0.0.1");
    expected = 0;
  };
  testCompareSameHostnameCase = {
    expr = host.compare (parse "NAS") (parse "nas");
    expected = 0;
  };
  testCompareSameDomainCase = {
    expr = host.compare (parse "EXAMPLE.COM") (parse "example.com");
    expected = 0;
  };
  testCompareWithinHostnameLexical = {
    expr = host.compare (parse "alpha") (parse "beta");
    expected = -1;
  };
  testCompareWithinDomainLexical = {
    expr = host.compare (parse "alpha.com") (parse "beta.com");
    expected = -1;
  };
  testCompareWithinIpv4 = {
    expr = host.compare (parse "10.0.0.1") (parse "10.0.0.2");
    expected = -1;
  };

  testLtIpVsHostname = {
    expr = host.lt (parse "10.0.0.1") (parse "nas");
    expected = true;
  };
  testLeEqual = {
    expr = host.le (parse "nas") (parse "nas");
    expected = true;
  };
  testGeEqual = {
    expr = host.ge (parse "nas") (parse "nas");
    expected = true;
  };
  testGtHostnameVsIp = {
    expr = host.gt (parse "nas") (parse "10.0.0.1");
    expected = true;
  };
  testMinPicksSmallerFamily = {
    expr = (host.min (parse "nas") (parse "10.0.0.1"))._type;
    expected = "ipv4";
  };
  testMaxPicksLargerFamily = {
    expr = (host.max (parse "10.0.0.1") (parse "example.com"))._type;
    expected = "domain";
  };
  testCompareFoldedOrder = {
    expr = host.compare (parse "alpha") (parse "Beta");
    expected = -1;
  };
  testGtNamesItself = {
    expr = host.gt (parse "nas") "nas";
    expectedError.msg = "^libnet\\.host\\.gt: expected ip, hostname or domain value, got string$";
  };
  testMinNamesItself = {
    expr = host.min (libnet.port.fromInt 80) (parse "nas");
    expectedError.msg = "^libnet\\.host\\.min: expected ip, hostname or domain value, got port value$";
  };

  # Sanity: structural .is checks recognise values from each underlying module
  testIsFromIpModule = {
    expr = host.is (ip.parse "10.0.0.1");
    expected = true;
  };
  testIsFromHostnameModule = {
    expr = host.is (hostname.parse "nas");
    expected = true;
  };
  testIsFromDomainModule = {
    expr = host.is (domain.parse "example.com");
    expected = true;
  };
}
