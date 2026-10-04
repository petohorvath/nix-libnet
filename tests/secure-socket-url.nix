{ harness }:
let
  secureSocketUrl = import ../lib/secure-socket-url.nix;
  transport = import ../lib/transport.nix;
  endpoint = import ../lib/endpoint.nix;
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
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
    expr = throws (parse "tls://host_name:1");
    expected = true;
  };
  testRejectMissingPort = {
    expr = throws (parse "tls://1.2.3.4");
    expected = true;
  };
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (secureSocketUrl.parse 42);
    expected = true;
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
  testMakeUnknownSchemeThrows = {
    expr = throws (secureSocketUrl.make "tcp" (endpoint.parse "1.2.3.4:443"));
    expected = true;
  };
  testMakeUnixThrows = {
    expr = throws (secureSocketUrl.make "tls" (unixSocket.parse "/run/foo.sock"));
    expected = true;
  };
  testMakeNonEndpointThrows = {
    expr = throws (secureSocketUrl.make "tls" "1.2.3.4:443");
    expected = true;
  };
  testMakeNonStringSchemeThrows = {
    expr = throws (secureSocketUrl.make 42 (endpoint.parse "1.2.3.4:443"));
    expected = true;
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
  testCompareTlsBeforeDtls = {
    expr = secureSocketUrl.compare (parse "tls://1.2.3.4:443") (parse "dtls://1.2.3.4:443");
    expected = -1;
  };
  testCompareDtlsBeforeQuic = {
    expr = secureSocketUrl.compare (parse "dtls://1.2.3.4:443") (parse "quic://1.2.3.4:443");
    expected = -1;
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
      tls = {
        transport = "tcp";
      };
      dtls = {
        transport = "udp";
      };
      quic = {
        transport = "udp";
      };
    };
  };
  testAliasesConstant = {
    expr = secureSocketUrl.aliases;
    expected = {
      ssl = "tls";
    };
  };
}
