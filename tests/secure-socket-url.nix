{ harness }:
let
  secureSocketUrl = import ../lib/secure-socket-url.nix;
  transport = import ../lib/transport.nix;
  endpoint = import ../lib/endpoint.nix;
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
  p = secureSocketUrl.parse;
in
{
  # ===== Parse: schemes & dialects =====
  parse-tls-ipv4 = {
    expr = secureSocketUrl.toString (p "tls://1.2.3.4:443");
    expected = "tls://1.2.3.4:443";
  };
  parse-dtls-ipv6 = {
    expr = secureSocketUrl.toString (p "dtls://[::1]:5684");
    expected = "dtls://[::1]:5684";
  };
  parse-quic-dns = {
    expr = secureSocketUrl.toString (p "quic://example.com:443");
    expected = "quic://example.com:443";
  };
  parse-ssl-canonicalizes = {
    expr = secureSocketUrl.toString (p "ssl://1.2.3.4:443");
    expected = "tls://1.2.3.4:443";
  };
  parse-scheme-case-insensitive = {
    expr = secureSocketUrl.toString (p "TLS://1.2.3.4:443");
    expected = "tls://1.2.3.4:443";
  };
  parse-ssl-uppercase-canonicalizes = {
    expr = secureSocketUrl.toString (p "SSL://1.2.3.4:443");
    expected = "tls://1.2.3.4:443";
  };
  parse-tagged = {
    expr = (p "tls://1.2.3.4:443")._type;
    expected = "secureSocketUrl";
  };
  parse-scheme-accessor = {
    expr = secureSocketUrl.scheme (p "quic://example.com:443");
    expected = "quic";
  };
  parse-endpoint-kind-ip = {
    expr = (secureSocketUrl.endpoint (p "tls://1.2.3.4:443"))._type;
    expected = "ipEndpoint";
  };
  parse-endpoint-kind-dns = {
    expr = (secureSocketUrl.endpoint (p "tls://example.com:443"))._type;
    expected = "dnsEndpoint";
  };

  # ===== Derived transport =====
  transport-tls-tcp = {
    expr = transport.toString (secureSocketUrl.transport (p "tls://1.2.3.4:443"));
    expected = "tcp";
  };
  transport-dtls-udp = {
    expr = transport.toString (secureSocketUrl.transport (p "dtls://1.2.3.4:443"));
    expected = "udp";
  };
  transport-quic-udp = {
    expr = transport.toString (secureSocketUrl.transport (p "quic://1.2.3.4:443"));
    expected = "udp";
  };

  # ===== Reject =====
  reject-no-scheme = {
    expr = throws (p "1.2.3.4:443");
    expected = true;
  };
  reject-plaintext-tcp = {
    expr = throws (p "tcp://1.2.3.4:443");
    expected = true;
  };
  reject-unknown-scheme = {
    expr = throws (p "http://1.2.3.4:443");
    expected = true;
  };
  reject-unix = {
    expr = throws (p "unix:///run/foo.sock");
    expected = true;
  };
  reject-tls-path = {
    expr = throws (p "tls:///run/foo.sock");
    expected = true;
  };
  reject-bad-endpoint = {
    expr = throws (p "tls://host_name:1");
    expected = true;
  };
  reject-missing-port = {
    expr = throws (p "tls://1.2.3.4");
    expected = true;
  };
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-not-string = {
    expr = throws (secureSocketUrl.parse 42);
    expected = true;
  };

  tryParse-ok = {
    expr = (secureSocketUrl.tryParse "tls://1.2.3.4:443").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (secureSocketUrl.tryParse "tcp://1.2.3.4:443").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (secureSocketUrl.tryParse "tcp://x:1").error;
    expected = true;
  };

  # ===== make =====
  make-tls = {
    expr = secureSocketUrl.toString (secureSocketUrl.make "tls" (endpoint.parse "1.2.3.4:443"));
    expected = "tls://1.2.3.4:443";
  };
  make-ssl-canonicalizes = {
    expr = secureSocketUrl.toString (secureSocketUrl.make "ssl" (endpoint.parse "1.2.3.4:443"));
    expected = "tls://1.2.3.4:443";
  };
  make-quic = {
    expr = secureSocketUrl.toString (secureSocketUrl.make "quic" (endpoint.parse "example.com:443"));
    expected = "quic://example.com:443";
  };
  make-unknown-scheme-throws = {
    expr = throws (secureSocketUrl.make "tcp" (endpoint.parse "1.2.3.4:443"));
    expected = true;
  };
  make-unix-throws = {
    expr = throws (secureSocketUrl.make "tls" (unixSocket.parse "/run/foo.sock"));
    expected = true;
  };
  make-non-endpoint-throws = {
    expr = throws (secureSocketUrl.make "tls" "1.2.3.4:443");
    expected = true;
  };
  make-non-string-scheme-throws = {
    expr = throws (secureSocketUrl.make 42 (endpoint.parse "1.2.3.4:443"));
    expected = true;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = secureSocketUrl.is (p "tls://1.2.3.4:443");
    expected = true;
  };
  is-string = {
    expr = secureSocketUrl.is "tls://1.2.3.4:443";
    expected = false;
  };
  isValid-tls = {
    expr = secureSocketUrl.isValid "tls://[::1]:443";
    expected = true;
  };
  isValid-quic = {
    expr = secureSocketUrl.isValid "quic://example.com:443";
    expected = true;
  };
  isValid-bad = {
    expr = secureSocketUrl.isValid "tcp://x:1";
    expected = false;
  };
  isSecure-tls = {
    expr = secureSocketUrl.isSecure (p "tls://1.2.3.4:443");
    expected = true;
  };
  isSecure-quic = {
    expr = secureSocketUrl.isSecure (p "quic://1.2.3.4:443");
    expected = true;
  };

  # ===== Comparison helpers =====
  cmp-lt = {
    expr = secureSocketUrl.lt (p "tls://1.2.3.4:443") (p "tls://1.2.3.4:444");
    expected = true;
  };
  cmp-le = {
    expr = secureSocketUrl.le (p "tls://1.2.3.4:443") (p "tls://1.2.3.4:444");
    expected = true;
  };
  cmp-gt = {
    expr = secureSocketUrl.gt (p "tls://1.2.3.4:444") (p "tls://1.2.3.4:443");
    expected = true;
  };
  cmp-ge = {
    expr = secureSocketUrl.ge (p "tls://1.2.3.4:444") (p "tls://1.2.3.4:443");
    expected = true;
  };
  cmp-min = {
    expr = secureSocketUrl.toString (
      secureSocketUrl.min (p "tls://1.2.3.4:443") (p "tls://1.2.3.4:444")
    );
    expected = "tls://1.2.3.4:443";
  };
  cmp-max = {
    expr = secureSocketUrl.toString (
      secureSocketUrl.max (p "tls://1.2.3.4:443") (p "tls://1.2.3.4:444")
    );
    expected = "tls://1.2.3.4:444";
  };

  # ===== Comparison =====
  eq-same = {
    expr = secureSocketUrl.eq (p "tls://1.2.3.4:443") (p "tls://1.2.3.4:443");
    expected = true;
  };
  eq-ssl-equals-tls = {
    expr = secureSocketUrl.eq (p "ssl://1.2.3.4:443") (p "tls://1.2.3.4:443");
    expected = true;
  };
  # dtls and quic are both UDP+TLS but distinct schemes — the registry
  # model keeps them apart where a transport+flag model could not.
  eq-dtls-not-quic = {
    expr = secureSocketUrl.eq (p "dtls://1.2.3.4:443") (p "quic://1.2.3.4:443");
    expected = false;
  };
  eq-diff-endpoint = {
    expr = secureSocketUrl.eq (p "tls://1.2.3.4:443") (p "tls://1.2.3.4:444");
    expected = false;
  };
  eq-dns-case-insensitive = {
    expr = secureSocketUrl.eq (p "tls://Example.COM:443") (p "tls://example.com:443");
    expected = true;
  };
  compare-tls-before-dtls = {
    expr = secureSocketUrl.compare (p "tls://1.2.3.4:443") (p "dtls://1.2.3.4:443");
    expected = -1;
  };
  compare-dtls-before-quic = {
    expr = secureSocketUrl.compare (p "dtls://1.2.3.4:443") (p "quic://1.2.3.4:443");
    expected = -1;
  };
  compare-within-scheme-by-endpoint = {
    expr = secureSocketUrl.compare (p "tls://1.2.3.4:443") (p "tls://1.2.3.4:444");
    expected = -1;
  };
  compare-equal = {
    expr = secureSocketUrl.compare (p "tls://1.2.3.4:443") (p "tls://1.2.3.4:443");
    expected = 0;
  };

  # ===== Constants =====
  schemes-registry = {
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
  aliases-const = {
    expr = secureSocketUrl.aliases;
    expected = {
      ssl = "tls";
    };
  };
}
