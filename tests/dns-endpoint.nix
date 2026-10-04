{ harness }:
let
  dnsEndpoint = import ../lib/dns-endpoint.nix;
  dnsName = import ../lib/dns-name.nix;
  port = import ../lib/port.nix;
  inherit (harness) throws;
  parse = dnsEndpoint.parse;
in
{
  # ===== Parse =====
  testParseHostname = {
    expr = dnsEndpoint.toString (parse "nas:22");
    expected = "nas:22";
  };
  testParseDomain = {
    expr = dnsEndpoint.toString (parse "pool.ntp.org:123");
    expected = "pool.ntp.org:123";
  };
  testParseTagged = {
    expr = (parse "nas:22")._type;
    expected = "dnsEndpoint";
  };
  testParseAddressHostname = {
    expr = (dnsEndpoint.address (parse "nas:22")).value;
    expected = "nas";
  };
  testParseAddressDomain = {
    expr = (dnsEndpoint.address (parse "pool.ntp.org:123")).value;
    expected = "pool.ntp.org";
  };
  testParsePort = {
    expr = port.toInt (dnsEndpoint.port (parse "nas:22"));
    expected = 22;
  };
  testParsePreservesCase = {
    expr = dnsEndpoint.toString (parse "MyHost.Example.COM:443");
    expected = "MyHost.Example.COM:443";
  };

  # ===== Reject =====
  testRejectIpv4 = {
    expr = throws (parse "192.0.2.1:80");
    expected = true;
  };
  testRejectBracketedIpv6 = {
    expr = throws (parse "[::1]:443");
    expected = true;
  };
  testRejectNoPort = {
    expr = throws (parse "nas");
    expected = true;
  };
  testRejectEmptyPort = {
    expr = throws (parse "nas:");
    expected = true;
  };
  testRejectBadPort = {
    expr = throws (parse "nas:99999");
    expected = true;
  };
  testRejectUnderscore = {
    expr = throws (parse "host_name:22");
    expected = true;
  };
  testRejectMultipleColons = {
    expr = throws (parse "a:b:22");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (dnsEndpoint.parse 42);
    expected = true;
  };

  testTryParseOk = {
    expr = (dnsEndpoint.tryParse "nas:22").success;
    expected = true;
  };
  testTryParseIpRejected = {
    expr = (dnsEndpoint.tryParse "192.0.2.1:80").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = builtins.isString (dnsEndpoint.tryParse "192.0.2.1:80").error;
    expected = true;
  };

  # ===== make =====
  testMakeOk = {
    expr = dnsEndpoint.toString (dnsEndpoint.make (dnsName.parse "nas") (port.fromInt 22));
    expected = "nas:22";
  };
  testMakeBadAddress = {
    expr = throws (dnsEndpoint.make "nas" (port.fromInt 22));
    expected = true;
  };
  testMakeBadPort = {
    expr = throws (dnsEndpoint.make (dnsName.parse "nas") 22);
    expected = true;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = dnsEndpoint.is (parse "nas:22");
    expected = true;
  };
  testIsString = {
    expr = dnsEndpoint.is "nas:22";
    expected = false;
  };
  testIsValidOk = {
    expr = dnsEndpoint.isValid "pool.ntp.org:123";
    expected = true;
  };
  testIsValidIp = {
    expr = dnsEndpoint.isValid "192.0.2.1:80";
    expected = false;
  };
  testIsHostnameYes = {
    expr = dnsEndpoint.isHostname (parse "nas:22");
    expected = true;
  };
  testIsHostnameNo = {
    expr = dnsEndpoint.isHostname (parse "example.com:80");
    expected = false;
  };
  testIsDomainYes = {
    expr = dnsEndpoint.isDomain (parse "example.com:80");
    expected = true;
  };
  testIsDomainNo = {
    expr = dnsEndpoint.isDomain (parse "nas:22");
    expected = false;
  };

  # ===== Comparison helpers =====
  testCompareLt = {
    expr = dnsEndpoint.lt (parse "alpha:80") (parse "beta:80");
    expected = true;
  };
  testCompareLe = {
    expr = dnsEndpoint.le (parse "alpha:80") (parse "beta:80");
    expected = true;
  };
  testCompareGt = {
    expr = dnsEndpoint.gt (parse "beta:80") (parse "alpha:80");
    expected = true;
  };
  testCompareGe = {
    expr = dnsEndpoint.ge (parse "beta:80") (parse "alpha:80");
    expected = true;
  };
  testCompareMin = {
    expr = dnsEndpoint.toString (dnsEndpoint.min (parse "alpha:80") (parse "beta:80"));
    expected = "alpha:80";
  };
  testCompareMax = {
    expr = dnsEndpoint.toString (dnsEndpoint.max (parse "alpha:80") (parse "beta:80"));
    expected = "beta:80";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = dnsEndpoint.eq (parse "nas:22") (parse "nas:22");
    expected = true;
  };
  testEqCaseInsensitive = {
    expr = dnsEndpoint.eq (parse "NAS:22") (parse "nas:22");
    expected = true;
  };
  testEqDifferentPort = {
    expr = dnsEndpoint.eq (parse "nas:22") (parse "nas:23");
    expected = false;
  };
  testEqDifferentHost = {
    expr = dnsEndpoint.eq (parse "nas:22") (parse "router:22");
    expected = false;
  };
  testCompareByHost = {
    expr = dnsEndpoint.compare (parse "alpha:80") (parse "beta:80");
    expected = -1;
  };
  testCompareByPort = {
    expr = dnsEndpoint.compare (parse "nas:22") (parse "nas:80");
    expected = -1;
  };
  testCompareEqual = {
    expr = dnsEndpoint.compare (parse "NAS:22") (parse "nas:22");
    expected = 0;
  };
}
