{ helpers, libnet, ... }:
let
  inherit (libnet)
    bindUrl
    bindpoint
    transport
    unixSocket
    ;
  inherit (helpers) throws;
  inherit (bindUrl) parse;
in
{
  # ===== Parse: IP schemes =====
  testParseTcpWildcard = {
    expr = bindUrl.toString (parse "tcp://:8080");
    expected = "tcp://:8080";
  };
  testParseUdpExplicitAny = {
    expr = bindUrl.toString (parse "udp://0.0.0.0:53");
    expected = "udp://0.0.0.0:53";
  };
  testParseTcpV6Range = {
    expr = bindUrl.toString (parse "tcp://[::]:8000-8100");
    expected = "tcp://[::]:8000-8100";
  };
  testParseSctpV4 = {
    expr = bindUrl.toString (parse "sctp://1.2.3.4:80");
    expected = "sctp://1.2.3.4:80";
  };
  testParseWildcardNormalizes = {
    expr = bindUrl.toString (parse "tcp://*:8080");
    expected = "tcp://:8080";
  };
  testParseSchemeUppercase = {
    expr = bindUrl.toString (parse "TCP://:80");
    expected = "tcp://:80";
  };
  testParseSchemeMixedCase = {
    expr = bindUrl.toString (parse "Udp://0.0.0.0:53");
    expected = "udp://0.0.0.0:53";
  };
  testParseSchemeUppercaseSctp = {
    expr = bindUrl.toString (parse "SCTP://[::]:8000-8100");
    expected = "sctp://[::]:8000-8100";
  };
  testParseTagged = {
    expr = (parse "tcp://:8080")._type;
    expected = "bindUrl";
  };
  testParseStoresScheme = {
    expr = parse "Udp://:53";
    expected = {
      _type = "bindUrl";
      scheme = "udp";
      bindpoint = bindpoint.parse ":53";
    };
  };
  testParseUnixStoresScheme = {
    expr = parse "unix://@foo";
    expected = {
      _type = "bindUrl";
      scheme = "unix";
      bindpoint = unixSocket.parse "@foo";
    };
  };
  testParseTransport = {
    expr = transport.toString (bindUrl.transport (parse "tcp://:8080"));
    expected = "tcp";
  };
  testParseBindpointKind = {
    expr = (bindUrl.bindpoint (parse "tcp://:8080"))._type;
    expected = "ipBindpoint";
  };

  # ===== Parse: unix scheme =====
  testParseUnixPathname = {
    expr = bindUrl.toString (parse "unix:///run/foo.sock");
    expected = "unix:///run/foo.sock";
  };
  testParseUnixAbstract = {
    expr = bindUrl.toString (parse "unix://@foo");
    expected = "unix://@foo";
  };
  testParseUnixTransportNull = {
    expr = bindUrl.transport (parse "unix:///run/foo.sock");
    expected = null;
  };
  testParseUnixSchemeUppercase = {
    expr = bindUrl.toString (parse "UNIX:///run/foo.sock");
    expected = "unix:///run/foo.sock";
  };
  testParseUnixBindpointKind = {
    expr = (bindUrl.bindpoint (parse "unix:///run/foo.sock"))._type;
    expected = "unixSocket";
  };

  # ===== Reject =====
  testRejectNoScheme = {
    expr = parse ":8080";
    expectedError.msg = "^libnet\\.bindUrl\\.parse: missing '<scheme>://': \":8080\"$";
  };
  testRejectUnknownScheme = {
    expr = throws (parse "http://:8080");
    expected = true;
  };
  testRejectTcpPath = {
    expr = throws (parse "tcp:///run/foo.sock");
    expected = true;
  };
  testRejectTcpPathUppercaseScheme = {
    expr = (bindUrl.tryParse "TCP:///run/foo.sock").error;
    expected = "libnet.bindUrl.parse: 'tcp://' requires [addr]:port, not a socket path: \"TCP:///run/foo.sock\"";
  };
  testRejectUnixHostPort = {
    expr = throws (parse "unix://1.2.3.4:80");
    expected = true;
  };
  testRejectUnixHostPortUppercaseScheme = {
    expr = (bindUrl.tryParse "UNIX://1.2.3.4:80").error;
    expected = "libnet.bindUrl.parse: 'unix://' requires a socket path: \"UNIX://1.2.3.4:80\"";
  };
  testRejectBadBindpoint = {
    expr = parse "tcp://:99999";
    expectedError.msg = "^libnet\\.bindUrl\\.parse: invalid port field \"99999\"$";
  };
  testRejectUnknownSchemeBeforeAddress = {
    expr = (bindUrl.tryParse "foo://garbage").error;
    expected = "libnet.bindUrl.parse: unknown scheme \"foo\" (expected tcp, udp, sctp, or unix)";
  };
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectNotString = {
    expr = bindUrl.parse 42;
    expectedError.msg = "^libnet\\.bindUrl\\.parse: expected string, got int$";
  };

  testTryParseOk = {
    expr = (bindUrl.tryParse "tcp://:8080").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (bindUrl.tryParse ":8080").success;
    expected = false;
  };
  testTryParseUnknownSchemeErrorKeepsCase = {
    expr = (bindUrl.tryParse "HTTP://:8080").error;
    expected = "libnet.bindUrl.parse: unknown scheme \"HTTP\" (expected tcp, udp, sctp, or unix)";
  };
  testTryParseBadError = {
    expr = builtins.isString (bindUrl.tryParse "http://:8080").error;
    expected = true;
  };

  # ===== make =====
  testMakeIp = {
    expr = bindUrl.toString (bindUrl.make "tcp" (bindpoint.parse ":8080"));
    expected = "tcp://:8080";
  };
  testMakeRange = {
    expr = bindUrl.toString (bindUrl.make "udp" (bindpoint.parse "[::]:8000-8100"));
    expected = "udp://[::]:8000-8100";
  };
  testMakeUnix = {
    expr = bindUrl.toString (bindUrl.make "unix" (unixSocket.parse "/run/foo.sock"));
    expected = "unix:///run/foo.sock";
  };
  testMakeEqualsParse = {
    expr = bindUrl.make "SCTP" (bindpoint.parse "0.0.0.0:53");
    expected = parse "sctp://0.0.0.0:53";
  };
  testMakeRoundTrips = {
    expr = map (value: bindUrl.eq (parse (bindUrl.toString value)) value) [
      (bindUrl.make "tcp" (bindpoint.parse ":8080"))
      (bindUrl.make "udp" (bindpoint.parse "[::1]:8000-8100"))
      (bindUrl.make "unix" (unixSocket.parse "@foo"))
    ];
    expected = [
      true
      true
      true
    ];
  };
  testMakeMapsOverBindpoints = {
    expr = map bindUrl.toString (
      map (bindUrl.make "tcp") [
        (bindpoint.parse ":80")
        (bindpoint.parse "[::]:443")
      ]
    );
    expected = [
      "tcp://:80"
      "tcp://[::]:443"
    ];
  };
  testMakeUnixSchemeIpBindpointThrows = {
    expr = bindUrl.make "unix" (bindpoint.parse ":8080");
    expectedError.msg = "^libnet\\.bindUrl\\.make: expected unixSocket value for scheme \"unix\", got ipBindpoint value$";
  };
  testMakeTcpSchemeUnixSocketThrows = {
    expr = bindUrl.make "TCP" (unixSocket.parse "/run/foo.sock");
    expectedError.msg = "^libnet\\.bindUrl\\.make: expected ipBindpoint value for scheme \"tcp\", got unixSocket value$";
  };
  testMakeUnknownSchemeThrows = {
    expr = bindUrl.make "tls" (bindpoint.parse ":8080");
    expectedError.msg = "^libnet\\.bindUrl\\.make: unknown scheme \"tls\" \\(expected tcp, udp, sctp, or unix\\)$";
  };
  testMakeNullSchemeThrows = {
    expr = bindUrl.make null (unixSocket.parse "/run/foo.sock");
    expectedError.msg = "^libnet\\.bindUrl\\.make: expected string, got null$";
  };
  testMakeEndpointThrows = {
    expr = bindUrl.make "tcp" (libnet.ipEndpoint.parse "192.0.2.1:80");
    expectedError.msg = "^libnet\\.bindUrl\\.make: expected ipBindpoint or unixSocket value, got ipEndpoint value$";
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = bindUrl.is (parse "tcp://:8080");
    expected = true;
  };
  testIsString = {
    expr = bindUrl.is "tcp://:8080";
    expected = false;
  };
  testIsValidIp = {
    expr = bindUrl.isValid "udp://[::]:53";
    expected = true;
  };
  testIsValidUnix = {
    expr = bindUrl.isValid "unix:///run/foo.sock";
    expected = true;
  };
  testIsValidBad = {
    expr = bindUrl.isValid "ftp://:1";
    expected = false;
  };
  testIsUnixYes = {
    expr = bindUrl.isUnix (parse "unix:///run/foo.sock");
    expected = true;
  };
  testIsUnixNo = {
    expr = bindUrl.isUnix (parse "tcp://:8080");
    expected = false;
  };

  # ===== Comparison helpers =====
  testLtBefore = {
    expr = bindUrl.lt (parse "tcp://:8080") (parse "tcp://:8081");
    expected = true;
  };
  testLeBefore = {
    expr = bindUrl.le (parse "tcp://:8080") (parse "tcp://:8081");
    expected = true;
  };
  testGtAfter = {
    expr = bindUrl.gt (parse "tcp://:8081") (parse "tcp://:8080");
    expected = true;
  };
  testGeAfter = {
    expr = bindUrl.ge (parse "tcp://:8081") (parse "tcp://:8080");
    expected = true;
  };
  testMinPicksLesser = {
    expr = bindUrl.toString (bindUrl.min (parse "tcp://:8080") (parse "tcp://:8081"));
    expected = "tcp://:8080";
  };
  testMaxPicksGreater = {
    expr = bindUrl.toString (bindUrl.max (parse "tcp://:8080") (parse "tcp://:8081"));
    expected = "tcp://:8081";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = bindUrl.eq (parse "tcp://:8080") (parse "tcp://:8080");
    expected = true;
  };
  testEqDifferentTransport = {
    expr = bindUrl.eq (parse "tcp://:8080") (parse "udp://:8080");
    expected = false;
  };
  testEqDifferentBindpoint = {
    expr = bindUrl.eq (parse "tcp://:8080") (parse "tcp://:8081");
    expected = false;
  };
  testEqSchemeCaseInsensitive = {
    expr = bindUrl.eq (parse "TCP://:8080") (parse "tcp://:8080");
    expected = true;
  };
  testEqSameUnix = {
    expr = bindUrl.eq (parse "unix:///run/foo.sock") (parse "unix:///run/foo.sock");
    expected = true;
  };
  testEqCrossFamily = {
    expr = bindUrl.eq (parse "tcp://:8080") (parse "unix:///run/foo.sock");
    expected = false;
  };
  testCompareTcpBeforeUdp = {
    expr = bindUrl.compare (parse "tcp://:8080") (parse "udp://:8080");
    expected = -1;
  };
  testCompareIpBeforeUnix = {
    expr = bindUrl.compare (parse "sctp://:8080") (parse "unix:///run/foo.sock");
    expected = -1;
  };
  testCompareWithinTransportByBindpoint = {
    expr = bindUrl.compare (parse "tcp://:8080") (parse "tcp://:8081");
    expected = -1;
  };
  testCompareEqual = {
    expr = bindUrl.compare (parse "tcp://:8080") (parse "tcp://:8080");
    expected = 0;
  };

  # Schemes sort by name: sctp < tcp < udp < unix.
  testCompareSctpBeforeTcp = {
    expr = bindUrl.compare (parse "sctp://:8080") (parse "tcp://:8080");
    expected = -1;
  };
  testCompareUdpBeforeUnix = {
    expr = bindUrl.compare (parse "udp://:8080") (parse "unix:///run/foo.sock");
    expected = -1;
  };
  testSortByScheme = {
    expr = map bindUrl.scheme (
      builtins.sort bindUrl.lt [
        (parse "unix:///run/foo.sock")
        (parse "udp://:8080")
        (parse "tcp://:8080")
        (parse "sctp://:8080")
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
    expr = bindUrl.scheme (parse "TCP://:8080");
    expected = "tcp";
  };
  testSchemeUnix = {
    expr = bindUrl.scheme (parse "unix:///run/foo.sock");
    expected = "unix";
  };
  testTransportSctp = {
    expr = bindUrl.transport (parse "sctp://:8080");
    expected = transport.sctp;
  };
  testTransportUnixNull = {
    expr = bindUrl.transport (parse "unix:///run/foo.sock");
    expected = null;
  };
  testIsSecureIp = {
    expr = bindUrl.isSecure (parse "tcp://:8080");
    expected = false;
  };
  testIsSecureUnix = {
    expr = bindUrl.isSecure (parse "unix:///run/foo.sock");
    expected = false;
  };

  # ===== Constant =====
  testSchemesRegistry = {
    expr = bindUrl.schemes;
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
    expr = map (name: bindUrl.schemes.${name}.transport) (map transport.toString transport.values);
    expected = [
      "sctp"
      "tcp"
      "udp"
    ];
  };
}
