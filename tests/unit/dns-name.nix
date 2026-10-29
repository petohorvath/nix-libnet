{ helpers, libnet, ... }:
let
  inherit (libnet) dnsName domain hostname;
  inherit (helpers) throws;
  inherit (dnsName) parse;
in
{
  # ===== Dispatch =====
  testParseHostnameTagged = {
    expr = (parse "nas")._type;
    expected = "hostname";
  };
  testParseDomainTagged = {
    expr = (parse "pool.ntp.org")._type;
    expected = "domain";
  };
  testParseHostnameValue = {
    expr = (parse "nas").value;
    expected = "nas";
  };
  testParseDomainValue = {
    expr = (parse "example.com").value;
    expected = "example.com";
  };
  testParseHostnameFoldsCase = {
    expr = (parse "MyHost").value;
    expected = "myhost";
  };
  testParseDomainFoldsCase = {
    expr = (parse "Example.COM").value;
    expected = "example.com";
  };

  # ===== IP literals rejected =====
  testRejectIpv4 = {
    expr = throws (parse "192.0.2.1");
    expected = true;
  };
  testRejectIpv6 = {
    expr = throws (parse "::1");
    expected = true;
  };
  testRejectIpv4ViaTryParse = {
    expr = (dnsName.tryParse "10.0.0.1").success;
    expected = false;
  };

  # ===== Text that reads as IPv4 rejected (ADR 0021) =====
  testRejectNumericHostname = {
    expr = parse "2130706433";
    expectedError.msg = "^libnet\\.dnsName\\.parse: \"2130706433\" reads as an IPv4 address, not a DNS name$";
  };
  testRejectHexHostname = {
    expr = parse "0x7f";
    expectedError.msg = "^libnet\\.dnsName\\.parse: \"0x7f\" reads as an IPv4 address, not a DNS name$";
  };
  testRejectNumericDomain = {
    expr = parse "127.1";
    expectedError.msg = "^libnet\\.dnsName\\.parse: \"127\\.1\" reads as an IPv4 address, not a DNS name$";
  };
  # inet_aton reads every one of these as an address, though none is a
  # valid `ip`.
  testRejectInetAtonForms = {
    expr = map dnsName.isValid [
      "010.0.0.1"
      "0x7f.0.0.1"
      "192.0.2.300"
      "0X7F"
      "0x"
    ];
    expected = [
      false
      false
      false
      false
      false
    ];
  };
  testAcceptNumericLeftLabels = {
    expr = map (name: (parse name).value) [
      "1234a"
      "0x7g"
      "192.0.2.example"
    ];
    expected = [
      "1234a"
      "0x7g"
      "192.0.2.example"
    ];
  };

  # ===== Other rejects =====
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
  testRejectNotString = {
    expr = dnsName.parse 42;
    expectedError.msg = "^libnet\\.dnsName\\.parse: expected string, got int$";
  };
  testRejectIpNamesDnsName = {
    expr = parse "192.0.2.1";
    expectedError.msg = "^libnet\\.dnsName\\.parse: \"192\\.0\\.2\\.1\" is an IP address, not a DNS name$";
  };
  testRejectInvalidNamesDnsName = {
    expr = parse "host_name";
    expectedError.msg = "^libnet\\.dnsName\\.parse: invalid hostname \"host_name\" \\(expected ";
  };
  # Text with a dot fails as a domain, so it keeps the domain's detail.
  testRejectInvalidDomainKeepsDetail = {
    expr = parse "host_name.example";
    expectedError.msg = "^libnet\\.dnsName\\.parse: invalid label in \"host_name\\.example\" \\(each label ";
  };

  testTryParseOkHostname = {
    expr = (dnsName.tryParse "nas").success;
    expected = true;
  };
  testTryParseOkDomain = {
    expr = (dnsName.tryParse "example.com").success;
    expected = true;
  };
  testTryParseBadError = {
    expr = builtins.isString (dnsName.tryParse "192.0.2.1").error;
    expected = true;
  };

  # ===== toString =====
  testToStringHostname = {
    expr = dnsName.toString (parse "nas");
    expected = "nas";
  };
  testToStringDomain = {
    expr = dnsName.toString (parse "example.com");
    expected = "example.com";
  };
  testToStringLowercase = {
    expr = dnsName.toString (parse "Example.COM");
    expected = "example.com";
  };
  testToStringRejectsIp = {
    expr = dnsName.toString (libnet.ip.parse "192.0.2.1");
    expectedError.msg = "^libnet\\.dnsName\\.toString: expected hostname or domain value, got ipv4 value$";
  };

  # A numeric hostname is not a DNS name, so it is the wrong kind.
  testToStringRejectsNumericHostname = {
    expr = dnsName.toString (hostname.parse "1234");
    expectedError.msg = "^libnet\\.dnsName\\.toString: expected hostname or domain value, got hostname \"1234\", which reads as an IPv4 address$";
  };

  # ===== Predicates =====
  testIsHostname = {
    expr = dnsName.is (parse "nas");
    expected = true;
  };
  testIsDomain = {
    expr = dnsName.is (parse "example.com");
    expected = true;
  };
  testIsString = {
    expr = dnsName.is "nas";
    expected = false;
  };
  testIsHostnameYes = {
    expr = dnsName.isHostname (parse "nas");
    expected = true;
  };
  testIsHostnameNo = {
    expr = dnsName.isHostname (parse "example.com");
    expected = false;
  };
  testIsDomainYes = {
    expr = dnsName.isDomain (parse "example.com");
    expected = true;
  };
  testIsDomainNo = {
    expr = dnsName.isDomain (parse "nas");
    expected = false;
  };
  # `hostname.parse` accepts a numeric label, which no DNS name is
  # (ADR 0021).
  testIsNumericHostname = {
    expr = map (text: dnsName.is (hostname.parse text)) [
      "1234"
      "0x7f"
      "1234a"
    ];
    expected = [
      false
      false
      true
    ];
  };
  testIsHostnameNumeric = {
    expr = dnsName.isHostname (hostname.parse "1234");
    expected = false;
  };
  testIsValidHostname = {
    expr = dnsName.isValid "nas";
    expected = true;
  };
  testIsValidDomain = {
    expr = dnsName.isValid "example.com";
    expected = true;
  };
  testIsValidIp = {
    expr = dnsName.isValid "192.0.2.1";
    expected = false;
  };
  testIsValidBad = {
    expr = dnsName.isValid "host_name";
    expected = false;
  };

  testNoNormalize = {
    expr = dnsName ? normalize;
    expected = false;
  };

  # ===== Comparison helpers =====
  testLt = {
    expr = dnsName.lt (dnsName.parse "alpha") (dnsName.parse "beta");
    expected = true;
  };
  testLe = {
    expr = dnsName.le (dnsName.parse "alpha") (dnsName.parse "beta");
    expected = true;
  };
  testGt = {
    expr = dnsName.gt (dnsName.parse "beta") (dnsName.parse "alpha");
    expected = true;
  };
  testGe = {
    expr = dnsName.ge (dnsName.parse "beta") (dnsName.parse "alpha");
    expected = true;
  };
  testMin = {
    expr = dnsName.toString (dnsName.min (dnsName.parse "alpha") (dnsName.parse "beta"));
    expected = "alpha";
  };
  testMax = {
    expr = dnsName.toString (dnsName.max (dnsName.parse "alpha") (dnsName.parse "beta"));
    expected = "beta";
  };
  testLtNamesItself = {
    expr = dnsName.lt (parse "nas") "nas";
    expectedError.msg = "^libnet\\.dnsName\\.lt: expected hostname or domain value, got string$";
  };
  testMaxNamesItself = {
    expr = dnsName.max (libnet.ip.parse "192.0.2.1") (parse "nas");
    expectedError.msg = "^libnet\\.dnsName\\.max: expected hostname or domain value, got ipv4 value$";
  };

  # ===== eq =====
  testEqSameHostname = {
    expr = dnsName.eq (parse "nas") (parse "nas");
    expected = true;
  };
  testEqHostnameCase = {
    expr = dnsName.eq (parse "NAS") (parse "nas");
    expected = true;
  };
  testEqDomainCase = {
    expr = dnsName.eq (parse "EXAMPLE.COM") (parse "example.com");
    expected = true;
  };
  testEqHostnameVsDomain = {
    expr = dnsName.eq (parse "nas") (parse "example.com");
    expected = false;
  };

  testEqNumericHostname = {
    expr = dnsName.eq (hostname.parse "1234") (hostname.parse "1234");
    expected = false;
  };

  # ===== compare =====
  testCompareHostnameBeforeDomain = {
    expr = dnsName.compare (parse "zzz") (parse "a.com");
    expected = -1;
  };
  testCompareDomainAfterHostname = {
    expr = dnsName.compare (parse "a.com") (parse "zzz");
    expected = 1;
  };
  testCompareWithinHostname = {
    expr = dnsName.compare (parse "alpha") (parse "beta");
    expected = -1;
  };
  testCompareWithinDomain = {
    expr = dnsName.compare (parse "alpha.com") (parse "beta.com");
    expected = -1;
  };
  testCompareFoldedOrder = {
    expr = dnsName.compare (parse "alpha") (parse "Beta");
    expected = -1;
  };
  testCompareEqualCase = {
    expr = dnsName.compare (parse "NAS") (parse "nas");
    expected = 0;
  };

  testCompareRejectsNumericHostname = {
    expr = dnsName.compare (parse "nas") (hostname.parse "0x7f");
    expectedError.msg = "^libnet\\.dnsName\\.compare: expected hostname or domain value, got hostname \"0x7f\", which reads as an IPv4 address$";
  };

  # Sanity: recognises values from each underlying module
  testIsFromHostnameModule = {
    expr = dnsName.is (hostname.parse "nas");
    expected = true;
  };
  testIsFromDomainModule = {
    expr = dnsName.is (domain.parse "example.com");
    expected = true;
  };
}
