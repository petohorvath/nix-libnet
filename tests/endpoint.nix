{ harness }:
let
  ep = import ../lib/endpoint.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  port = import ../lib/port.nix;
  inherit (harness) throws;
  p = ep.parse;
in
{
  # ===== Parse =====
  parse-v4 = {
    expr = ep.toString (p "1.2.3.4:80");
    expected = "1.2.3.4:80";
  };
  parse-v6 = {
    expr = ep.toString (p "[::1]:80");
    expected = "[::1]:80";
  };
  parse-v6-doc = {
    expr = ep.toString (p "[2001:db8::1]:443");
    expected = "[2001:db8::1]:443";
  };
  parse-v4-max-port = {
    expr = ep.toString (p "1.2.3.4:65535");
    expected = "1.2.3.4:65535";
  };
  parse-v4-port-0 = {
    expr = ep.toString (p "1.2.3.4:0");
    expected = "1.2.3.4:0";
  };

  # ===== Reject =====
  reject-v6-unbrak = {
    expr = throws (p "::1:80");
    expected = true;
  };
  reject-no-port = {
    expr = throws (p "1.2.3.4");
    expected = true;
  };
  reject-v4-brak = {
    expr = throws (p "[1.2.3.4]:80");
    expected = true;
  };
  reject-empty-port = {
    expr = throws (p "1.2.3.4:");
    expected = true;
  };
  reject-no-addr = {
    expr = throws (p ":80");
    expected = true;
  };
  reject-port-over = {
    expr = throws (p "1.2.3.4:70000");
    expected = true;
  };
  reject-bad-v6 = {
    expr = throws (p "[:::1]:80");
    expected = true;
  };
  reject-not-string = {
    expr = throws (ep.parse 123);
    expected = true;
  };

  # ===== tryParse =====
  tryParse-ok = {
    expr = (ep.tryParse "1.2.3.4:80").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (ep.tryParse "bad").success;
    expected = false;
  };

  # ===== Round-trip =====
  rt-v4 = {
    expr = ep.toString (p (ep.toString (p "1.2.3.4:80")));
    expected = "1.2.3.4:80";
  };
  rt-v6 = {
    expr = ep.toString (p (ep.toString (p "[::1]:80")));
    expected = "[::1]:80";
  };

  # ===== make / accessors =====
  make-v4 = {
    expr = ep.toString (ep.make (ipv4.parse "1.2.3.4") (port.fromInt 80));
    expected = "1.2.3.4:80";
  };
  make-v6 = {
    expr = ep.toString (ep.make (ipv6.parse "::1") (port.fromInt 443));
    expected = "[::1]:443";
  };
  address-ext = {
    expr = ipv4.toString (ep.address (p "1.2.3.4:80"));
    expected = "1.2.3.4";
  };
  port-ext = {
    expr = port.toInt (ep.port (p "1.2.3.4:80"));
    expected = 80;
  };
  version-v4 = {
    expr = ep.version (p "1.2.3.4:80");
    expected = 4;
  };
  version-v6 = {
    expr = ep.version (p "[::1]:80");
    expected = 6;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = ep.is (p "1.2.3.4:80");
    expected = true;
  };
  is-string = {
    expr = ep.is "1.2.3.4:80";
    expected = false;
  };
  isIpv4-v4 = {
    expr = ep.isIpv4 (p "1.2.3.4:80");
    expected = true;
  };
  isIpv6-v6 = {
    expr = ep.isIpv6 (p "[::1]:80");
    expected = true;
  };
  isValid-ok = {
    expr = ep.isValid "1.2.3.4:80";
    expected = true;
  };
  isValid-bad = {
    expr = ep.isValid "bad";
    expected = false;
  };

  # ===== Forwarded predicates =====
  fwd-loopback-v4 = {
    expr = ep.isLoopback (p "127.0.0.1:80");
    expected = true;
  };
  fwd-loopback-v6 = {
    expr = ep.isLoopback (p "[::1]:80");
    expected = true;
  };
  fwd-loopback-no = {
    expr = ep.isLoopback (p "8.8.8.8:80");
    expected = false;
  };
  fwd-global-v4 = {
    expr = ep.isGlobal (p "8.8.8.8:80");
    expected = true;
  };
  fwd-linkLocal-v6 = {
    expr = ep.isLinkLocal (p "[fe80::1]:80");
    expected = true;
  };

  # ===== Comparison =====
  eq-same = {
    expr = ep.eq (p "1.2.3.4:80") (p "1.2.3.4:80");
    expected = true;
  };
  eq-diff-port = {
    expr = ep.eq (p "1.2.3.4:80") (p "1.2.3.4:81");
    expected = false;
  };
  eq-diff-addr = {
    expr = ep.eq (p "1.2.3.4:80") (p "1.2.3.5:80");
    expected = false;
  };
  eq-cross-fam = {
    expr = ep.eq (p "1.2.3.4:80") (p "[::1]:80");
    expected = false;
  };

  compare-v4-v6 = {
    expr = ep.compare (p "1.2.3.4:80") (p "[::1]:80");
    expected = -1;
  };
  compare-same = {
    expr = ep.compare (p "1.2.3.4:80") (p "1.2.3.4:80");
    expected = 0;
  };
  compare-addr = {
    expr = ep.compare (p "1.2.3.4:80") (p "1.2.3.5:80");
    expected = -1;
  };
  compare-port = {
    expr = ep.compare (p "1.2.3.4:80") (p "1.2.3.4:81");
    expected = -1;
  };
  lt-yes = {
    expr = ep.lt (p "1.2.3.4:80") (p "1.2.3.4:81");
    expected = true;
  };
  min-smaller = {
    expr = ep.toString (ep.min (p "1.2.3.4:80") (p "1.2.3.4:81"));
    expected = "1.2.3.4:80";
  };
}
