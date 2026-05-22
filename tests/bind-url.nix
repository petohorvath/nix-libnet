{ harness }:
let
  bindUrl = import ../lib/bind-url.nix;
  transport = import ../lib/transport.nix;
  bindpoint = import ../lib/bindpoint.nix;
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
  p = bindUrl.parse;
in
{
  # ===== Parse: IP schemes =====
  parse-tcp-wildcard = {
    expr = bindUrl.toString (p "tcp://:8080");
    expected = "tcp://:8080";
  };
  parse-udp-explicit-any = {
    expr = bindUrl.toString (p "udp://0.0.0.0:53");
    expected = "udp://0.0.0.0:53";
  };
  parse-tcp-v6-range = {
    expr = bindUrl.toString (p "tcp://[::]:8000-8100");
    expected = "tcp://[::]:8000-8100";
  };
  parse-sctp-v4 = {
    expr = bindUrl.toString (p "sctp://1.2.3.4:80");
    expected = "sctp://1.2.3.4:80";
  };
  parse-wildcard-normalizes = {
    expr = bindUrl.toString (p "tcp://*:8080");
    expected = "tcp://:8080";
  };
  parse-tagged = {
    expr = (p "tcp://:8080")._type;
    expected = "bindUrl";
  };
  parse-transport = {
    expr = transport.toString (bindUrl.transport (p "tcp://:8080"));
    expected = "tcp";
  };
  parse-bindpoint-kind = {
    expr = (bindUrl.bindpoint (p "tcp://:8080"))._type;
    expected = "ipBindpoint";
  };

  # ===== Parse: unix scheme =====
  parse-unix-pathname = {
    expr = bindUrl.toString (p "unix:///run/foo.sock");
    expected = "unix:///run/foo.sock";
  };
  parse-unix-abstract = {
    expr = bindUrl.toString (p "unix://@foo");
    expected = "unix://@foo";
  };
  parse-unix-transport-null = {
    expr = bindUrl.transport (p "unix:///run/foo.sock");
    expected = null;
  };
  parse-unix-bindpoint-kind = {
    expr = (bindUrl.bindpoint (p "unix:///run/foo.sock"))._type;
    expected = "unixSocket";
  };

  # ===== Reject =====
  reject-no-scheme = {
    expr = throws (p ":8080");
    expected = true;
  };
  reject-unknown-scheme = {
    expr = throws (p "http://:8080");
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
  reject-bad-bindpoint = {
    expr = throws (p "tcp://:99999");
    expected = true;
  };
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-not-string = {
    expr = throws (bindUrl.parse 42);
    expected = true;
  };

  tryParse-ok = {
    expr = (bindUrl.tryParse "tcp://:8080").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (bindUrl.tryParse ":8080").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (bindUrl.tryParse "http://:8080").error;
    expected = true;
  };

  # ===== make =====
  make-ip = {
    expr = bindUrl.toString (bindUrl.make (transport.parse "tcp") (bindpoint.parse ":8080"));
    expected = "tcp://:8080";
  };
  make-range = {
    expr = bindUrl.toString (bindUrl.make (transport.parse "udp") (bindpoint.parse "[::]:8000-8100"));
    expected = "udp://[::]:8000-8100";
  };
  make-unix = {
    expr = bindUrl.toString (bindUrl.make null (unixSocket.parse "/run/foo.sock"));
    expected = "unix:///run/foo.sock";
  };
  make-unix-with-transport-throws = {
    expr = throws (bindUrl.make (transport.parse "tcp") (unixSocket.parse "/run/foo.sock"));
    expected = true;
  };
  make-ip-without-transport-throws = {
    expr = throws (bindUrl.make null (bindpoint.parse ":8080"));
    expected = true;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = bindUrl.is (p "tcp://:8080");
    expected = true;
  };
  is-string = {
    expr = bindUrl.is "tcp://:8080";
    expected = false;
  };
  isValid-ip = {
    expr = bindUrl.isValid "udp://[::]:53";
    expected = true;
  };
  isValid-unix = {
    expr = bindUrl.isValid "unix:///run/foo.sock";
    expected = true;
  };
  isValid-bad = {
    expr = bindUrl.isValid "ftp://:1";
    expected = false;
  };
  isUnix-yes = {
    expr = bindUrl.isUnix (p "unix:///run/foo.sock");
    expected = true;
  };
  isUnix-no = {
    expr = bindUrl.isUnix (p "tcp://:8080");
    expected = false;
  };

  # ===== Comparison helpers =====
  cmp-lt = {
    expr = bindUrl.lt (p "tcp://:8080") (p "tcp://:8081");
    expected = true;
  };
  cmp-le = {
    expr = bindUrl.le (p "tcp://:8080") (p "tcp://:8081");
    expected = true;
  };
  cmp-gt = {
    expr = bindUrl.gt (p "tcp://:8081") (p "tcp://:8080");
    expected = true;
  };
  cmp-ge = {
    expr = bindUrl.ge (p "tcp://:8081") (p "tcp://:8080");
    expected = true;
  };
  cmp-min = {
    expr = bindUrl.toString (bindUrl.min (p "tcp://:8080") (p "tcp://:8081"));
    expected = "tcp://:8080";
  };
  cmp-max = {
    expr = bindUrl.toString (bindUrl.max (p "tcp://:8080") (p "tcp://:8081"));
    expected = "tcp://:8081";
  };

  # ===== Comparison =====
  eq-same = {
    expr = bindUrl.eq (p "tcp://:8080") (p "tcp://:8080");
    expected = true;
  };
  eq-diff-transport = {
    expr = bindUrl.eq (p "tcp://:8080") (p "udp://:8080");
    expected = false;
  };
  eq-diff-bindpoint = {
    expr = bindUrl.eq (p "tcp://:8080") (p "tcp://:8081");
    expected = false;
  };
  eq-same-unix = {
    expr = bindUrl.eq (p "unix:///run/foo.sock") (p "unix:///run/foo.sock");
    expected = true;
  };
  eq-cross-family = {
    expr = bindUrl.eq (p "tcp://:8080") (p "unix:///run/foo.sock");
    expected = false;
  };
  compare-tcp-before-udp = {
    expr = bindUrl.compare (p "tcp://:8080") (p "udp://:8080");
    expected = -1;
  };
  compare-ip-before-unix = {
    expr = bindUrl.compare (p "sctp://:8080") (p "unix:///run/foo.sock");
    expected = -1;
  };
  compare-within-transport-by-bindpoint = {
    expr = bindUrl.compare (p "tcp://:8080") (p "tcp://:8081");
    expected = -1;
  };
  compare-equal = {
    expr = bindUrl.compare (p "tcp://:8080") (p "tcp://:8080");
    expected = 0;
  };

  # ===== Constant =====
  schemes-list = {
    expr = bindUrl.schemes;
    expected = [
      "tcp"
      "udp"
      "sctp"
      "unix"
    ];
  };
}
