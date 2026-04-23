{ harness }:
let
  ipv4 = import ../lib/ipv4.nix;
  inherit (harness) throws;

  p = ipv4.parse;
in
{
  # ===== Parse: positive =====
  parse-zero = {
    expr = ipv4.toInt (p "0.0.0.0");
    expected = 0;
  };
  parse-max = {
    expr = ipv4.toInt (p "255.255.255.255");
    expected = 4294967295;
  };
  parse-generic = {
    expr = ipv4.toInt (p "1.2.3.4");
    expected = 16909060;
  };
  parse-loopback = {
    expr = ipv4.toInt (p "127.0.0.1");
    expected = 2130706433;
  };
  parse-octet-zero = {
    expr = ipv4.toInt (p "1.0.0.1");
    expected = 16777217;
  };

  # ===== Parse: negative =====
  parse-empty = {
    expr = throws (p "");
    expected = true;
  };
  parse-3-octets = {
    expr = throws (p "1.2.3");
    expected = true;
  };
  parse-5-octets = {
    expr = throws (p "1.2.3.4.5");
    expected = true;
  };
  parse-octet-256 = {
    expr = throws (p "1.2.3.256");
    expected = true;
  };
  parse-leading-0 = {
    expr = throws (p "01.2.3.4");
    expected = true;
  };
  parse-leading-0b = {
    expr = throws (p "1.02.3.4");
    expected = true;
  };
  parse-negative = {
    expr = throws (p "1.2.3.-1");
    expected = true;
  };
  parse-whitespace = {
    expr = throws (p " 1.2.3.4");
    expected = true;
  };
  parse-trailing = {
    expr = throws (p "1.2.3.4 ");
    expected = true;
  };
  parse-non-digit = {
    expr = throws (p "a.b.c.d");
    expected = true;
  };
  parse-hex = {
    expr = throws (p "0x1.2.3.4");
    expected = true;
  };
  parse-empty-oct = {
    expr = throws (p "1..3.4");
    expected = true;
  };
  parse-non-string = {
    expr = throws (ipv4.parse 123);
    expected = true;
  };

  # ===== tryParse =====
  tryParse-ok = {
    expr = (ipv4.tryParse "1.2.3.4").success;
    expected = true;
  };
  tryParse-fail = {
    expr = (ipv4.tryParse "bad").success;
    expected = false;
  };
  tryParse-err-msg = {
    expr = builtins.isString (ipv4.tryParse "bad").error;
    expected = true;
  };
  tryParse-null-val = {
    expr = (ipv4.tryParse "bad").value == null;
    expected = true;
  };

  # ===== Round-trip =====
  rt-string = {
    expr = ipv4.toString (p "1.2.3.4");
    expected = "1.2.3.4";
  };
  rt-string-zero = {
    expr = ipv4.toString (p "0.0.0.0");
    expected = "0.0.0.0";
  };
  rt-string-max = {
    expr = ipv4.toString (p "255.255.255.255");
    expected = "255.255.255.255";
  };
  rt-int = {
    expr = ipv4.toInt (ipv4.fromInt 16909060);
    expected = 16909060;
  };
  rt-octets = {
    expr = ipv4.toOctets (
      ipv4.fromOctets [
        1
        2
        3
        4
      ]
    );
    expected = [
      1
      2
      3
      4
    ];
  };
  rt-full = {
    expr = ipv4.toString (ipv4.fromOctets (ipv4.toOctets (p "10.0.0.1")));
    expected = "10.0.0.1";
  };

  # ===== fromInt / toInt =====
  fromInt-zero = {
    expr = ipv4.toString (ipv4.fromInt 0);
    expected = "0.0.0.0";
  };
  fromInt-max = {
    expr = ipv4.toString (ipv4.fromInt 4294967295);
    expected = "255.255.255.255";
  };
  fromInt-over = {
    expr = throws (ipv4.fromInt 4294967296);
    expected = true;
  };
  fromInt-neg = {
    expr = throws (ipv4.fromInt (-1));
    expected = true;
  };
  fromInt-not-int = {
    expr = throws (ipv4.fromInt "42");
    expected = true;
  };

  # ===== fromOctets / toOctets =====
  fromOct-zero = {
    expr = ipv4.toString (
      ipv4.fromOctets [
        0
        0
        0
        0
      ]
    );
    expected = "0.0.0.0";
  };
  fromOct-max = {
    expr = ipv4.toString (
      ipv4.fromOctets [
        255
        255
        255
        255
      ]
    );
    expected = "255.255.255.255";
  };
  fromOct-short = {
    expr = throws (
      ipv4.fromOctets [
        1
        2
        3
      ]
    );
    expected = true;
  };
  fromOct-long = {
    expr = throws (
      ipv4.fromOctets [
        1
        2
        3
        4
        5
      ]
    );
    expected = true;
  };
  fromOct-over = {
    expr = throws (
      ipv4.fromOctets [
        1
        2
        3
        256
      ]
    );
    expected = true;
  };
  fromOct-neg = {
    expr = throws (
      ipv4.fromOctets [
        1
        2
        3
        (-1)
      ]
    );
    expected = true;
  };

  # ===== toArpa =====
  arpa-simple = {
    expr = ipv4.toArpa (p "1.2.3.4");
    expected = "4.3.2.1.in-addr.arpa";
  };
  arpa-zero = {
    expr = ipv4.toArpa (p "0.0.0.0");
    expected = "0.0.0.0.in-addr.arpa";
  };
  arpa-loopback = {
    expr = ipv4.toArpa (p "127.0.0.1");
    expected = "1.0.0.127.in-addr.arpa";
  };

  # ===== Predicates: is / isValid =====
  isValid-good = {
    expr = ipv4.isValid "1.2.3.4";
    expected = true;
  };
  isValid-bad = {
    expr = ipv4.isValid "1.2.3";
    expected = false;
  };
  is-parsed = {
    expr = ipv4.is (p "1.2.3.4");
    expected = true;
  };
  is-string = {
    expr = ipv4.is "1.2.3.4";
    expected = false;
  };
  is-int = {
    expr = ipv4.is 123;
    expected = false;
  };
  is-wrong-type = {
    expr = ipv4.is { _type = "ipv6"; };
    expected = false;
  };

  # ===== Predicates: loopback =====
  loopback-pos = {
    expr = ipv4.isLoopback (p "127.0.0.1");
    expected = true;
  };
  loopback-pos-low = {
    expr = ipv4.isLoopback (p "127.0.0.0");
    expected = true;
  };
  loopback-pos-high = {
    expr = ipv4.isLoopback (p "127.255.255.255");
    expected = true;
  };
  loopback-neg = {
    expr = ipv4.isLoopback (p "128.0.0.1");
    expected = false;
  };
  loopback-neg-low = {
    expr = ipv4.isLoopback (p "126.255.255.255");
    expected = false;
  };

  # ===== Predicates: private (RFC 1918) =====
  priv-10 = {
    expr = ipv4.isPrivate (p "10.0.0.1");
    expected = true;
  };
  priv-10-last = {
    expr = ipv4.isPrivate (p "10.255.255.255");
    expected = true;
  };
  priv-10-neg = {
    expr = ipv4.isPrivate (p "11.0.0.1");
    expected = false;
  };
  priv-172-16 = {
    expr = ipv4.isPrivate (p "172.16.0.1");
    expected = true;
  };
  priv-172-31 = {
    expr = ipv4.isPrivate (p "172.31.255.255");
    expected = true;
  };
  priv-172-15 = {
    expr = ipv4.isPrivate (p "172.15.255.255");
    expected = false;
  };
  priv-172-32 = {
    expr = ipv4.isPrivate (p "172.32.0.0");
    expected = false;
  };
  priv-192-168 = {
    expr = ipv4.isPrivate (p "192.168.0.1");
    expected = true;
  };
  priv-192-169 = {
    expr = ipv4.isPrivate (p "192.169.0.0");
    expected = false;
  };
  priv-public = {
    expr = ipv4.isPrivate (p "8.8.8.8");
    expected = false;
  };

  # ===== Predicates: linkLocal =====
  ll-pos = {
    expr = ipv4.isLinkLocal (p "169.254.1.1");
    expected = true;
  };
  ll-pos-low = {
    expr = ipv4.isLinkLocal (p "169.254.0.0");
    expected = true;
  };
  ll-pos-high = {
    expr = ipv4.isLinkLocal (p "169.254.255.255");
    expected = true;
  };
  ll-neg = {
    expr = ipv4.isLinkLocal (p "169.253.255.255");
    expected = false;
  };

  # ===== Predicates: multicast =====
  mcast-224 = {
    expr = ipv4.isMulticast (p "224.0.0.1");
    expected = true;
  };
  mcast-239 = {
    expr = ipv4.isMulticast (p "239.255.255.255");
    expected = true;
  };
  mcast-223 = {
    expr = ipv4.isMulticast (p "223.255.255.255");
    expected = false;
  };
  mcast-240 = {
    expr = ipv4.isMulticast (p "240.0.0.0");
    expected = false;
  };

  # ===== Predicates: broadcast / unspecified =====
  bcast-pos = {
    expr = ipv4.isBroadcast (p "255.255.255.255");
    expected = true;
  };
  bcast-neg = {
    expr = ipv4.isBroadcast (p "255.255.255.254");
    expected = false;
  };
  unspec-pos = {
    expr = ipv4.isUnspecified (p "0.0.0.0");
    expected = true;
  };
  unspec-neg = {
    expr = ipv4.isUnspecified (p "0.0.0.1");
    expected = false;
  };

  # ===== Predicates: reserved =====
  reserved-pos = {
    expr = ipv4.isReserved (p "240.0.0.1");
    expected = true;
  };
  reserved-pos-low = {
    expr = ipv4.isReserved (p "240.0.0.0");
    expected = true;
  };
  reserved-exc-b = {
    expr = ipv4.isReserved (p "255.255.255.255");
    expected = false;
  };
  reserved-neg = {
    expr = ipv4.isReserved (p "239.255.255.255");
    expected = false;
  };

  # ===== Predicates: documentation =====
  doc-test-net-1 = {
    expr = ipv4.isDocumentation (p "192.0.2.1");
    expected = true;
  };
  doc-test-net-2 = {
    expr = ipv4.isDocumentation (p "198.51.100.5");
    expected = true;
  };
  doc-test-net-3 = {
    expr = ipv4.isDocumentation (p "203.0.113.10");
    expected = true;
  };
  doc-neg = {
    expr = ipv4.isDocumentation (p "192.0.3.1");
    expected = false;
  };

  # ===== Predicates: global / bogon =====
  global-pos = {
    expr = ipv4.isGlobal (p "8.8.8.8");
    expected = true;
  };
  global-neg-loop = {
    expr = ipv4.isGlobal (p "127.0.0.1");
    expected = false;
  };
  global-neg-priv = {
    expr = ipv4.isGlobal (p "10.0.0.1");
    expected = false;
  };
  bogon-pos = {
    expr = ipv4.isBogon (p "127.0.0.1");
    expected = true;
  };
  bogon-neg = {
    expr = ipv4.isBogon (p "8.8.8.8");
    expected = false;
  };
  bogon-doc = {
    expr = ipv4.isBogon (p "192.0.2.1");
    expected = true;
  };

  # ===== Arithmetic =====
  add-zero = {
    expr = ipv4.toString (ipv4.add 0 (p "1.2.3.4"));
    expected = "1.2.3.4";
  };
  add-one = {
    expr = ipv4.toString (ipv4.add 1 (p "1.2.3.4"));
    expected = "1.2.3.5";
  };
  add-carry = {
    expr = ipv4.toString (ipv4.add 1 (p "1.2.3.255"));
    expected = "1.2.4.0";
  };
  add-big = {
    expr = ipv4.toString (ipv4.add 256 (p "0.0.0.0"));
    expected = "0.0.1.0";
  };
  add-overflow = {
    expr = throws (ipv4.add 1 (p "255.255.255.255"));
    expected = true;
  };
  sub-one = {
    expr = ipv4.toString (ipv4.sub 1 (p "1.2.3.4"));
    expected = "1.2.3.3";
  };
  sub-borrow = {
    expr = ipv4.toString (ipv4.sub 1 (p "1.2.3.0"));
    expected = "1.2.2.255";
  };
  sub-underflow = {
    expr = throws (ipv4.sub 1 (p "0.0.0.0"));
    expected = true;
  };
  next-ok = {
    expr = ipv4.toString (ipv4.next (p "1.2.3.4"));
    expected = "1.2.3.5";
  };
  next-overflow = {
    expr = throws (ipv4.next (p "255.255.255.255"));
    expected = true;
  };
  prev-ok = {
    expr = ipv4.toString (ipv4.prev (p "1.2.3.4"));
    expected = "1.2.3.3";
  };
  prev-underflow = {
    expr = throws (ipv4.prev (p "0.0.0.0"));
    expected = true;
  };
  diff-pos = {
    expr = ipv4.diff (p "1.2.3.4") (p "1.2.3.10");
    expected = 6;
  };
  diff-neg = {
    expr = ipv4.diff (p "1.2.3.10") (p "1.2.3.4");
    expected = (-6);
  };
  diff-same = {
    expr = ipv4.diff (p "1.2.3.4") (p "1.2.3.4");
    expected = 0;
  };

  # ===== Comparison =====
  eq-same = {
    expr = ipv4.eq (p "1.2.3.4") (p "1.2.3.4");
    expected = true;
  };
  eq-diff = {
    expr = ipv4.eq (p "1.2.3.4") (p "1.2.3.5");
    expected = false;
  };
  lt-yes = {
    expr = ipv4.lt (p "1.2.3.4") (p "1.2.3.5");
    expected = true;
  };
  lt-no = {
    expr = ipv4.lt (p "1.2.3.5") (p "1.2.3.4");
    expected = false;
  };
  lt-eq = {
    expr = ipv4.lt (p "1.2.3.4") (p "1.2.3.4");
    expected = false;
  };
  le-eq = {
    expr = ipv4.le (p "1.2.3.4") (p "1.2.3.4");
    expected = true;
  };
  gt-yes = {
    expr = ipv4.gt (p "1.2.3.5") (p "1.2.3.4");
    expected = true;
  };
  ge-eq = {
    expr = ipv4.ge (p "1.2.3.4") (p "1.2.3.4");
    expected = true;
  };
  compare-lt = {
    expr = ipv4.compare (p "1.0.0.0") (p "2.0.0.0");
    expected = -1;
  };
  compare-eq = {
    expr = ipv4.compare (p "1.0.0.0") (p "1.0.0.0");
    expected = 0;
  };
  compare-gt = {
    expr = ipv4.compare (p "2.0.0.0") (p "1.0.0.0");
    expected = 1;
  };
  min-a = {
    expr = ipv4.toString (ipv4.min (p "1.0.0.0") (p "2.0.0.0"));
    expected = "1.0.0.0";
  };
  min-b = {
    expr = ipv4.toString (ipv4.min (p "2.0.0.0") (p "1.0.0.0"));
    expected = "1.0.0.0";
  };
  max-a = {
    expr = ipv4.toString (ipv4.max (p "1.0.0.0") (p "2.0.0.0"));
    expected = "2.0.0.0";
  };

  # ===== Constants =====
  const-unspecified = {
    expr = ipv4.toString ipv4.unspecified;
    expected = "0.0.0.0";
  };
  const-broadcast = {
    expr = ipv4.toString ipv4.broadcast;
    expected = "255.255.255.255";
  };
  const-loopback = {
    expr = ipv4.toString ipv4.loopback;
    expected = "127.0.0.1";
  };

  # ===== Curry partial application =====
  curry-add = {
    expr = map (ipv4.toString) (
      map (ipv4.add 1) [
        (p "1.0.0.0")
        (p "2.0.0.0")
        (p "3.0.0.0")
      ]
    );
    expected = [
      "1.0.0.1"
      "2.0.0.1"
      "3.0.0.1"
    ];
  };
}
