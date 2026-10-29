{ helpers, libnet, ... }:
let
  inherit (libnet)
    endpoint
    secureSocketUrl
    transport
    unixSocket
    ;
  inherit (helpers) throws;
  inherit (secureSocketUrl) parse;
in
{
  # ===== Parse: schemes & dialects =====
  testParseTlsIpv4 = {
    expr = secureSocketUrl.toString (parse "tls://1.2.3.4:443");
    expected = "tls://1.2.3.4:443";
  };
  testParseDtlsIpv6 = {
    expr = secureSocketUrl.toString (parse "dtls://[::1]:5684");
    expected = "dtls://[::1]:5684";
  };
  testParseQuicDns = {
    expr = secureSocketUrl.toString (parse "quic://example.com:443");
    expected = "quic://example.com:443";
  };
  testParseSslCanonicalizes = {
    expr = secureSocketUrl.toString (parse "ssl://1.2.3.4:443");
    expected = "tls://1.2.3.4:443";
  };
  testParseSchemeCaseInsensitive = {
    expr = secureSocketUrl.toString (parse "TLS://1.2.3.4:443");
    expected = "tls://1.2.3.4:443";
  };
  testParseSslUppercaseCanonicalizes = {
    expr = secureSocketUrl.toString (parse "SSL://1.2.3.4:443");
    expected = "tls://1.2.3.4:443";
  };
  testParseTagged = {
    expr = (parse "tls://1.2.3.4:443")._type;
    expected = "secureSocketUrl";
  };
  testParseSchemeAccessor = {
    expr = secureSocketUrl.scheme (parse "quic://example.com:443");
    expected = "quic";
  };
  testParseEndpointKindIp = {
    expr = (secureSocketUrl.endpoint (parse "tls://1.2.3.4:443"))._type;
    expected = "ipEndpoint";
  };
  testParseEndpointKindDns = {
    expr = (secureSocketUrl.endpoint (parse "tls://example.com:443"))._type;
    expected = "dnsEndpoint";
  };

  # ===== Derived transport =====
  testTransportTlsTcp = {
    expr = transport.toString (secureSocketUrl.transport (parse "tls://1.2.3.4:443"));
    expected = "tcp";
  };
  testTransportDtlsUdp = {
    expr = transport.toString (secureSocketUrl.transport (parse "dtls://1.2.3.4:443"));
    expected = "udp";
  };
  testTransportQuicUdp = {
    expr = transport.toString (secureSocketUrl.transport (parse "quic://1.2.3.4:443"));
    expected = "udp";
  };

  # ===== Reject =====
  testRejectNoScheme = {
    expr = throws (parse "1.2.3.4:443");
    expected = true;
  };
  testRejectPlaintextTcp = {
    expr = throws (parse "tcp://1.2.3.4:443");
    expected = true;
  };
  testRejectUnknownScheme = {
    expr = throws (parse "http://1.2.3.4:443");
    expected = true;
  };
  testRejectUnix = {
    expr = throws (parse "unix:///run/foo.sock");
    expected = true;
  };
  testRejectTlsPath = {
    expr = throws (parse "tls:///run/foo.sock");
    expected = true;
  };
  testRejectBadEndpoint = {
    expr = parse "tls://host_name:1";
    expectedError.msg = "^libnet\\.secureSocketUrl\\.parse: \"host_name:1\" is not a valid IP, name, or unix-socket endpoint$";
  };
  testRejectMissingPort = {
    expr = parse "tls://1.2.3.4";
    expectedError.msg = "^libnet\\.secureSocketUrl\\.parse: \"1\\.2\\.3\\.4\" is not a valid IP, name, or unix-socket endpoint$";
  };
  testRejectUnknownSchemeBeforeAddress = {
    expr = (secureSocketUrl.tryParse "foo://garbage").error;
    expected = "libnet.secureSocketUrl.parse: unknown scheme \"foo\" (expected tls/ssl, dtls, or quic)";
  };
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectNotString = {
    expr = secureSocketUrl.parse 42;
    expectedError.msg = "^libnet\\.secureSocketUrl\\.parse: expected string, got int$";
  };

  testTryParseOk = {
    expr = (secureSocketUrl.tryParse "tls://1.2.3.4:443").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (secureSocketUrl.tryParse "tcp://1.2.3.4:443").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = builtins.isString (secureSocketUrl.tryParse "tcp://x:1").error;
    expected = true;
  };

  # ===== make =====
  testMakeTls = {
    expr = secureSocketUrl.toString (secureSocketUrl.make "tls" (endpoint.parse "1.2.3.4:443"));
    expected = "tls://1.2.3.4:443";
  };
  testMakeSslCanonicalizes = {
    expr = secureSocketUrl.toString (secureSocketUrl.make "ssl" (endpoint.parse "1.2.3.4:443"));
    expected = "tls://1.2.3.4:443";
  };
  testMakeQuic = {
    expr = secureSocketUrl.toString (secureSocketUrl.make "quic" (endpoint.parse "example.com:443"));
    expected = "quic://example.com:443";
  };
  testMakeSchemeCaseInsensitive = {
    expr = secureSocketUrl.make "SSL" (endpoint.parse "example.com:443");
    expected = parse "tls://example.com:443";
  };
  testMakeRoundTrips = {
    expr = map (value: secureSocketUrl.eq (parse (secureSocketUrl.toString value)) value) [
      (secureSocketUrl.make "tls" (endpoint.parse "1.2.3.4:443"))
      (secureSocketUrl.make "dtls" (endpoint.parse "[::1]:5684"))
      (secureSocketUrl.make "quic" (endpoint.parse "example.com:443"))
    ];
    expected = [
      true
      true
      true
    ];
  };
  testMakeUnknownSchemeThrows = {
    expr = secureSocketUrl.make "tcp" (endpoint.parse "1.2.3.4:443");
    expectedError.msg = "^libnet\\.secureSocketUrl\\.make: unknown scheme \"tcp\" \\(expected tls/ssl, dtls, or quic\\)$";
  };
  testMakeUnixThrows = {
    expr = secureSocketUrl.make "tls" (unixSocket.parse "/run/foo.sock");
    expectedError.msg = "^libnet\\.secureSocketUrl\\.make: expected ipEndpoint or dnsEndpoint value, got unixSocket value$";
  };
  testMakeNonEndpointThrows = {
    expr = secureSocketUrl.make "tls" "1.2.3.4:443";
    expectedError.msg = "^libnet\\.secureSocketUrl\\.make: expected ipEndpoint or dnsEndpoint value, got string$";
  };
  testMakeNonStringSchemeThrows = {
    expr = secureSocketUrl.make 42 (endpoint.parse "1.2.3.4:443");
    expectedError.msg = "^libnet\\.secureSocketUrl\\.make: expected string, got int$";
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = secureSocketUrl.is (parse "tls://1.2.3.4:443");
    expected = true;
  };
  testIsString = {
    expr = secureSocketUrl.is "tls://1.2.3.4:443";
    expected = false;
  };
  testIsValidTls = {
    expr = secureSocketUrl.isValid "tls://[::1]:443";
    expected = true;
  };
  testIsValidQuic = {
    expr = secureSocketUrl.isValid "quic://example.com:443";
    expected = true;
  };
  testIsValidBad = {
    expr = secureSocketUrl.isValid "tcp://x:1";
    expected = false;
  };
  testIsSecureTls = {
    expr = secureSocketUrl.isSecure (parse "tls://1.2.3.4:443");
    expected = true;
  };
  testIsSecureQuic = {
    expr = secureSocketUrl.isSecure (parse "quic://1.2.3.4:443");
    expected = true;
  };

  # ===== Comparison helpers =====
  testLtBefore = {
    expr = secureSocketUrl.lt (parse "tls://1.2.3.4:443") (parse "tls://1.2.3.4:444");
    expected = true;
  };
  testLeBefore = {
    expr = secureSocketUrl.le (parse "tls://1.2.3.4:443") (parse "tls://1.2.3.4:444");
    expected = true;
  };
  testGtAfter = {
    expr = secureSocketUrl.gt (parse "tls://1.2.3.4:444") (parse "tls://1.2.3.4:443");
    expected = true;
  };
  testGeAfter = {
    expr = secureSocketUrl.ge (parse "tls://1.2.3.4:444") (parse "tls://1.2.3.4:443");
    expected = true;
  };
  testMinPicksLesser = {
    expr = secureSocketUrl.toString (
      secureSocketUrl.min (parse "tls://1.2.3.4:443") (parse "tls://1.2.3.4:444")
    );
    expected = "tls://1.2.3.4:443";
  };
  testMaxPicksGreater = {
    expr = secureSocketUrl.toString (
      secureSocketUrl.max (parse "tls://1.2.3.4:443") (parse "tls://1.2.3.4:444")
    );
    expected = "tls://1.2.3.4:444";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = secureSocketUrl.eq (parse "tls://1.2.3.4:443") (parse "tls://1.2.3.4:443");
    expected = true;
  };
  testEqSslEqualsTls = {
    expr = secureSocketUrl.eq (parse "ssl://1.2.3.4:443") (parse "tls://1.2.3.4:443");
    expected = true;
  };
  # dtls and quic are both UDP+TLS but distinct schemes — the registry
  # model keeps them apart where a transport+flag model could not.
  testEqDtlsNotQuic = {
    expr = secureSocketUrl.eq (parse "dtls://1.2.3.4:443") (parse "quic://1.2.3.4:443");
    expected = false;
  };
  testEqDifferentEndpoint = {
    expr = secureSocketUrl.eq (parse "tls://1.2.3.4:443") (parse "tls://1.2.3.4:444");
    expected = false;
  };
  testEqDnsCaseInsensitive = {
    expr = secureSocketUrl.eq (parse "tls://Example.COM:443") (parse "tls://example.com:443");
    expected = true;
  };
  # Schemes sort by name: dtls < quic < tls.
  testCompareDtlsBeforeTls = {
    expr = secureSocketUrl.compare (parse "dtls://1.2.3.4:443") (parse "tls://1.2.3.4:443");
    expected = -1;
  };
  testCompareDtlsBeforeQuic = {
    expr = secureSocketUrl.compare (parse "dtls://1.2.3.4:443") (parse "quic://1.2.3.4:443");
    expected = -1;
  };
  testCompareSslSortsAsTls = {
    expr = secureSocketUrl.compare (parse "ssl://1.2.3.4:443") (parse "quic://1.2.3.4:443");
    expected = 1;
  };
  testCompareWithinSchemeByEndpoint = {
    expr = secureSocketUrl.compare (parse "tls://1.2.3.4:443") (parse "tls://1.2.3.4:444");
    expected = -1;
  };
  testCompareEqual = {
    expr = secureSocketUrl.compare (parse "tls://1.2.3.4:443") (parse "tls://1.2.3.4:443");
    expected = 0;
  };

  # ===== Constants =====
  testSchemesRegistry = {
    expr = secureSocketUrl.schemes;
    expected = {
      dtls = {
        transport = "udp";
        secure = true;
      };
      quic = {
        transport = "udp";
        secure = true;
      };
      tls = {
        transport = "tcp";
        secure = true;
      };
    };
  };
  # `ssl` is an input spelling of `tls`, not a scheme of its own.
  testSchemesExcludeSsl = {
    expr = secureSocketUrl.schemes ? ssl;
    expected = false;
  };
}
