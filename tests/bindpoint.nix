{ harness }:
let
  bindpoint = import ../lib/bindpoint.nix;
  ipBindpoint = import ../lib/ip-bindpoint.nix;
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
  p = bindpoint.parse;
in
{
  # ===== Dispatch =====
  parse-ip-tagged = {
    expr = (p "0.0.0.0:8080")._type;
    expected = "ipBindpoint";
  };
  parse-wildcard-tagged = {
    expr = (p ":8080")._type;
    expected = "ipBindpoint";
  };
  parse-range-tagged = {
    expr = (p "1.2.3.4:8000-8100")._type;
    expected = "ipBindpoint";
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
    expr = bindpoint.toString (p "1.2.3.4:8000-8100");
    expected = "1.2.3.4:8000-8100";
  };
  parse-unix-roundtrip = {
    expr = bindpoint.toString (p "/run/foo.sock");
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
    expr = throws (bindpoint.parse 42);
    expected = true;
  };

  tryParse-ok-ip = {
    expr = (bindpoint.tryParse ":80").success;
    expected = true;
  };
  tryParse-ok-unix = {
    expr = (bindpoint.tryParse "/run/foo.sock").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (bindpoint.tryParse "host_name:1").success;
    expected = false;
  };

  # ===== Predicates =====
  is-ip = {
    expr = bindpoint.is (p ":8080");
    expected = true;
  };
  is-unix = {
    expr = bindpoint.is (p "/run/foo.sock");
    expected = true;
  };
  is-string = {
    expr = bindpoint.is ":8080";
    expected = false;
  };
  isIpBindpoint-yes = {
    expr = bindpoint.isIpBindpoint (p ":8080");
    expected = true;
  };
  isIpBindpoint-no = {
    expr = bindpoint.isIpBindpoint (p "/run/foo.sock");
    expected = false;
  };
  isUnixSocket-yes = {
    expr = bindpoint.isUnixSocket (p "/run/foo.sock");
    expected = true;
  };
  isUnixSocket-no = {
    expr = bindpoint.isUnixSocket (p ":8080");
    expected = false;
  };
  isValid-ip = {
    expr = bindpoint.isValid ":8080";
    expected = true;
  };
  isValid-unix = {
    expr = bindpoint.isValid "/run/foo.sock";
    expected = true;
  };
  isValid-bad = {
    expr = bindpoint.isValid "host_name:1";
    expected = false;
  };

  # ===== Comparison helpers =====
  cmp-lt = {
    expr = bindpoint.lt (p ":8080") (p ":8081");
    expected = true;
  };
  cmp-le = {
    expr = bindpoint.le (p ":8080") (p ":8081");
    expected = true;
  };
  cmp-gt = {
    expr = bindpoint.gt (p ":8081") (p ":8080");
    expected = true;
  };
  cmp-ge = {
    expr = bindpoint.ge (p ":8081") (p ":8080");
    expected = true;
  };
  cmp-max = {
    expr = bindpoint.toString (bindpoint.max (p ":8080") (p ":8081"));
    expected = ":8081";
  };

  # ===== Comparison =====
  eq-same-ip = {
    expr = bindpoint.eq (p ":8080") (p ":8080");
    expected = true;
  };
  eq-same-unix = {
    expr = bindpoint.eq (p "/run/foo.sock") (p "/run/foo.sock");
    expected = true;
  };
  eq-cross-kind = {
    expr = bindpoint.eq (p ":8080") (p "/run/foo.sock");
    expected = false;
  };
  compare-ip-before-unix = {
    expr = bindpoint.compare (p ":8080") (p "/run/foo.sock");
    expected = -1;
  };
  compare-unix-after-ip = {
    expr = bindpoint.compare (p "/run/foo.sock") (p ":8080");
    expected = 1;
  };
  min-picks-ip = {
    expr = (bindpoint.min (p "/run/foo.sock") (p ":8080"))._type;
    expected = "ipBindpoint";
  };

  # Sanity: union recognises values from each member module
  is-from-ip-module = {
    expr = bindpoint.is (ipBindpoint.parse ":8080");
    expected = true;
  };
  is-from-unix-module = {
    expr = bindpoint.is (unixSocket.parse "/run/foo.sock");
    expected = true;
  };
}
