{ harness }:
let
  listener = import ../lib/listener.nix;
  ipListener = import ../lib/ip-listener.nix;
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
  p = listener.parse;
in
{
  # ===== Dispatch =====
  parse-ip-tagged = {
    expr = (p "0.0.0.0:8080")._type;
    expected = "ipListener";
  };
  parse-wildcard-tagged = {
    expr = (p ":8080")._type;
    expected = "ipListener";
  };
  parse-range-tagged = {
    expr = (p "1.2.3.4:8000-8100")._type;
    expected = "ipListener";
  };
  parse-unix-tagged = {
    expr = (p "/run/foo.sock")._type;
    expected = "unixSocket";
  };
  parse-unix-abstract = {
    expr = (p "@foo")._type;
    expected = "unixSocket";
  };
  parse-ip-roundtrip = {
    expr = listener.toString (p "1.2.3.4:8000-8100");
    expected = "1.2.3.4:8000-8100";
  };
  parse-unix-roundtrip = {
    expr = listener.toString (p "/run/foo.sock");
    expected = "/run/foo.sock";
  };

  # ===== Reject =====
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-bad-port = {
    expr = throws (p ":99999");
    expected = true;
  };
  reject-not-string = {
    expr = throws (listener.parse 42);
    expected = true;
  };

  tryParse-ok-ip = {
    expr = (listener.tryParse ":80").success;
    expected = true;
  };
  tryParse-ok-unix = {
    expr = (listener.tryParse "/run/foo.sock").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (listener.tryParse "host_name:1").success;
    expected = false;
  };

  # ===== Predicates =====
  is-ip = {
    expr = listener.is (p ":8080");
    expected = true;
  };
  is-unix = {
    expr = listener.is (p "/run/foo.sock");
    expected = true;
  };
  is-string = {
    expr = listener.is ":8080";
    expected = false;
  };
  isIpListener-yes = {
    expr = listener.isIpListener (p ":8080");
    expected = true;
  };
  isIpListener-no = {
    expr = listener.isIpListener (p "/run/foo.sock");
    expected = false;
  };
  isUnixSocket-yes = {
    expr = listener.isUnixSocket (p "/run/foo.sock");
    expected = true;
  };
  isUnixSocket-no = {
    expr = listener.isUnixSocket (p ":8080");
    expected = false;
  };
  isValid-ip = {
    expr = listener.isValid ":8080";
    expected = true;
  };
  isValid-unix = {
    expr = listener.isValid "/run/foo.sock";
    expected = true;
  };
  isValid-bad = {
    expr = listener.isValid "host_name:1";
    expected = false;
  };

  # ===== Comparison helpers =====
  cmp-lt = {
    expr = listener.lt (p ":8080") (p ":8081");
    expected = true;
  };
  cmp-le = {
    expr = listener.le (p ":8080") (p ":8081");
    expected = true;
  };
  cmp-gt = {
    expr = listener.gt (p ":8081") (p ":8080");
    expected = true;
  };
  cmp-ge = {
    expr = listener.ge (p ":8081") (p ":8080");
    expected = true;
  };
  cmp-max = {
    expr = listener.toString (listener.max (p ":8080") (p ":8081"));
    expected = ":8081";
  };

  # ===== Comparison =====
  eq-same-ip = {
    expr = listener.eq (p ":8080") (p ":8080");
    expected = true;
  };
  eq-same-unix = {
    expr = listener.eq (p "/run/foo.sock") (p "/run/foo.sock");
    expected = true;
  };
  eq-cross-kind = {
    expr = listener.eq (p ":8080") (p "/run/foo.sock");
    expected = false;
  };
  compare-ip-before-unix = {
    expr = listener.compare (p ":8080") (p "/run/foo.sock");
    expected = -1;
  };
  compare-unix-after-ip = {
    expr = listener.compare (p "/run/foo.sock") (p ":8080");
    expected = 1;
  };
  min-picks-ip = {
    expr = (listener.min (p "/run/foo.sock") (p ":8080"))._type;
    expected = "ipListener";
  };

  # Sanity: union recognises values from each member module
  is-from-ip-module = {
    expr = listener.is (ipListener.parse ":8080");
    expected = true;
  };
  is-from-unix-module = {
    expr = listener.is (unixSocket.parse "/run/foo.sock");
    expected = true;
  };
}
