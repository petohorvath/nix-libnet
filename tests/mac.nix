{ harness }:
let
  mac = import ../lib/mac.nix;
  inherit (harness) throws;
  p = mac.parse;
in
{
  # ===== Parse: four formats =====
  parse-colon = {
    expr = mac.toInt (p "aa:bb:cc:dd:ee:ff");
    expected = 187723572702975;
  };
  parse-hyphen = {
    expr = mac.toInt (p "aa-bb-cc-dd-ee-ff");
    expected = 187723572702975;
  };
  parse-cisco = {
    expr = mac.toInt (p "aabb.ccdd.eeff");
    expected = 187723572702975;
  };
  parse-bare = {
    expr = mac.toInt (p "aabbccddeeff");
    expected = 187723572702975;
  };
  parse-zero = {
    expr = mac.toInt (p "00:00:00:00:00:00");
    expected = 0;
  };
  parse-max = {
    expr = mac.toInt (p "ff:ff:ff:ff:ff:ff");
    expected = 281474976710655;
  };

  # ===== Case insensitive =====
  parse-upper = {
    expr = mac.toString (p "AA:BB:CC:DD:EE:FF");
    expected = "aa:bb:cc:dd:ee:ff";
  };
  parse-mixed = {
    expr = mac.toString (p "Aa:bB:cC:Dd:eE:Ff");
    expected = "aa:bb:cc:dd:ee:ff";
  };
  parse-cisco-upper = {
    expr = mac.toString (p "AABB.CCDD.EEFF");
    expected = "aa:bb:cc:dd:ee:ff";
  };
  parse-bare-upper = {
    expr = mac.toString (p "AABBCCDDEEFF");
    expected = "aa:bb:cc:dd:ee:ff";
  };

  # ===== Parse: negative =====
  parse-5-octets = {
    expr = throws (p "aa:bb:cc:dd:ee");
    expected = true;
  };
  parse-7-octets = {
    expr = throws (p "aa:bb:cc:dd:ee:ff:11");
    expected = true;
  };
  parse-non-hex = {
    expr = throws (p "gg:hh:ii:jj:kk:ll");
    expected = true;
  };
  parse-wrong-sep = {
    expr = throws (p "aa/bb/cc/dd/ee/ff");
    expected = true;
  };
  parse-mixed-sep = {
    expr = throws (p "aa:bb-cc:dd-ee:ff");
    expected = true;
  };
  parse-whitespace = {
    expr = throws (p " aa:bb:cc:dd:ee:ff");
    expected = true;
  };
  parse-short-octet = {
    expr = throws (p "a:b:c:d:e:f");
    expected = true;
  };
  parse-long-octet = {
    expr = throws (p "aaa:bb:cc:dd:ee:ff");
    expected = true;
  };
  parse-empty = {
    expr = throws (p "");
    expected = true;
  };
  parse-not-string = {
    expr = throws (mac.parse 123);
    expected = true;
  };

  # ===== tryParse =====
  tryParse-ok = {
    expr = (mac.tryParse "aa:bb:cc:dd:ee:ff").success;
    expected = true;
  };
  tryParse-fail = {
    expr = (mac.tryParse "bad").success;
    expected = false;
  };

  # ===== Round-trip =====
  rt-string = {
    expr = mac.toString (p "aa:bb:cc:dd:ee:ff");
    expected = "aa:bb:cc:dd:ee:ff";
  };
  rt-int = {
    expr = mac.toInt (mac.fromInt 187723572702975);
    expected = 187723572702975;
  };
  rt-bytes = {
    expr = mac.toBytes (
      mac.fromBytes [
        170
        187
        204
        221
        238
        255
      ]
    );
    expected = [
      170
      187
      204
      221
      238
      255
    ];
  };

  # ===== Formatting =====
  fmt-string = {
    expr = mac.toString (p "aabbccddeeff");
    expected = "aa:bb:cc:dd:ee:ff";
  };
  fmt-hyphen = {
    expr = mac.toStringHyphen (p "aabbccddeeff");
    expected = "aa-bb-cc-dd-ee-ff";
  };
  fmt-cisco = {
    expr = mac.toStringCisco (p "aabbccddeeff");
    expected = "aabb.ccdd.eeff";
  };
  fmt-bare = {
    expr = mac.toStringBare (p "aabbccddeeff");
    expected = "aabbccddeeff";
  };

  # ===== fromInt / fromBytes =====
  fromInt-over = {
    expr = throws (mac.fromInt 281474976710656);
    expected = true;
  };
  fromInt-neg = {
    expr = throws (mac.fromInt (-1));
    expected = true;
  };
  fromBytes-short = {
    expr = throws (
      mac.fromBytes [
        1
        2
        3
      ]
    );
    expected = true;
  };
  fromBytes-over = {
    expr = throws (
      mac.fromBytes [
        1
        2
        3
        4
        5
        256
      ]
    );
    expected = true;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = mac.is (p "aa:bb:cc:dd:ee:ff");
    expected = true;
  };
  is-string = {
    expr = mac.is "aa:bb:cc:dd:ee:ff";
    expected = false;
  };
  isValid-ok = {
    expr = mac.isValid "aa:bb:cc:dd:ee:ff";
    expected = true;
  };
  isValid-bad = {
    expr = mac.isValid "zz:zz:zz:zz:zz:zz";
    expected = false;
  };

  # unicast vs multicast: bit 0 of first octet
  unicast-pos = {
    expr = mac.isUnicast (p "02:bb:cc:dd:ee:ff");
    expected = true;
  }; # bit 0 = 0
  unicast-neg = {
    expr = mac.isUnicast (p "01:bb:cc:dd:ee:ff");
    expected = false;
  }; # bit 0 = 1
  multicast-pos = {
    expr = mac.isMulticast (p "01:bb:cc:dd:ee:ff");
    expected = true;
  };
  multicast-neg = {
    expr = mac.isMulticast (p "02:bb:cc:dd:ee:ff");
    expected = false;
  };

  # universal vs local: bit 1 of first octet
  universal-pos = {
    expr = mac.isUniversal (p "00:bb:cc:dd:ee:ff");
    expected = true;
  };
  universal-neg = {
    expr = mac.isUniversal (p "02:bb:cc:dd:ee:ff");
    expected = false;
  };
  local-pos = {
    expr = mac.isLocal (p "02:bb:cc:dd:ee:ff");
    expected = true;
  };
  local-neg = {
    expr = mac.isLocal (p "00:bb:cc:dd:ee:ff");
    expected = false;
  };

  broadcast-pos = {
    expr = mac.isBroadcast (p "ff:ff:ff:ff:ff:ff");
    expected = true;
  };
  broadcast-neg = {
    expr = mac.isBroadcast (p "ff:ff:ff:ff:ff:fe");
    expected = false;
  };
  zero-pos = {
    expr = mac.isZero (p "00:00:00:00:00:00");
    expected = true;
  };
  zero-neg = {
    expr = mac.isZero (p "00:00:00:00:00:01");
    expected = false;
  };

  # ===== Bit setters =====
  setLocal-flips = {
    expr = mac.toString (mac.setLocal (p "00:bb:cc:dd:ee:ff"));
    expected = "02:bb:cc:dd:ee:ff";
  };
  setLocal-idem = {
    expr = mac.toString (mac.setLocal (p "02:bb:cc:dd:ee:ff"));
    expected = "02:bb:cc:dd:ee:ff";
  };
  setUniversal-flip = {
    expr = mac.toString (mac.setUniversal (p "02:bb:cc:dd:ee:ff"));
    expected = "00:bb:cc:dd:ee:ff";
  };
  setUniversal-idem = {
    expr = mac.toString (mac.setUniversal (p "00:bb:cc:dd:ee:ff"));
    expected = "00:bb:cc:dd:ee:ff";
  };
  setMulticast-flip = {
    expr = mac.toString (mac.setMulticast (p "00:bb:cc:dd:ee:ff"));
    expected = "01:bb:cc:dd:ee:ff";
  };
  setUnicast-flip = {
    expr = mac.toString (mac.setUnicast (p "01:bb:cc:dd:ee:ff"));
    expected = "00:bb:cc:dd:ee:ff";
  };

  # ===== OUI / NIC =====
  # 11:22:33:44:55:66 → OUI = 0x112233 = 1122867, NIC = 0x445566 = 4478310
  oui-extract = {
    expr = mac.oui (p "11:22:33:44:55:66");
    expected = 1122867;
  };
  nic-extract = {
    expr = mac.nic (p "11:22:33:44:55:66");
    expected = 4478310;
  };
  fromOuiNic-build = {
    expr = mac.toString (mac.fromOuiNic 1122867 4478310);
    expected = "11:22:33:44:55:66";
  };
  ouiToString-fmt = {
    expr = mac.ouiToString 1122867;
    expected = "11:22:33";
  };
  fromOuiNic-oob = {
    expr = throws (mac.fromOuiNic 16777216 0);
    expected = true;
  };

  # ===== EUI-64 (RFC 4291 § 2.5.1) =====
  # aa:bb:cc:dd:ee:ff → [0xa8, 0xbb, 0xcc, 0xff, 0xfe, 0xdd, 0xee, 0xff]
  eui64-spec-vector = {
    expr = mac.toEui64 (p "aa:bb:cc:dd:ee:ff");
    expected = [
      168
      187
      204
      255
      254
      221
      238
      255
    ];
  };
  # Flip u/l bit: 00:11:22:33:44:55 → first octet 0x00 XOR 2 = 0x02
  eui64-zero-ul = {
    expr = mac.toEui64 (p "00:11:22:33:44:55");
    expected = [
      2
      17
      34
      255
      254
      51
      68
      85
    ];
  };

  # ===== Arithmetic =====
  add-one = {
    expr = mac.toString (mac.add 1 (p "00:00:00:00:00:00"));
    expected = "00:00:00:00:00:01";
  };
  add-carry = {
    expr = mac.toString (mac.add 1 (p "00:00:00:00:00:ff"));
    expected = "00:00:00:00:01:00";
  };
  add-overflow = {
    expr = throws (mac.add 1 (p "ff:ff:ff:ff:ff:ff"));
    expected = true;
  };
  sub-borrow = {
    expr = mac.toString (mac.sub 1 (p "00:00:00:00:01:00"));
    expected = "00:00:00:00:00:ff";
  };
  sub-underflow = {
    expr = throws (mac.sub 1 (p "00:00:00:00:00:00"));
    expected = true;
  };
  next-ok = {
    expr = mac.toString (mac.next (p "00:00:00:00:00:01"));
    expected = "00:00:00:00:00:02";
  };
  prev-ok = {
    expr = mac.toString (mac.prev (p "00:00:00:00:00:02"));
    expected = "00:00:00:00:00:01";
  };
  diff-pos = {
    expr = mac.diff (p "00:00:00:00:00:01") (p "00:00:00:00:00:05");
    expected = 4;
  };

  # ===== Comparison =====
  eq-same = {
    expr = mac.eq (p "aa:bb:cc:dd:ee:ff") (p "aa:bb:cc:dd:ee:ff");
    expected = true;
  };
  eq-diff = {
    expr = mac.eq (p "aa:bb:cc:dd:ee:ff") (p "aa:bb:cc:dd:ee:fe");
    expected = false;
  };
  lt-yes = {
    expr = mac.lt (p "00:00:00:00:00:01") (p "00:00:00:00:00:02");
    expected = true;
  };
  compare-lt = {
    expr = mac.compare (p "00:00:00:00:00:01") (p "00:00:00:00:00:02");
    expected = -1;
  };
  compare-eq = {
    expr = mac.compare (p "00:00:00:00:00:01") (p "00:00:00:00:00:01");
    expected = 0;
  };
  compare-gt = {
    expr = mac.compare (p "00:00:00:00:00:02") (p "00:00:00:00:00:01");
    expected = 1;
  };
  min-smaller = {
    expr = mac.toString (mac.min (p "00:00:00:00:00:01") (p "00:00:00:00:00:02"));
    expected = "00:00:00:00:00:01";
  };
  max-larger = {
    expr = mac.toString (mac.max (p "00:00:00:00:00:01") (p "00:00:00:00:00:02"));
    expected = "00:00:00:00:00:02";
  };

  # ===== Constants =====
  const-any = {
    expr = mac.toString mac.any;
    expected = "00:00:00:00:00:00";
  };
  const-broadcast = {
    expr = mac.toString mac.broadcast;
    expected = "ff:ff:ff:ff:ff:ff";
  };

  # ===== Curry =====
  curry-add = {
    expr = map mac.toString (
      map (mac.add 1) [
        (p "00:00:00:00:00:00")
        (p "00:00:00:00:00:10")
      ]
    );
    expected = [
      "00:00:00:00:00:01"
      "00:00:00:00:00:11"
    ];
  };
}
