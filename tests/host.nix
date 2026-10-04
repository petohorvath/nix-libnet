{ harness }:
let
  host = import ../lib/host.nix;
  ip = import ../lib/ip.nix;
  hostname = import ../lib/hostname.nix;
  domain = import ../lib/domain.nix;
  inherit (harness) throws;
  parse = host.parse;
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
  testParseHostnameMixedCase = {
    expr = (parse "MyHost")._type;
    expected = "hostname";
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
    expr = throws (host.parse 42);
    expected = true;
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
    expr = builtins.isString (host.tryParse "host_name").error;
    expected = true;
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
  testToStringHostnamePreservesCase = {
    expr = host.toString (parse "MyHost");
    expected = "MyHost";
  };
  testToStringUntaggedThrows = {
    expr = throws (host.toString { value = "nope"; });
    expected = true;
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

  testIsHostnameHostname = {
    expr = host.isHostname (parse "nas");
    expected = true;
  };
  testIsHostnameIp = {
    expr = host.isHostname (parse "10.0.0.1");
    expected = false;
  };
  testIsHostnameDomain = {
    expr = host.isHostname (parse "example.com");
    expected = false;
  };

  testIsDomainDomain = {
    expr = host.isDomain (parse "example.com");
    expected = true;
  };
  testIsDomainHostname = {
    expr = host.isDomain (parse "nas");
    expected = false;
  };
  testIsDomainIp = {
    expr = host.isDomain (parse "10.0.0.1");
    expected = false;
  };

  testIsNameHostname = {
    expr = host.isName (parse "nas");
    expected = true;
  };
  testIsNameDomain = {
    expr = host.isName (parse "example.com");
    expected = true;
  };
  testIsNameIp = {
    expr = host.isName (parse "10.0.0.1");
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
