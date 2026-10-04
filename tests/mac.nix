{ harness }:
let
  mac = import ../lib/mac.nix;
  inherit (harness) throws;
  inherit (mac) parse;
in
{
  # ===== Parse: four formats =====
  testParseColon = {
    expr = mac.toInt (parse "aa:bb:cc:dd:ee:ff");
    expected = 187723572702975;
  };
  testParseHyphen = {
    expr = mac.toInt (parse "aa-bb-cc-dd-ee-ff");
    expected = 187723572702975;
  };
  testParseCisco = {
    expr = mac.toInt (parse "aabb.ccdd.eeff");
    expected = 187723572702975;
  };
  testParseBare = {
    expr = mac.toInt (parse "aabbccddeeff");
    expected = 187723572702975;
  };
  testParseZero = {
    expr = mac.toInt (parse "00:00:00:00:00:00");
    expected = 0;
  };
  testParseMax = {
    expr = mac.toInt (parse "ff:ff:ff:ff:ff:ff");
    expected = 281474976710655;
  };

  # ===== Case insensitive =====
  testParseUpper = {
    expr = mac.toString (parse "AA:BB:CC:DD:EE:FF");
    expected = "aa:bb:cc:dd:ee:ff";
  };
  testParseMixedCase = {
    expr = mac.toString (parse "Aa:bB:cC:Dd:eE:Ff");
    expected = "aa:bb:cc:dd:ee:ff";
  };
  testParseCiscoUpper = {
    expr = mac.toString (parse "AABB.CCDD.EEFF");
    expected = "aa:bb:cc:dd:ee:ff";
  };
  testParseBareUpper = {
    expr = mac.toString (parse "AABBCCDDEEFF");
    expected = "aa:bb:cc:dd:ee:ff";
  };

  # ===== Parse: negative =====
  testParse5Octets = {
    expr = throws (parse "aa:bb:cc:dd:ee");
    expected = true;
  };
  testParse7Octets = {
    expr = throws (parse "aa:bb:cc:dd:ee:ff:11");
    expected = true;
  };
  testParseNonHex = {
    expr = throws (parse "gg:hh:ii:jj:kk:ll");
    expected = true;
  };
  testParseWrongSeparator = {
    expr = throws (parse "aa/bb/cc/dd/ee/ff");
    expected = true;
  };
  testParseMixedSeparators = {
    expr = throws (parse "aa:bb-cc:dd-ee:ff");
    expected = true;
  };
  testParseWhitespace = {
    expr = throws (parse " aa:bb:cc:dd:ee:ff");
    expected = true;
  };
  testParseShortOctet = {
    expr = throws (parse "a:b:c:d:e:f");
    expected = true;
  };
  testParseLongOctet = {
    expr = throws (parse "aaa:bb:cc:dd:ee:ff");
    expected = true;
  };
  testParseEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testParseNotString = {
    expr = throws (mac.parse 123);
    expected = true;
  };

  # ===== tryParse =====
  testTryParseOk = {
    expr = (mac.tryParse "aa:bb:cc:dd:ee:ff").success;
    expected = true;
  };
  testTryParseFail = {
    expr = (mac.tryParse "bad").success;
    expected = false;
  };

  # ===== Round-trip =====
  testRoundTripString = {
    expr = mac.toString (parse "aa:bb:cc:dd:ee:ff");
    expected = "aa:bb:cc:dd:ee:ff";
  };
  testRoundTripInt = {
    expr = mac.toInt (mac.fromInt 187723572702975);
    expected = 187723572702975;
  };
  testRoundTripBytes = {
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
  testFormatString = {
    expr = mac.toString (parse "aabbccddeeff");
    expected = "aa:bb:cc:dd:ee:ff";
  };
  testFormatHyphen = {
    expr = mac.toStringHyphen (parse "aabbccddeeff");
    expected = "aa-bb-cc-dd-ee-ff";
  };
  testFormatCisco = {
    expr = mac.toStringCisco (parse "aabbccddeeff");
    expected = "aabb.ccdd.eeff";
  };
  testFormatBare = {
    expr = mac.toStringBare (parse "aabbccddeeff");
    expected = "aabbccddeeff";
  };

  # ===== fromInt / fromBytes =====
  testFromIntOverflow = {
    expr = throws (mac.fromInt 281474976710656);
    expected = true;
  };
  testFromIntNegative = {
    expr = throws (mac.fromInt (-1));
    expected = true;
  };
  testFromBytesShort = {
    expr = throws (
      mac.fromBytes [
        1
        2
        3
      ]
    );
    expected = true;
  };
  testFromBytesByteOverflow = {
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
  testIsParsed = {
    expr = mac.is (parse "aa:bb:cc:dd:ee:ff");
    expected = true;
  };
  testIsString = {
    expr = mac.is "aa:bb:cc:dd:ee:ff";
    expected = false;
  };
  testIsValidOk = {
    expr = mac.isValid "aa:bb:cc:dd:ee:ff";
    expected = true;
  };
  testIsValidBad = {
    expr = mac.isValid "zz:zz:zz:zz:zz:zz";
    expected = false;
  };

  # unicast vs multicast: bit 0 of first octet
  testIsUnicastTrue = {
    expr = mac.isUnicast (parse "02:bb:cc:dd:ee:ff");
    expected = true;
  }; # bit 0 = 0
  testIsUnicastFalse = {
    expr = mac.isUnicast (parse "01:bb:cc:dd:ee:ff");
    expected = false;
  }; # bit 0 = 1
  testIsMulticastTrue = {
    expr = mac.isMulticast (parse "01:bb:cc:dd:ee:ff");
    expected = true;
  };
  testIsMulticastFalse = {
    expr = mac.isMulticast (parse "02:bb:cc:dd:ee:ff");
    expected = false;
  };

  # universal vs local: bit 1 of first octet
  testIsUniversalTrue = {
    expr = mac.isUniversal (parse "00:bb:cc:dd:ee:ff");
    expected = true;
  };
  testIsUniversalFalse = {
    expr = mac.isUniversal (parse "02:bb:cc:dd:ee:ff");
    expected = false;
  };
  testIsLocalTrue = {
    expr = mac.isLocal (parse "02:bb:cc:dd:ee:ff");
    expected = true;
  };
  testIsLocalFalse = {
    expr = mac.isLocal (parse "00:bb:cc:dd:ee:ff");
    expected = false;
  };

  testIsBroadcastTrue = {
    expr = mac.isBroadcast (parse "ff:ff:ff:ff:ff:ff");
    expected = true;
  };
  testIsBroadcastFalse = {
    expr = mac.isBroadcast (parse "ff:ff:ff:ff:ff:fe");
    expected = false;
  };
  testIsUnspecifiedTrue = {
    expr = mac.isUnspecified (parse "00:00:00:00:00:00");
    expected = true;
  };
  testIsUnspecifiedFalse = {
    expr = mac.isUnspecified (parse "00:00:00:00:00:01");
    expected = false;
  };

  # ===== Bit setters =====
  testSetLocalSetsBit = {
    expr = mac.toString (mac.setLocal (parse "00:bb:cc:dd:ee:ff"));
    expected = "02:bb:cc:dd:ee:ff";
  };
  testSetLocalIdempotent = {
    expr = mac.toString (mac.setLocal (parse "02:bb:cc:dd:ee:ff"));
    expected = "02:bb:cc:dd:ee:ff";
  };
  testSetUniversalClearsBit = {
    expr = mac.toString (mac.setUniversal (parse "02:bb:cc:dd:ee:ff"));
    expected = "00:bb:cc:dd:ee:ff";
  };
  testSetUniversalIdempotent = {
    expr = mac.toString (mac.setUniversal (parse "00:bb:cc:dd:ee:ff"));
    expected = "00:bb:cc:dd:ee:ff";
  };
  testSetMulticastSetsBit = {
    expr = mac.toString (mac.setMulticast (parse "00:bb:cc:dd:ee:ff"));
    expected = "01:bb:cc:dd:ee:ff";
  };
  testSetUnicastClearsBit = {
    expr = mac.toString (mac.setUnicast (parse "01:bb:cc:dd:ee:ff"));
    expected = "00:bb:cc:dd:ee:ff";
  };

  # ===== OUI / NIC =====
  # 11:22:33:44:55:66 → OUI = 0x112233 = 1122867, NIC = 0x445566 = 4478310
  testOuiExtract = {
    expr = mac.oui (parse "11:22:33:44:55:66");
    expected = 1122867;
  };
  testNicExtract = {
    expr = mac.nic (parse "11:22:33:44:55:66");
    expected = 4478310;
  };
  testFromOuiNicBuild = {
    expr = mac.toString (mac.fromOuiNic 1122867 4478310);
    expected = "11:22:33:44:55:66";
  };
  testOuiToStringFormat = {
    expr = mac.ouiToString 1122867;
    expected = "11:22:33";
  };
  testFromOuiNicOutOfRange = {
    expr = throws (mac.fromOuiNic 16777216 0);
    expected = true;
  };

  # ===== EUI-64 (RFC 4291 § 2.5.1) =====
  # aa:bb:cc:dd:ee:ff → [0xa8, 0xbb, 0xcc, 0xff, 0xfe, 0xdd, 0xee, 0xff]
  testEui64SpecVector = {
    expr = mac.toEui64 (parse "aa:bb:cc:dd:ee:ff");
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
  testEui64FlipsUniversalLocalBit = {
    expr = mac.toEui64 (parse "00:11:22:33:44:55");
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
  testAddOne = {
    expr = mac.toString (mac.add 1 (parse "00:00:00:00:00:00"));
    expected = "00:00:00:00:00:01";
  };
  testAddCarry = {
    expr = mac.toString (mac.add 1 (parse "00:00:00:00:00:ff"));
    expected = "00:00:00:00:01:00";
  };
  testAddOverflow = {
    expr = throws (mac.add 1 (parse "ff:ff:ff:ff:ff:ff"));
    expected = true;
  };
  testSubBorrow = {
    expr = mac.toString (mac.sub 1 (parse "00:00:00:00:01:00"));
    expected = "00:00:00:00:00:ff";
  };
  testSubUnderflow = {
    expr = throws (mac.sub 1 (parse "00:00:00:00:00:00"));
    expected = true;
  };
  testNextOk = {
    expr = mac.toString (mac.next (parse "00:00:00:00:00:01"));
    expected = "00:00:00:00:00:02";
  };
  testPrevOk = {
    expr = mac.toString (mac.prev (parse "00:00:00:00:00:02"));
    expected = "00:00:00:00:00:01";
  };
  testDiffPositive = {
    expr = mac.diff (parse "00:00:00:00:00:01") (parse "00:00:00:00:00:05");
    expected = 4;
  };
  testDiffNegative = {
    expr = mac.diff (parse "00:00:00:00:00:05") (parse "00:00:00:00:00:01");
    expected = -4;
  };
  testDiffZero = {
    expr = mac.diff (parse "00:00:00:00:00:05") (parse "00:00:00:00:00:05");
    expected = 0;
  };

  # ===== Comparison helpers =====
  testComparisonLe = {
    expr = mac.le (parse "00:00:00:00:00:01") (parse "00:00:00:00:00:02");
    expected = true;
  };
  testComparisonGt = {
    expr = mac.gt (parse "00:00:00:00:00:02") (parse "00:00:00:00:00:01");
    expected = true;
  };
  testComparisonGe = {
    expr = mac.ge (parse "00:00:00:00:00:02") (parse "00:00:00:00:00:01");
    expected = true;
  };

  # ===== Comparison =====
  testEqSame = {
    expr = mac.eq (parse "aa:bb:cc:dd:ee:ff") (parse "aa:bb:cc:dd:ee:ff");
    expected = true;
  };
  testEqDifferent = {
    expr = mac.eq (parse "aa:bb:cc:dd:ee:ff") (parse "aa:bb:cc:dd:ee:fe");
    expected = false;
  };
  testLtTrue = {
    expr = mac.lt (parse "00:00:00:00:00:01") (parse "00:00:00:00:00:02");
    expected = true;
  };
  testCompareLt = {
    expr = mac.compare (parse "00:00:00:00:00:01") (parse "00:00:00:00:00:02");
    expected = -1;
  };
  testCompareEq = {
    expr = mac.compare (parse "00:00:00:00:00:01") (parse "00:00:00:00:00:01");
    expected = 0;
  };
  testCompareGt = {
    expr = mac.compare (parse "00:00:00:00:00:02") (parse "00:00:00:00:00:01");
    expected = 1;
  };
  testMinSmaller = {
    expr = mac.toString (mac.min (parse "00:00:00:00:00:01") (parse "00:00:00:00:00:02"));
    expected = "00:00:00:00:00:01";
  };
  testMaxLarger = {
    expr = mac.toString (mac.max (parse "00:00:00:00:00:01") (parse "00:00:00:00:00:02"));
    expected = "00:00:00:00:00:02";
  };

  # ===== Constants =====
  testConstantUnspecified = {
    expr = mac.toString mac.unspecified;
    expected = "00:00:00:00:00:00";
  };
  testConstantBroadcast = {
    expr = mac.toString mac.broadcast;
    expected = "ff:ff:ff:ff:ff:ff";
  };

  # ===== Curry =====
  testCurriedAdd = {
    expr = map mac.toString (
      map (mac.add 1) [
        (parse "00:00:00:00:00:00")
        (parse "00:00:00:00:00:10")
      ]
    );
    expected = [
      "00:00:00:00:00:01"
      "00:00:00:00:00:11"
    ];
  };
}
