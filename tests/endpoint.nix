{ harness }:
let
  endpoint = import ../lib/endpoint.nix;
  ipEndpoint = import ../lib/ip-endpoint.nix;
  dnsEndpoint = import ../lib/dns-endpoint.nix;
  inherit (harness) throws;
  parse = endpoint.parse;
in
{
  # ===== Dispatch =====
  testParseIpv4Tagged = {
    expr = (parse "192.0.2.1:80")._type;
    expected = "ipEndpoint";
  };
  testParseIpv6Tagged = {
    expr = (parse "[::1]:443")._type;
    expected = "ipEndpoint";
  };
  testParseHostnameTagged = {
    expr = (parse "nas:22")._type;
    expected = "dnsEndpoint";
  };
  testParseDomainTagged = {
    expr = (parse "pool.ntp.org:123")._type;
    expected = "dnsEndpoint";
  };
  testParseIpv4RoundTrip = {
    expr = endpoint.toString (parse "192.0.2.1:80");
    expected = "192.0.2.1:80";
  };
  testParseIpv6RoundTrip = {
    expr = endpoint.toString (parse "[::1]:443");
    expected = "[::1]:443";
  };
  testParseDomainRoundTrip = {
    expr = endpoint.toString (parse "pool.ntp.org:123");
    expected = "pool.ntp.org:123";
  };

  # ===== Reject =====
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectNoPort = {
    expr = throws (parse "nas");
    expected = true;
  };
  testRejectUnderscore = {
    expr = throws (parse "host_name:22");
    expected = true;
  };
  testRejectUnbracketedIpv6 = {
    expr = throws (parse "::1:443");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (endpoint.parse 42);
    expected = true;
  };

  testTryParseOkIp = {
    expr = (endpoint.tryParse "192.0.2.1:80").success;
    expected = true;
  };
  testTryParseOkName = {
    expr = (endpoint.tryParse "nas:22").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (endpoint.tryParse "host_name:1").success;
    expected = false;
  };

  # ===== toString =====
  testToStringNamePreservesCase = {
    expr = endpoint.toString (parse "MyHost.example.com:443");
    expected = "MyHost.example.com:443";
  };

  # ===== Predicates =====
  testIsIp = {
    expr = endpoint.is (parse "192.0.2.1:80");
    expected = true;
  };
  testIsDns = {
    expr = endpoint.is (parse "nas:22");
    expected = true;
  };
  testIsString = {
    expr = endpoint.is "nas:22";
    expected = false;
  };
  testIsIpEndpointYes = {
    expr = endpoint.isIpEndpoint (parse "192.0.2.1:80");
    expected = true;
  };
  testIsIpEndpointNo = {
    expr = endpoint.isIpEndpoint (parse "nas:22");
    expected = false;
  };
  testIsDnsEndpointYes = {
    expr = endpoint.isDnsEndpoint (parse "nas:22");
    expected = true;
  };
  testIsDnsEndpointNo = {
    expr = endpoint.isDnsEndpoint (parse "192.0.2.1:80");
    expected = false;
  };
  testIsValidIp = {
    expr = endpoint.isValid "192.0.2.1:80";
    expected = true;
  };
  testIsValidName = {
    expr = endpoint.isValid "pool.ntp.org:123";
    expected = true;
  };
  testIsValidBad = {
    expr = endpoint.isValid "host_name:1";
    expected = false;
  };

  # ===== Member access via predicates =====
  # The union is heterogeneous (no uniform address/port), so branch on
  # the kind and use the member module's accessors.
  testPortViaMember = {
    expr = (import ../lib/port.nix).toInt (ipEndpoint.port (parse "192.0.2.1:80"));
    expected = 80;
  };
  testAddressViaMember = {
    expr = (dnsEndpoint.address (parse "nas:22")).value;
    expected = "nas";
  };

  # IP-endpoint result carries the full ipEndpoint API (predicates).
  testIpResultHasPredicates = {
    expr = ipEndpoint.isLoopback (parse "127.0.0.1:80");
    expected = true;
  };

  # ===== Comparison helpers =====
  testCompareLt = {
    expr = endpoint.lt (parse "192.0.2.1:80") (parse "192.0.2.2:80");
    expected = true;
  };
  testCompareLe = {
    expr = endpoint.le (parse "192.0.2.1:80") (parse "192.0.2.2:80");
    expected = true;
  };
  testCompareGt = {
    expr = endpoint.gt (parse "192.0.2.2:80") (parse "192.0.2.1:80");
    expected = true;
  };
  testCompareGe = {
    expr = endpoint.ge (parse "192.0.2.2:80") (parse "192.0.2.1:80");
    expected = true;
  };
  testCompareMax = {
    expr = endpoint.toString (endpoint.max (parse "192.0.2.1:80") (parse "192.0.2.2:80"));
    expected = "192.0.2.2:80";
  };

  # ===== Comparison =====
  testEqSameIp = {
    expr = endpoint.eq (parse "192.0.2.1:80") (parse "192.0.2.1:80");
    expected = true;
  };
  testEqSameName = {
    expr = endpoint.eq (parse "nas:22") (parse "nas:22");
    expected = true;
  };
  testEqNameCaseInsensitive = {
    expr = endpoint.eq (parse "NAS:22") (parse "nas:22");
    expected = true;
  };
  testEqCrossKind = {
    expr = endpoint.eq (parse "192.0.2.1:80") (parse "nas:22");
    expected = false;
  };
  testCompareIpBeforeName = {
    expr = endpoint.compare (parse "192.0.2.1:80") (parse "nas:22");
    expected = -1;
  };
  testCompareNameAfterIp = {
    expr = endpoint.compare (parse "nas:22") (parse "192.0.2.1:80");
    expected = 1;
  };
  testCompareWithinName = {
    expr = endpoint.compare (parse "alpha:80") (parse "beta:80");
    expected = -1;
  };
  testCompareNameBeforeUnix = {
    expr = endpoint.compare (parse "nas:22") (parse "/run/foo.sock");
    expected = -1;
  };
  testCompareUnixAfterIp = {
    expr = endpoint.compare (parse "/run/foo.sock") (parse "10.0.0.1:80");
    expected = 1;
  };
  testMinPicksIp = {
    expr = (endpoint.min (parse "nas:22") (parse "10.0.0.1:80"))._type;
    expected = "ipEndpoint";
  };

  # ===== unixSocket member =====
  testParseUnixTagged = {
    expr = (parse "/run/foo.sock")._type;
    expected = "unixSocket";
  };
  testParseUnixAbstract = {
    expr = (parse "@foo")._type;
    expected = "unixSocket";
  };
  testParseUnixRoundTrip = {
    expr = endpoint.toString (parse "/run/postgresql/.s.PGSQL.5432");
    expected = "/run/postgresql/.s.PGSQL.5432";
  };
  testIsUnixSocketYes = {
    expr = endpoint.isUnixSocket (parse "/run/foo.sock");
    expected = true;
  };
  testIsUnixSocketNo = {
    expr = endpoint.isUnixSocket (parse "192.0.2.1:80");
    expected = false;
  };
  testIsValidUnix = {
    expr = endpoint.isValid "/run/foo.sock";
    expected = true;
  };
  testEqSameUnix = {
    expr = endpoint.eq (parse "/run/foo.sock") (parse "/run/foo.sock");
    expected = true;
  };
  testEqUnixCrossKind = {
    expr = endpoint.eq (parse "/run/foo.sock") (parse "nas:22");
    expected = false;
  };

  # Sanity: union recognises values from each member module
  testIsFromIpModule = {
    expr = endpoint.is (ipEndpoint.parse "10.0.0.1:80");
    expected = true;
  };
  testIsFromDnsModule = {
    expr = endpoint.is (dnsEndpoint.parse "nas:22");
    expected = true;
  };
  testIsFromUnixModule = {
    expr = endpoint.is ((import ../lib/unix-socket.nix).parse "/run/foo.sock");
    expected = true;
  };
}
