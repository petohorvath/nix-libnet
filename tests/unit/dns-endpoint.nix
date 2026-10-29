{ helpers, libnet, ... }:
let
  inherit (libnet) dnsEndpoint dnsName port;
  inherit (helpers) throws;
  inherit (dnsEndpoint) parse;
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
  testParseNameHostname = {
    expr = (dnsEndpoint.name (parse "nas:22")).value;
    expected = "nas";
  };
  testParseNameDomain = {
    expr = (dnsEndpoint.name (parse "pool.ntp.org:123")).value;
    expected = "pool.ntp.org";
  };
  testParsePort = {
    expr = port.toInt (dnsEndpoint.port (parse "nas:22"));
    expected = 22;
  };
  testParseFoldsCase = {
    expr = dnsEndpoint.toString (parse "MyHost.Example.COM:443");
    expected = "myhost.example.com:443";
  };

  # ===== Reject =====
  # The name's failure keeps its detail under one `dnsEndpoint.parse`
  # prefix.
  testRejectIpv4 = {
    expr = parse "192.0.2.1:80";
    expectedError.msg = "^libnet\\.dnsEndpoint\\.parse: \"192\\.0\\.2\\.1\" ";
  };
  testRejectBracketedIpv6 = {
    expr = parse "[::1]:443";
    expectedError.msg = "^libnet\\.dnsEndpoint\\.parse: bracketed form is for IPv6";
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
    expr = parse "nas:99999";
    expectedError.msg = "^libnet\\.dnsEndpoint\\.parse: invalid port in \"nas:99999\"$";
  };
  testRejectPortLeadingZero = {
    expr = throws (parse "nas:022");
    expected = true;
  };
  testTryParseOverlongPort = {
    expr = (dnsEndpoint.tryParse "nas:99999999999999999999").success;
    expected = false;
  };
  testRejectUnderscore = {
    expr = parse "host_name:22";
    expectedError.msg = "^libnet\\.dnsEndpoint\\.parse: \"host_name\" ";
  };
  testRejectMultipleColons = {
    expr = throws (parse "a:b:22");
    expected = true;
  };
  testRejectNotString = {
    expr = dnsEndpoint.parse 42;
    expectedError.msg = "^libnet\\.dnsEndpoint\\.parse: expected string, got int$";
  };

  testTryParseOk = {
    expr = (dnsEndpoint.tryParse "nas:22").success;
    expected = true;
  };
  testTryParseIpRejected = {
    expr = (dnsEndpoint.tryParse "192.0.2.1:80").success;
    expected = false;
  };
  testTryParseBadErrorHasOnePrefix = {
    expr =
      builtins.match "libnet[.]dnsEndpoint[.]parse: \"192[.]0[.]2[.]1\" [^:]*" (dnsEndpoint.tryParse "192.0.2.1:80")
      .error != null;
    expected = true;
  };

  # ===== make =====
  testMakeOk = {
    expr = dnsEndpoint.toString (dnsEndpoint.make (dnsName.parse "nas") (port.fromInt 22));
    expected = "nas:22";
  };
  testMakeRoundTrips = {
    expr =
      let
        made = dnsEndpoint.make (dnsName.parse "pool.ntp.org") (port.fromInt 123);
      in
      dnsEndpoint.eq (parse (dnsEndpoint.toString made)) made;
    expected = true;
  };
  testMakeBadAddress = {
    expr = dnsEndpoint.make "nas" (port.fromInt 22);
    expectedError.msg = "^libnet\\.dnsEndpoint\\.make: expected hostname or domain value, got string$";
  };
  # `hostname.parse "1234"` succeeds, but no DNS name reads as IPv4, so
  # `make` cannot build what `parse` rejects (ADR 0021).
  testMakeRejectsNumericHostname = {
    expr = dnsEndpoint.make (libnet.hostname.parse "1234") (port.fromInt 22);
    expectedError.msg = "^libnet\\.dnsEndpoint\\.make: \"1234\" reads as an IPv4 address, not a DNS name$";
  };
  testParseRejectsNumericName = {
    expr = parse "0x7f:22";
    expectedError.msg = "^libnet\\.dnsEndpoint\\.parse: \"0x7f\" reads as an IPv4 address, not a DNS name$";
  };
  testMakeBadPort = {
    expr = dnsEndpoint.make (dnsName.parse "nas") 22;
    expectedError.msg = "^libnet\\.dnsEndpoint\\.make: expected port value, got int$";
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
  # Hostnames sort before domains whatever their text: "zeta" < "a.example".
  testCompareHostnameBeforeDomain = {
    expr = dnsEndpoint.compare (parse "zeta:80") (parse "a.example:80");
    expected = -1;
  };
  testCompareDomainAfterHostname = {
    expr = dnsEndpoint.compare (parse "a.example:22") (parse "zeta:80");
    expected = 1;
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
