{ harness }:
let
  dnsName = import ../lib/dns-name.nix;
  hostname = import ../lib/hostname.nix;
  domain = import ../lib/domain.nix;
  inherit (harness) throws;
  parse = dnsName.parse;
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
  testParseMixedCase = {
    expr = (parse "MyHost").value;
    expected = "MyHost";
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
  # A 4-numeric-label string that is NOT a valid IP is still a domain.
  testParseNumericNotIp = {
    expr = (parse "192.0.2.300")._type;
    expected = "domain";
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
    expr = throws (dnsName.parse 42);
    expected = true;
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
  testToStringPreservesCase = {
    expr = dnsName.toString (parse "Example.COM");
    expected = "Example.COM";
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

  # ===== Normalize =====
  testNormalizeHostname = {
    expr = (dnsName.normalize (parse "MyHost")).value;
    expected = "myhost";
  };
  testNormalizeDomain = {
    expr = (dnsName.normalize (parse "Example.COM")).value;
    expected = "example.com";
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
  testCompareEqualCase = {
    expr = dnsName.compare (parse "NAS") (parse "nas");
    expected = 0;
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
