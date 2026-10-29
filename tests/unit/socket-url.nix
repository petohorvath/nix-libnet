{ helpers, libnet, ... }:
let
  inherit (libnet)
    endpoint
    socketUrl
    transport
    unixSocket
    ;
  inherit (helpers) throws;
  inherit (socketUrl) parse;
in
{
  # ===== Parse: IP schemes =====
  testParseTcpIpv4 = {
    expr = socketUrl.toString (parse "tcp://1.2.3.4:80");
    expected = "tcp://1.2.3.4:80";
  };
  testParseUdpIpv6 = {
    expr = socketUrl.toString (parse "udp://[::1]:53");
    expected = "udp://[::1]:53";
  };
  testParseSctpDns = {
    expr = socketUrl.toString (parse "sctp://pool.ntp.org:9999");
    expected = "sctp://pool.ntp.org:9999";
  };
  testParseTagged = {
    expr = (parse "tcp://1.2.3.4:80")._type;
    expected = "socketUrl";
  };
  testParseStoresScheme = {
    expr = parse "TCP://1.2.3.4:80";
    expected = {
      _type = "socketUrl";
      scheme = "tcp";
      endpoint = endpoint.parse "1.2.3.4:80";
    };
  };
  testParseUnixStoresScheme = {
    expr = parse "unix:///run/foo.sock";
    expected = {
      _type = "socketUrl";
      scheme = "unix";
      endpoint = unixSocket.parse "/run/foo.sock";
    };
  };
  testParseTransport = {
    expr = transport.toString (socketUrl.transport (parse "tcp://1.2.3.4:80"));
    expected = "tcp";
  };
  testParseEndpointKind = {
    expr = (socketUrl.endpoint (parse "tcp://1.2.3.4:80"))._type;
    expected = "ipEndpoint";
  };
  testParseDnsEndpointKind = {
    expr = (socketUrl.endpoint (parse "tcp://pool.ntp.org:123"))._type;
    expected = "dnsEndpoint";
  };
  testParseSchemeUppercase = {
    expr = socketUrl.toString (parse "TCP://1.2.3.4:80");
    expected = "tcp://1.2.3.4:80";
  };
  testParseSchemeMixedCase = {
    expr = socketUrl.toString (parse "Udp://[::1]:53");
    expected = "udp://[::1]:53";
  };
  testParseSchemeUppercaseSctp = {
    expr = socketUrl.toString (parse "SCTP://pool.ntp.org:9999");
    expected = "sctp://pool.ntp.org:9999";
  };

  # ===== Parse: unix scheme =====
  testParseUnixPathname = {
    expr = socketUrl.toString (parse "unix:///run/foo.sock");
    expected = "unix:///run/foo.sock";
  };
  testParseUnixAbstract = {
    expr = socketUrl.toString (parse "unix://@foo");
    expected = "unix://@foo";
  };
  testParseUnixTransportNull = {
    expr = socketUrl.transport (parse "unix:///run/foo.sock");
    expected = null;
  };
  testParseUnixSchemeUppercase = {
    expr = socketUrl.toString (parse "UNIX:///run/foo.sock");
    expected = "unix:///run/foo.sock";
  };
  testParseUnixEndpointKind = {
    expr = (socketUrl.endpoint (parse "unix:///run/foo.sock"))._type;
    expected = "unixSocket";
  };

  # ===== Reject =====
  testRejectNoScheme = {
    expr = parse "1.2.3.4:80";
    expectedError.msg = "^libnet\\.socketUrl\\.parse: missing '<scheme>://': \"1\\.2\\.3\\.4:80\"$";
  };
  testRejectUnknownScheme = {
    expr = throws (parse "http://1.2.3.4:80");
    expected = true;
  };
  testRejectIcmpScheme = {
    expr = throws (parse "icmp://1.2.3.4:80");
    expected = true;
  };
  testRejectTcpPath = {
    expr = throws (parse "tcp:///run/foo.sock");
    expected = true;
  };
  testRejectTcpPathUppercaseScheme = {
    expr = (socketUrl.tryParse "TCP:///run/foo.sock").error;
    expected = "libnet.socketUrl.parse: 'tcp://' requires host:port, not a socket path: \"TCP:///run/foo.sock\"";
  };
  testRejectUnixHostPort = {
    expr = throws (parse "unix://1.2.3.4:80");
    expected = true;
  };
  testRejectUnixHostPortUppercaseScheme = {
    expr = (socketUrl.tryParse "UNIX://1.2.3.4:80").error;
    expected = "libnet.socketUrl.parse: 'unix://' requires a socket path: \"UNIX://1.2.3.4:80\"";
  };
  # The host reads as IPv4 but is not an `ip` (ADR 0021).
  testRejectNumericName = {
    expr = throws (parse "tcp://127.1:80");
    expected = true;
  };
  testRejectBadEndpoint = {
    expr = parse "tcp://host_name:1";
    expectedError.msg = "^libnet\\.socketUrl\\.parse: \"host_name:1\" is not a valid IP, name, or unix-socket endpoint$";
  };
  testRejectBadSocketPathKeepsDetail = {
    expr = parse "unix://@";
    expectedError.msg = "^libnet\\.socketUrl\\.parse: invalid socket \"@\"";
  };
  testRejectUnknownSchemeBeforeAddress = {
    expr = (socketUrl.tryParse "foo://garbage").error;
    expected = "libnet.socketUrl.parse: unknown scheme \"foo\" (expected tcp, udp, sctp, or unix)";
  };
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectNotString = {
    expr = socketUrl.parse 42;
    expectedError.msg = "^libnet\\.socketUrl\\.parse: expected string, got int$";
  };

  testTryParseOk = {
    expr = (socketUrl.tryParse "tcp://1.2.3.4:80").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (socketUrl.tryParse "1.2.3.4:80").success;
    expected = false;
  };
  testTryParseUnknownSchemeErrorKeepsCase = {
    expr = (socketUrl.tryParse "HTTP://x:1").error;
    expected = "libnet.socketUrl.parse: unknown scheme \"HTTP\" (expected tcp, udp, sctp, or unix)";
  };
  testTryParseBadError = {
    expr = builtins.isString (socketUrl.tryParse "http://x:1").error;
    expected = true;
  };

  # ===== make =====
  testMakeIp = {
    expr = socketUrl.toString (socketUrl.make "tcp" (endpoint.parse "1.2.3.4:80"));
    expected = "tcp://1.2.3.4:80";
  };
  testMakeDns = {
    expr = socketUrl.toString (socketUrl.make "sctp" (endpoint.parse "pool.ntp.org:9999"));
    expected = "sctp://pool.ntp.org:9999";
  };
  testMakeUnix = {
    expr = socketUrl.toString (socketUrl.make "unix" (unixSocket.parse "/run/foo.sock"));
    expected = "unix:///run/foo.sock";
  };
  testMakeSchemeCaseInsensitive = {
    expr = socketUrl.scheme (socketUrl.make "UDP" (endpoint.parse "[::1]:53"));
    expected = "udp";
  };
  testMakeEqualsParse = {
    expr = socketUrl.make "Tcp" (endpoint.parse "1.2.3.4:80");
    expected = parse "tcp://1.2.3.4:80";
  };
  testMakeRoundTrips = {
    expr = map (value: socketUrl.eq (parse (socketUrl.toString value)) value) [
      (socketUrl.make "tcp" (endpoint.parse "1.2.3.4:80"))
      (socketUrl.make "udp" (endpoint.parse "nas:53"))
      (socketUrl.make "unix" (unixSocket.parse "@foo"))
    ];
    expected = [
      true
      true
      true
    ];
  };
  testMakeMapsOverEndpoints = {
    expr = map socketUrl.toString (
      map (socketUrl.make "udp") [
        (endpoint.parse "1.2.3.4:53")
        (endpoint.parse "[::1]:53")
      ]
    );
    expected = [
      "udp://1.2.3.4:53"
      "udp://[::1]:53"
    ];
  };
  testMakeUnixSchemeIpEndpointThrows = {
    expr = socketUrl.make "unix" (endpoint.parse "1.2.3.4:80");
    expectedError.msg = "^libnet\\.socketUrl\\.make: expected unixSocket value for scheme \"unix\", got ipEndpoint value$";
  };
  testMakeTcpSchemeUnixSocketThrows = {
    expr = socketUrl.make "tcp" (unixSocket.parse "/run/foo.sock");
    expectedError.msg = "^libnet\\.socketUrl\\.make: expected ipEndpoint or dnsEndpoint value for scheme \"tcp\", got unixSocket value$";
  };
  testMakeUnknownSchemeThrows = {
    expr = socketUrl.make "http" (endpoint.parse "1.2.3.4:80");
    expectedError.msg = "^libnet\\.socketUrl\\.make: unknown scheme \"http\" \\(expected tcp, udp, sctp, or unix\\)$";
  };
  testMakeTransportSchemeThrows = {
    expr = socketUrl.make (transport.parse "tcp") (endpoint.parse "1.2.3.4:80");
    expectedError.msg = "^libnet\\.socketUrl\\.make: expected string, got transport value$";
  };
  testMakeNullSchemeThrows = {
    expr = socketUrl.make null (unixSocket.parse "/run/foo.sock");
    expectedError.msg = "^libnet\\.socketUrl\\.make: expected string, got null$";
  };
  testMakeBindpointThrows = {
    expr = socketUrl.make "tcp" (libnet.ipBindpoint.parse ":80");
    expectedError.msg = "^libnet\\.socketUrl\\.make: expected ipEndpoint, dnsEndpoint or unixSocket value, got ipBindpoint value$";
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = socketUrl.is (parse "tcp://1.2.3.4:80");
    expected = true;
  };
  testIsString = {
    expr = socketUrl.is "tcp://1.2.3.4:80";
    expected = false;
  };
  testIsValidIp = {
    expr = socketUrl.isValid "udp://[::]:53";
    expected = true;
  };
  testIsValidUnix = {
    expr = socketUrl.isValid "unix:///run/foo.sock";
    expected = true;
  };
  testIsValidBad = {
    expr = socketUrl.isValid "ftp://x:1";
    expected = false;
  };
  testIsUnixYes = {
    expr = socketUrl.isUnix (parse "unix:///run/foo.sock");
    expected = true;
  };
  testIsUnixNo = {
    expr = socketUrl.isUnix (parse "tcp://1.2.3.4:80");
    expected = false;
  };

  # ===== Comparison helpers =====
  testLtBefore = {
    expr = socketUrl.lt (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81");
    expected = true;
  };
  testLeBefore = {
    expr = socketUrl.le (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81");
    expected = true;
  };
  testGtAfter = {
    expr = socketUrl.gt (parse "tcp://1.2.3.4:81") (parse "tcp://1.2.3.4:80");
    expected = true;
  };
  testGeAfter = {
    expr = socketUrl.ge (parse "tcp://1.2.3.4:81") (parse "tcp://1.2.3.4:80");
    expected = true;
  };
  testMinPicksLesser = {
    expr = socketUrl.toString (socketUrl.min (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81"));
    expected = "tcp://1.2.3.4:80";
  };
  testMaxPicksGreater = {
    expr = socketUrl.toString (socketUrl.max (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81"));
    expected = "tcp://1.2.3.4:81";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = socketUrl.eq (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:80");
    expected = true;
  };
  testEqDifferentTransport = {
    expr = socketUrl.eq (parse "tcp://1.2.3.4:80") (parse "udp://1.2.3.4:80");
    expected = false;
  };
  testEqDifferentEndpoint = {
    expr = socketUrl.eq (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81");
    expected = false;
  };
  testEqSchemeCaseInsensitive = {
    expr = socketUrl.eq (parse "TCP://1.2.3.4:80") (parse "tcp://1.2.3.4:80");
    expected = true;
  };
  testToStringDnsLowercase = {
    expr = socketUrl.toString (parse "tcp://Pool.NTP.org:123");
    expected = "tcp://pool.ntp.org:123";
  };
  testToStringUnixPathKeepsCase = {
    expr = socketUrl.toString (parse "unix:///run/App.sock");
    expected = "unix:///run/App.sock";
  };
  testEqDnsCaseInsensitive = {
    expr = socketUrl.eq (parse "tcp://Pool.NTP.org:123") (parse "tcp://pool.ntp.org:123");
    expected = true;
  };
  testEqSameUnix = {
    expr = socketUrl.eq (parse "unix:///run/foo.sock") (parse "unix:///run/foo.sock");
    expected = true;
  };
  testEqCrossFamily = {
    expr = socketUrl.eq (parse "tcp://1.2.3.4:80") (parse "unix:///run/foo.sock");
    expected = false;
  };
  testCompareTcpBeforeUdp = {
    expr = socketUrl.compare (parse "tcp://1.2.3.4:80") (parse "udp://1.2.3.4:80");
    expected = -1;
  };
  testCompareIpBeforeUnix = {
    expr = socketUrl.compare (parse "sctp://1.2.3.4:80") (parse "unix:///run/foo.sock");
    expected = -1;
  };
  testCompareWithinTransportByEndpoint = {
    expr = socketUrl.compare (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81");
    expected = -1;
  };
  testCompareEqual = {
    expr = socketUrl.compare (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:80");
    expected = 0;
  };

  # Schemes sort by name: sctp < tcp < udp < unix.
  testCompareSctpBeforeTcp = {
    expr = socketUrl.compare (parse "sctp://1.2.3.4:80") (parse "tcp://1.2.3.4:80");
    expected = -1;
  };
  testCompareUdpBeforeUnix = {
    expr = socketUrl.compare (parse "udp://1.2.3.4:80") (parse "unix:///run/foo.sock");
    expected = -1;
  };
  testSortByScheme = {
    expr = map socketUrl.scheme (
      builtins.sort socketUrl.lt [
        (parse "unix:///run/foo.sock")
        (parse "udp://1.2.3.4:80")
        (parse "tcp://1.2.3.4:80")
        (parse "sctp://1.2.3.4:80")
      ]
    );
    expected = [
      "sctp"
      "tcp"
      "udp"
      "unix"
    ];
  };

  # ===== Scheme-derived =====
  testSchemeTcp = {
    expr = socketUrl.scheme (parse "TCP://1.2.3.4:80");
    expected = "tcp";
  };
  testSchemeUnix = {
    expr = socketUrl.scheme (parse "unix:///run/foo.sock");
    expected = "unix";
  };
  testTransportSctp = {
    expr = socketUrl.transport (parse "sctp://1.2.3.4:80");
    expected = transport.sctp;
  };
  testTransportUnixNull = {
    expr = socketUrl.transport (parse "unix:///run/foo.sock");
    expected = null;
  };
  testIsSecureIp = {
    expr = socketUrl.isSecure (parse "tcp://1.2.3.4:80");
    expected = false;
  };
  testIsSecureUnix = {
    expr = socketUrl.isSecure (parse "unix:///run/foo.sock");
    expected = false;
  };

  # ===== Constant =====
  testSchemesRegistry = {
    expr = socketUrl.schemes;
    expected = {
      sctp = {
        transport = "sctp";
        secure = false;
      };
      tcp = {
        transport = "tcp";
        secure = false;
      };
      udp = {
        transport = "udp";
        secure = false;
      };
      unix = {
        transport = null;
        secure = false;
      };
    };
  };
  testSchemesMatchTransports = {
    expr = map (name: socketUrl.schemes.${name}.transport) (map transport.toString transport.values);
    expected = [
      "sctp"
      "tcp"
      "udp"
    ];
  };
}
