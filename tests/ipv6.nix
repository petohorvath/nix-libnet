{ harness }:
let
  ipv6 = import ../lib/ipv6.nix;
  ipv4 = import ../lib/ipv4.nix;
  mac = import ../lib/mac.nix;
  inherit (harness) throws;

  p = ipv6.parse;
in
{
  # ===== Parse: positive (compression) =====
  parse-all-zero = {
    expr = ipv6.toWords (p "::");
    expected = [
      0
      0
      0
      0
    ];
  };
  parse-loopback = {
    expr = ipv6.toWords (p "::1");
    expected = [
      0
      0
      0
      1
    ];
  };
  parse-one-tail = {
    expr = ipv6.toWords (p "1::");
    expected = [
      65536
      0
      0
      0
    ];
  };
  parse-one-double = {
    expr = ipv6.toWords (p "1::2");
    expected = [
      65536
      0
      0
      2
    ];
  };
  parse-middle-comp = {
    expr = ipv6.toWords (p "1:2::3:4");
    expected = [
      65538
      0
      0
      196612
    ];
  };
  parse-doc = {
    expr = ipv6.toWords (p "2001:db8::1");
    expected = [
      536939960
      0
      0
      1
    ];
  };
  parse-full-expanded = {
    expr = ipv6.toWords (p "2001:0db8:0000:0000:0000:0000:0000:0001");
    expected = [
      536939960
      0
      0
      1
    ];
  };

  # ===== Parse: uncompressed =====
  parse-all-explicit = {
    expr = ipv6.toWords (p "1:2:3:4:5:6:7:8");
    expected = [
      65538
      196612
      327686
      458760
    ];
  };

  # ===== Parse: IPv4-mapped / compatible =====
  # ::ffff:1.2.3.4 → [0, 0, 0xffff, 1*2^24+2*2^16+3*2^8+4] = [0, 0, 65535, 16909060]
  parse-v4-mapped = {
    expr = ipv6.toWords (p "::ffff:1.2.3.4");
    expected = [
      0
      0
      65535
      16909060
    ];
  };
  # ::1.2.3.4 (IPv4-compatible, deprecated)
  parse-v4-compat = {
    expr = ipv6.toWords (p "::1.2.3.4");
    expected = [
      0
      0
      0
      16909060
    ];
  };
  parse-full-v4-embed = {
    expr = ipv6.toWords (p "1:2:3:4:5:6:1.2.3.4");
    expected = [
      65538
      196612
      327686
      16909060
    ];
  };

  # ===== Parse: case insensitive =====
  parse-upper = {
    expr = ipv6.toWords (p "2001:DB8::1");
    expected = [
      536939960
      0
      0
      1
    ];
  };
  parse-mixed = {
    expr = ipv6.toWords (p "2001:Db8::AbCd");
    expected = [
      536939960
      0
      0
      43981
    ];
  };

  # ===== Parse: negative =====
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-triple-colon = {
    expr = throws (p ":::");
    expected = true;
  };
  reject-two-compress = {
    expr = throws (p "::1::");
    expected = true;
  };
  reject-nine-groups = {
    expr = throws (p "1:2:3:4:5:6:7:8:9");
    expected = true;
  };
  reject-oversize-grp = {
    expr = throws (p "12345::");
    expected = true;
  };
  reject-non-hex = {
    expr = throws (p "gggg::");
    expected = true;
  };
  reject-v4-in-left = {
    expr = throws (p "1.2.3.4::1");
    expected = true;
  };
  reject-whitespace = {
    expr = throws (p " ::1");
    expected = true;
  };
  reject-not-string = {
    expr = throws (ipv6.parse 123);
    expected = true;
  };
  reject-compress-full = {
    expr = throws (p "1:2:3:4::5:6:7:8");
    expected = true;
  }; # 8 groups + :: invalid

  # ===== tryParse =====
  tryParse-ok = {
    expr = (ipv6.tryParse "::1").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (ipv6.tryParse "bad").success;
    expected = false;
  };

  # ===== toString (RFC 5952) =====
  fmt-loopback = {
    expr = ipv6.toString (p "::1");
    expected = "::1";
  };
  fmt-any = {
    expr = ipv6.toString (p "::");
    expected = "::";
  };
  fmt-one-tail = {
    expr = ipv6.toString (p "1::");
    expected = "1::";
  };
  fmt-middle = {
    expr = ipv6.toString (p "1:2::3:4");
    expected = "1:2::3:4";
  };
  fmt-doc = {
    expr = ipv6.toString (p "2001:0db8:0000:0000:0000:0000:0000:0001");
    expected = "2001:db8::1";
  };
  fmt-no-compress = {
    expr = ipv6.toString (p "1:2:3:4:5:6:7:8");
    expected = "1:2:3:4:5:6:7:8";
  };
  fmt-first-run-wins = {
    expr = ipv6.toString (p "1:0:0:2:3:0:0:4");
    expected = "1::2:3:0:0:4";
  }; # first tied run wins
  fmt-single-zero = {
    expr = ipv6.toString (p "1:0:2:0:3:0:4:5");
    expected = "1:0:2:0:3:0:4:5";
  }; # no run of >=2, no compression

  # ===== toStringExpanded / toStringBracketed =====
  fmt-expanded = {
    expr = ipv6.toStringExpanded (p "::1");
    expected = "0000:0000:0000:0000:0000:0000:0000:0001";
  };
  fmt-bracket = {
    expr = ipv6.toStringBracketed (p "::1");
    expected = "[::1]";
  };
  fmt-bracket-doc = {
    expr = ipv6.toStringBracketed (p "2001:db8::1");
    expected = "[2001:db8::1]";
  };

  # ===== toArpa =====
  arpa-doc = {
    expr = ipv6.toArpa (p "2001:db8::1");
    expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa";
  };
  arpa-loopback = {
    expr = ipv6.toArpa (p "::1");
    expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa";
  };

  # ===== Round-trip =====
  rt-words = {
    expr = ipv6.toWords (
      ipv6.fromWords [
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
  rt-groups = {
    expr = ipv6.toGroups (
      ipv6.fromGroups [
        1
        2
        3
        4
        5
        6
        7
        8
      ]
    );
    expected = [
      1
      2
      3
      4
      5
      6
      7
      8
    ];
  };
  rt-bytes = {
    expr = ipv6.toBytes (
      ipv6.fromBytes [
        0
        1
        0
        2
        0
        3
        0
        4
        0
        5
        0
        6
        0
        7
        0
        8
      ]
    );
    expected = [
      0
      1
      0
      2
      0
      3
      0
      4
      0
      5
      0
      6
      0
      7
      0
      8
    ];
  };
  rt-string = {
    expr = ipv6.toString (p (ipv6.toString (p "2001:db8::1")));
    expected = "2001:db8::1";
  };

  # ===== fromWords / fromGroups / fromBytes errors =====
  fromWords-short = {
    expr = throws (
      ipv6.fromWords [
        1
        2
        3
      ]
    );
    expected = true;
  };
  fromWords-over = {
    expr = throws (
      ipv6.fromWords [
        4294967296
        0
        0
        0
      ]
    );
    expected = true;
  };
  fromGroups-short = {
    expr = throws (
      ipv6.fromGroups [
        1
        2
        3
        4
      ]
    );
    expected = true;
  };
  fromGroups-over = {
    expr = throws (
      ipv6.fromGroups [
        65536
        0
        0
        0
        0
        0
        0
        0
      ]
    );
    expected = true;
  };
  fromBytes-short = {
    expr = throws (ipv6.fromBytes [ 0 ]);
    expected = true;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = ipv6.is (p "::1");
    expected = true;
  };
  is-string = {
    expr = ipv6.is "::1";
    expected = false;
  };
  isValid-ok = {
    expr = ipv6.isValid "::1";
    expected = true;
  };
  isValid-bad = {
    expr = ipv6.isValid "bad";
    expected = false;
  };

  loopback-pos = {
    expr = ipv6.isLoopback (p "::1");
    expected = true;
  };
  loopback-neg = {
    expr = ipv6.isLoopback (p "::2");
    expected = false;
  };
  unspec-pos = {
    expr = ipv6.isUnspecified (p "::");
    expected = true;
  };
  unspec-neg = {
    expr = ipv6.isUnspecified (p "::1");
    expected = false;
  };
  link-local-pos = {
    expr = ipv6.isLinkLocal (p "fe80::1");
    expected = true;
  };
  link-local-pos-hi = {
    expr = ipv6.isLinkLocal (p "febf:ffff::1");
    expected = true;
  };
  link-local-neg = {
    expr = ipv6.isLinkLocal (p "fec0::1");
    expected = false;
  };
  unique-local-pos = {
    expr = ipv6.isUniqueLocal (p "fc00::1");
    expected = true;
  };
  unique-local-pos-fd = {
    expr = ipv6.isUniqueLocal (p "fd00::1");
    expected = true;
  };
  unique-local-neg = {
    expr = ipv6.isUniqueLocal (p "fe00::1");
    expected = false;
  };
  multicast-pos = {
    expr = ipv6.isMulticast (p "ff00::1");
    expected = true;
  };
  multicast-neg = {
    expr = ipv6.isMulticast (p "fe00::1");
    expected = false;
  };
  doc-pos = {
    expr = ipv6.isDocumentation (p "2001:db8::1");
    expected = true;
  };
  doc-3fff-pos = {
    expr = ipv6.isDocumentation (p "3fff::1");
    expected = true;
  };
  doc-neg = {
    expr = ipv6.isDocumentation (p "2001:db9::1");
    expected = false;
  };
  v4mapped-pos = {
    expr = ipv6.isIpv4Mapped (p "::ffff:1.2.3.4");
    expected = true;
  };
  v4mapped-neg = {
    expr = ipv6.isIpv4Mapped (p "::1");
    expected = false;
  };
  v4compat-pos = {
    expr = ipv6.isIpv4Compatible (p "::1.2.3.4");
    expected = true;
  };
  v4compat-loopback = {
    expr = ipv6.isIpv4Compatible (p "::1");
    expected = true;
  }; # loopback is also in ::/96
  v4compat-neg = {
    expr = ipv6.isIpv4Compatible (p "1::");
    expected = false;
  };
  sixtofour-pos = {
    expr = ipv6.is6to4 (p "2002::1");
    expected = true;
  };
  sixtofour-neg = {
    expr = ipv6.is6to4 (p "2001::1");
    expected = false;
  };
  global-pos = {
    expr = ipv6.isGlobal (p "2606:4700:4700::1111");
    expected = true;
  };
  global-neg-loop = {
    expr = ipv6.isGlobal (p "::1");
    expected = false;
  };
  # isGlobal is stricter than !isBogon: v4-mapped / v4-compat / 6to4 are also not global
  global-neg-v4mapped = {
    expr = ipv6.isGlobal (p "::ffff:8.8.8.8");
    expected = false;
  };
  global-neg-v4compat = {
    expr = ipv6.isGlobal (p "::1.2.3.4");
    expected = false;
  };
  global-neg-6to4 = {
    expr = ipv6.isGlobal (p "2002::1");
    expected = false;
  };
  # isBogon stays narrower (6 items) — is6to4 / v4-mapped are NOT bogon
  bogon-excludes-6to4 = {
    expr = ipv6.isBogon (p "2002::1");
    expected = false;
  };
  bogon-pos = {
    expr = ipv6.isBogon (p "::1");
    expected = true;
  };
  bogon-neg = {
    expr = ipv6.isBogon (p "2606:4700:4700::1111");
    expected = false;
  };

  # ===== IPv4 interop =====
  v4-mapped-from-v4 = {
    expr = ipv6.toString (ipv6.fromIpv4Mapped (ipv4.parse "1.2.3.4"));
    expected = "::ffff:1.2.3.4";
  };
  v4-mapped-back = {
    expr = ipv4.toString (ipv6.toIpv4Mapped (p "::ffff:1.2.3.4"));
    expected = "1.2.3.4";
  };
  v4-mapped-wrong-fam = {
    expr = throws (ipv6.toIpv4Mapped (p "::1"));
    expected = true;
  };
  v4-mapped-wrong-in = {
    expr = throws (ipv6.fromIpv4Mapped (p "::1"));
    expected = true;
  };

  # ===== EUI-64 =====
  # 2001:db8::/64 + aa:bb:cc:dd:ee:ff → 2001:db8::a8bb:ccff:fedd:eeff
  eui64-vector = {
    expr = ipv6.toString (
      ipv6.fromEui64 {
        _type = "cidr";
        address = p "2001:db8::";
        prefix = 64;
      } (mac.parse "aa:bb:cc:dd:ee:ff")
    );
    expected = "2001:db8::a8bb:ccff:fedd:eeff";
  };
  eui64-prefix-too-big = {
    expr = throws (
      ipv6.fromEui64 {
        _type = "cidr";
        address = p "2001:db8::";
        prefix = 96;
      } (mac.parse "aa:bb:cc:dd:ee:ff")
    );
    expected = true;
  };
  eui64-wrong-type = {
    expr = throws (ipv6.fromEui64 (p "::1") (mac.parse "aa:bb:cc:dd:ee:ff"));
    expected = true;
  };

  # ===== Arithmetic =====
  add-one = {
    expr = ipv6.toString (ipv6.add 1 (p "::"));
    expected = "::1";
  };
  add-one-word-carry = {
    expr = ipv6.toString (ipv6.add 1 (p "::ffff:ffff"));
    expected = "::1:0:0";
  };
  add-zero-identity = {
    expr = ipv6.toString (ipv6.add 0 (p "::1"));
    expected = "::1";
  };
  add-overflow = {
    expr = throws (ipv6.add 1 (p "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"));
    expected = true;
  };
  sub-one = {
    expr = ipv6.toString (ipv6.sub 1 (p "::2"));
    expected = "::1";
  };
  # ::1:0:0:0 - 1 = 0x0000..0000ffffffffffff which is also within ::ffff:0:0/96 (v4-mapped)
  sub-borrow = {
    expr = ipv6.toString (ipv6.sub 1 (p "::1:0:0:0"));
    expected = "::ffff:255.255.255.255";
  };
  # A borrow case that stays outside the v4-mapped range
  sub-borrow-hex = {
    expr = ipv6.toString (ipv6.sub 1 (p "::1:1:0:0:0"));
    expected = "::1:0:ffff:ffff:ffff";
  };
  # Verify canonical mixed form for v4-mapped output
  fmt-v4-mapped-out = {
    expr = ipv6.toString (p "::ffff:c000:201");
    expected = "::ffff:192.0.2.1";
  };
  sub-underflow = {
    expr = throws (ipv6.sub 1 (p "::"));
    expected = true;
  };
  next = {
    expr = ipv6.toString (ipv6.next (p "::1"));
    expected = "::2";
  };
  prev = {
    expr = ipv6.toString (ipv6.prev (p "::2"));
    expected = "::1";
  };
  diff-pos = {
    expr = ipv6.diff (p "::1") (p "::10");
    expected = 15;
  };
  diff-zero = {
    expr = ipv6.diff (p "::1") (p "::1");
    expected = 0;
  };
  diff-neg = {
    expr = ipv6.diff (p "::10") (p "::1");
    expected = (-15);
  };

  # ===== Comparison =====
  eq-same = {
    expr = ipv6.eq (p "::1") (p "::1");
    expected = true;
  };
  eq-diff = {
    expr = ipv6.eq (p "::1") (p "::2");
    expected = false;
  };
  lt-yes = {
    expr = ipv6.lt (p "::1") (p "::2");
    expected = true;
  };
  lt-no = {
    expr = ipv6.lt (p "::2") (p "::1");
    expected = false;
  };
  lt-word0 = {
    expr = ipv6.lt (p "1::") (p "2::");
    expected = true;
  };
  compare-lt = {
    expr = ipv6.compare (p "::1") (p "::2");
    expected = -1;
  };
  compare-eq = {
    expr = ipv6.compare (p "::1") (p "::1");
    expected = 0;
  };
  compare-gt = {
    expr = ipv6.compare (p "::2") (p "::1");
    expected = 1;
  };
  min-smaller = {
    expr = ipv6.toString (ipv6.min (p "::1") (p "::2"));
    expected = "::1";
  };
  max-larger = {
    expr = ipv6.toString (ipv6.max (p "::1") (p "::2"));
    expected = "::2";
  };

  # ===== Constants =====
  const-unspecified = {
    expr = ipv6.toString ipv6.unspecified;
    expected = "::";
  };
  const-loopback = {
    expr = ipv6.toString ipv6.loopback;
    expected = "::1";
  };

  # ===== Curry =====
  curry-add = {
    expr = map ipv6.toString (
      map (ipv6.add 1) [
        (p "::")
        (p "::10")
      ]
    );
    expected = [
      "::1"
      "::11"
    ];
  };
}
