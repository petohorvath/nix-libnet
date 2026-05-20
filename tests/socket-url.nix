{ harness }:
let
  socketUrl = import ../lib/socket-url.nix;
  transport = import ../lib/transport.nix;
  endpoint = import ../lib/endpoint.nix;
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
  p = socketUrl.parse;
in
{
  # ===== Parse: IP schemes =====
  parse-tcp-ipv4 = {
    expr = socketUrl.toString (p "tcp://1.2.3.4:80");
    expected = "tcp://1.2.3.4:80";
  };
  parse-udp-ipv6 = {
    expr = socketUrl.toString (p "udp://[::1]:53");
    expected = "udp://[::1]:53";
  };
  parse-sctp-dns = {
    expr = socketUrl.toString (p "sctp://pool.ntp.org:9999");
    expected = "sctp://pool.ntp.org:9999";
  };
  parse-tagged = {
    expr = (p "tcp://1.2.3.4:80")._type;
    expected = "socketUrl";
  };
  parse-transport = {
    expr = transport.toString (socketUrl.transport (p "tcp://1.2.3.4:80"));
    expected = "tcp";
  };
  parse-endpoint-kind = {
    expr = (socketUrl.endpoint (p "tcp://1.2.3.4:80"))._type;
    expected = "ipEndpoint";
  };
  parse-dns-endpoint-kind = {
    expr = (socketUrl.endpoint (p "tcp://pool.ntp.org:123"))._type;
    expected = "dnsEndpoint";
  };

  # ===== Parse: unix scheme =====
  parse-unix-pathname = {
    expr = socketUrl.toString (p "unix:///run/foo.sock");
    expected = "unix:///run/foo.sock";
  };
  parse-unix-abstract = {
    expr = socketUrl.toString (p "unix://@foo");
    expected = "unix://@foo";
  };
  parse-unix-transport-null = {
    expr = socketUrl.transport (p "unix:///run/foo.sock");
    expected = null;
  };
  parse-unix-endpoint-kind = {
    expr = (socketUrl.endpoint (p "unix:///run/foo.sock"))._type;
    expected = "unixSocket";
  };

  # ===== Reject =====
  reject-no-scheme = {
    expr = throws (p "1.2.3.4:80");
    expected = true;
  };
  reject-unknown-scheme = {
    expr = throws (p "http://1.2.3.4:80");
    expected = true;
  };
  reject-icmp-scheme = {
    expr = throws (p "icmp://1.2.3.4:80");
    expected = true;
  };
  reject-tcp-path = {
    expr = throws (p "tcp:///run/foo.sock");
    expected = true;
  };
  reject-unix-host-port = {
    expr = throws (p "unix://1.2.3.4:80");
    expected = true;
  };
  reject-bad-endpoint = {
    expr = throws (p "tcp://host_name:1");
    expected = true;
  };
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-not-string = {
    expr = throws (socketUrl.parse 42);
    expected = true;
  };

  tryParse-ok = {
    expr = (socketUrl.tryParse "tcp://1.2.3.4:80").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (socketUrl.tryParse "1.2.3.4:80").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (socketUrl.tryParse "http://x:1").error;
    expected = true;
  };

  # ===== make =====
  make-ip = {
    expr = socketUrl.toString (socketUrl.make (transport.parse "tcp") (endpoint.parse "1.2.3.4:80"));
    expected = "tcp://1.2.3.4:80";
  };
  make-unix = {
    expr = socketUrl.toString (socketUrl.make null (unixSocket.parse "/run/foo.sock"));
    expected = "unix:///run/foo.sock";
  };
  make-unix-with-transport-throws = {
    expr = throws (socketUrl.make (transport.parse "tcp") (unixSocket.parse "/run/foo.sock"));
    expected = true;
  };
  make-ip-without-transport-throws = {
    expr = throws (socketUrl.make null (endpoint.parse "1.2.3.4:80"));
    expected = true;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = socketUrl.is (p "tcp://1.2.3.4:80");
    expected = true;
  };
  is-string = {
    expr = socketUrl.is "tcp://1.2.3.4:80";
    expected = false;
  };
  isValid-ip = {
    expr = socketUrl.isValid "udp://[::]:53";
    expected = true;
  };
  isValid-unix = {
    expr = socketUrl.isValid "unix:///run/foo.sock";
    expected = true;
  };
  isValid-bad = {
    expr = socketUrl.isValid "ftp://x:1";
    expected = false;
  };
  isUnix-yes = {
    expr = socketUrl.isUnix (p "unix:///run/foo.sock");
    expected = true;
  };
  isUnix-no = {
    expr = socketUrl.isUnix (p "tcp://1.2.3.4:80");
    expected = false;
  };

  # ===== Comparison =====
  eq-same = {
    expr = socketUrl.eq (p "tcp://1.2.3.4:80") (p "tcp://1.2.3.4:80");
    expected = true;
  };
  eq-diff-transport = {
    expr = socketUrl.eq (p "tcp://1.2.3.4:80") (p "udp://1.2.3.4:80");
    expected = false;
  };
  eq-diff-endpoint = {
    expr = socketUrl.eq (p "tcp://1.2.3.4:80") (p "tcp://1.2.3.4:81");
    expected = false;
  };
  eq-dns-case-insensitive = {
    expr = socketUrl.eq (p "tcp://Pool.NTP.org:123") (p "tcp://pool.ntp.org:123");
    expected = true;
  };
  eq-same-unix = {
    expr = socketUrl.eq (p "unix:///run/foo.sock") (p "unix:///run/foo.sock");
    expected = true;
  };
  eq-cross-family = {
    expr = socketUrl.eq (p "tcp://1.2.3.4:80") (p "unix:///run/foo.sock");
    expected = false;
  };
  compare-tcp-before-udp = {
    expr = socketUrl.compare (p "tcp://1.2.3.4:80") (p "udp://1.2.3.4:80");
    expected = -1;
  };
  compare-ip-before-unix = {
    expr = socketUrl.compare (p "sctp://1.2.3.4:80") (p "unix:///run/foo.sock");
    expected = -1;
  };
  compare-within-transport-by-endpoint = {
    expr = socketUrl.compare (p "tcp://1.2.3.4:80") (p "tcp://1.2.3.4:81");
    expected = -1;
  };
  compare-equal = {
    expr = socketUrl.compare (p "tcp://1.2.3.4:80") (p "tcp://1.2.3.4:80");
    expected = 0;
  };

  # ===== Constant =====
  schemes-list = {
    expr = socketUrl.schemes;
    expected = [
      "tcp"
      "udp"
      "sctp"
      "unix"
    ];
  };
}
