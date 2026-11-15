{ internal, ... }:
let
  inherit (internal) address;

  # A 4-bit scalar kind, small enough to pin both bounds.
  nibble = address.scalar {
    typeName = "nibble";
    maxValue = 15;
    format = value: builtins.toString value.value;
  };
  mkNibble = value: {
    _type = "nibble";
    inherit value;
  };

  # A kind with a non-zero lower bound whose errors name its range, as
  # the bounded integers' errors do.
  digit = address.scalar {
    typeName = "digit";
    minValue = 1;
    maxValue = 9;
    range = "[1, 9]";
    format = value: builtins.toString value.value;
  };
  mkDigit = value: {
    _type = "digit";
    inherit value;
  };

  mkIpv4 = value: {
    _type = "ipv4";
    inherit value;
  };

  mkMac = value: {
    _type = "mac";
    inherit value;
  };

  words = address.words { format = value: builtins.toJSON value.words; };
  mkWords = words: {
    _type = "ipv6";
    inherit words;
  };
  maxWords = mkWords [
    4294967295
    4294967295
    4294967295
    4294967295
  ];
  zeroWords = mkWords [
    0
    0
    0
    0
  ];

  smallestInt = -9223372036854775807 - 1;
in
{
  # ===== offsetWithin =====
  testOffsetWithinAddPinsBounds = {
    expr =
      let
        within = address.offsetWithin {
          minValue = 1;
          maxValue = 10;
        };
      in
      [
        (within.add 5 5)
        (within.add 5 6)
        (within.add 5 (-4))
        (within.add 5 (-5))
      ];
    expected = [
      10
      null
      1
      null
    ];
  };
  testOffsetWithinSubPinsBounds = {
    expr =
      let
        within = address.offsetWithin {
          minValue = 1;
          maxValue = 10;
        };
      in
      [
        (within.sub 5 4)
        (within.sub 5 5)
        (within.sub 5 (-5))
        (within.sub 5 (-6))
      ];
    expected = [
      1
      null
      10
      null
    ];
  };
  # An offset at either end of the Nix integer range is rejected without
  # overflowing, which Nix 2.18 would wrap silently.
  testOffsetWithinExtremeOffsets = {
    expr =
      let
        within = address.offsetWithin {
          minValue = 0;
          maxValue = 65535;
        };
      in
      [
        (within.add 0 smallestInt)
        (within.add 65535 9223372036854775807)
        (within.sub 0 9223372036854775807)
        (within.sub 65535 smallestInt)
      ];
    expected = [
      null
      null
      null
      null
    ];
  };

  # ===== scalar =====
  testScalarAddToUpperBound = {
    expr = nibble.add "nibble.add" 15 (mkNibble 0);
    expected = mkNibble 15;
  };
  testScalarAddPastUpperBound = {
    expr = nibble.add "nibble.next" 1 (mkNibble 15);
    expectedError.msg = "^libnet\\.nibble\\.next: out of range: 15 \\+ 1$";
  };
  testScalarAddBelowLowerBound = {
    expr = nibble.add "nibble.add" (-1) (mkNibble 0);
    expectedError.msg = "^libnet\\.nibble\\.add: out of range: 0 \\+ -1$";
  };
  testScalarSubToLowerBound = {
    expr = nibble.sub "nibble.sub" 15 (mkNibble 15);
    expected = mkNibble 0;
  };
  testScalarSubSmallestInteger = {
    expr = nibble.sub "nibble.sub" smallestInt (mkNibble 0);
    expectedError.msg = "^libnet\\.nibble\\.sub: out of range: 0 - -9223372036854775808$";
  };
  testScalarRejectsFloatOffset = {
    expr = nibble.add "nibble.add" 1.0 (mkNibble 0);
    expectedError.msg = "^libnet\\.nibble\\.add: expected int, got float$";
  };

  testScalarAddNamesRange = {
    expr = digit.add "digit.next" 1 (mkDigit 9);
    expectedError.msg = "^libnet\\.digit\\.next: out of range \\[1, 9\\]: 9 \\+ 1$";
  };
  testScalarSubToNonZeroLowerBound = {
    expr = digit.sub "digit.sub" 8 (mkDigit 9);
    expected = mkDigit 1;
  };
  testScalarSubBelowNonZeroLowerBound = {
    expr = digit.sub "digit.prev" 1 (mkDigit 1);
    expectedError.msg = "^libnet\\.digit\\.prev: out of range \\[1, 9\\]: 1 - 1$";
  };
  testScalarRejectsOtherKind = {
    expr = digit.add "digit.add" 1 (mkNibble 1);
    expectedError.msg = "^libnet\\.digit\\.add: expected digit value, got nibble value$";
  };
  testScalarDiffIsSecondMinusFirst = {
    expr = [
      (nibble.diff "nibble.diff" (mkNibble 3) (mkNibble 15))
      (nibble.diff "nibble.diff" (mkNibble 15) (mkNibble 3))
    ];
    expected = [
      12
      (-12)
    ];
  };
  testScalarDiffRejectsOtherKind = {
    expr = nibble.diff "nibble.diff" (mkNibble 3) (mkDigit 1);
    expectedError.msg = "^libnet\\.nibble\\.diff: expected nibble value, got digit value$";
  };

  # ===== ipv4 =====
  testIpv4AddWithinFamily = {
    expr = address.ipv4.add "ip.add" 1 (mkIpv4 4294967294);
    expected = mkIpv4 4294967295;
  };
  testIpv4AddFormatsAddress = {
    expr = address.ipv4.add "ip.next" 1 (mkIpv4 4294967295);
    expectedError.msg = "^libnet\\.ip\\.next: out of range: 255\\.255\\.255\\.255 \\+ 1$";
  };
  testIpv4SubFormatsAddress = {
    expr = address.ipv4.sub "ipv4.prev" 1 (mkIpv4 0);
    expectedError.msg = "^libnet\\.ipv4\\.prev: out of range: 0\\.0\\.0\\.0 - 1$";
  };
  testIpv4Diff = {
    expr = address.ipv4.diff "ip.diff" (mkIpv4 0) (mkIpv4 4294967295);
    expected = 4294967295;
  };

  # ===== ipv6 =====
  testIpv6AddFormatsAddress = {
    expr = address.ipv6.add "ip.next" 1 maxWords;
    expectedError.msg = "^libnet\\.ip\\.next: out of range: ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff \\+ 1$";
  };
  testIpv6SubFormatsAddress = {
    expr = address.ipv6.sub "ipv6.prev" 1 zeroWords;
    expectedError.msg = "^libnet\\.ipv6\\.prev: out of range: :: - 1$";
  };
  testIpv6DiffFormatsAddresses = {
    expr = address.ipv6.diff "ip.diff" zeroWords maxWords;
    expectedError.msg = "^libnet\\.ip\\.diff: difference out of the Nix integer range: ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff - ::$";
  };

  # ===== words =====
  testWordsAddCarriesAcrossWords = {
    expr =
      (words.add "ipv6.add" 1 (mkWords [
        0
        4294967295
        4294967295
        4294967295
      ])).words;
    expected = [
      1
      0
      0
      0
    ];
  };
  testWordsAddNegativeBorrowsAcrossWords = {
    expr =
      (words.add "ipv6.add" (-1) (mkWords [
        1
        0
        0
        0
      ])).words;
    expected = [
      0
      4294967295
      4294967295
      4294967295
    ];
  };
  testWordsAddPastMax = {
    expr = words.add "ipv6.next" 1 maxWords;
    expectedError.msg = "^libnet\\.ipv6\\.next: out of range: ";
  };
  testWordsSubBelowZero = {
    expr = words.sub "ipv6.prev" 1 zeroWords;
    expectedError.msg = "^libnet\\.ipv6\\.prev: out of range: ";
  };
  testWordsSubSmallestInteger = {
    expr = (words.sub "ipv6.sub" smallestInt zeroWords).words;
    expected = [
      0
      0
      2147483648
      0
    ];
  };
  testWordsDiffSmallestInteger = {
    expr = words.diff "ipv6.diff" (mkWords [
      0
      0
      2147483648
      0
    ]) zeroWords;
    expected = smallestInt;
  };
  testWordsDiffAboveLargestInteger = {
    expr = words.diff "ip.diff" zeroWords (mkWords [
      0
      0
      2147483648
      0
    ]);
    expectedError.msg = "^libnet\\.ip\\.diff: difference out of the Nix integer range: ";
  };

  # ===== Builders =====
  testIpv4FromBytes = {
    expr = address.ipv4.fromBytes "ipv4.fromBytes" [
      192
      0
      2
      1
    ];
    expected = mkIpv4 3221225985;
  };
  testIpv4FromBytesUnchecked = {
    expr = address.ipv4.fromBytesUnchecked [
      192
      0
      2
      1
    ];
    expected = mkIpv4 3221225985;
  };
  testIpv4FromBytesNamesCaller = {
    expr = address.ipv4.fromBytes "ip.fromBytes" [
      192
      0
      2
    ];
    expectedError.msg = "^libnet\\.ip\\.fromBytes: expected 4 bytes, got 3$";
  };
  testIpv4FromBytesRejectsNonList = {
    expr = address.ipv4.fromBytes "ip.fromBytes" "192.0.2.1";
    expectedError.msg = "^libnet\\.ip\\.fromBytes: expected list, got string$";
  };
  testIpv4FromBytesRejectsElementType = {
    expr = address.ipv4.fromBytes "ip.fromBytes" [
      192
      0
      2
      { }
    ];
    expectedError.msg = "^libnet\\.ip\\.fromBytes: expected int byte, got set$";
  };
  # Forced only to weak head normal form, so the check must run at the
  # call rather than when a field of the value is read.
  testIpv4FromBytesChecksAtCall = {
    expr = builtins.seq (address.ipv4.fromBytes "ip.fromBytes" [
      256
      0
      2
      1
    ]) true;
    expectedError.msg = "^libnet\\.ip\\.fromBytes: byte out of range \\[0, 255\\]: 256$";
  };

  testIpv6FromWords = {
    expr = address.ipv6.fromWords "ipv6.fromWords" [
      536939960
      0
      0
      1
    ];
    expected = mkWords [
      536939960
      0
      0
      1
    ];
  };
  testIpv6FromWordsChecksAtCall = {
    expr = builtins.seq (address.ipv6.fromWords "ipv6.fromWords" [
      4294967296
      0
      0
      0
    ]) true;
    expectedError.msg = "^libnet\\.ipv6\\.fromWords: word out of range \\[0, 4294967295\\]: 4294967296$";
  };
  testIpv6FromGroups = {
    expr = address.ipv6.fromGroups "ipv6.fromGroups" [
      8193
      3512
      0
      0
      0
      0
      0
      1
    ];
    expected = mkWords [
      536939960
      0
      0
      1
    ];
  };
  testIpv6FromGroupsUnchecked = {
    expr = address.ipv6.fromGroupsUnchecked [
      8193
      3512
      0
      0
      0
      0
      0
      1
    ];
    expected = mkWords [
      536939960
      0
      0
      1
    ];
  };
  testIpv6FromGroupsChecksAtCall = {
    expr = builtins.seq (address.ipv6.fromGroups "ipv6.fromGroups" [
      8193
      3512
    ]) true;
    expectedError.msg = "^libnet\\.ipv6\\.fromGroups: expected 8 groups, got 2$";
  };
  testIpv6FromBytes = {
    expr = address.ipv6.fromBytes "ipv6.fromBytes" [
      32
      1
      13
      184
      0
      0
      0
      0
      0
      0
      0
      0
      0
      0
      0
      1
    ];
    expected = mkWords [
      536939960
      0
      0
      1
    ];
  };
  testIpv6FromBytesNamesCaller = {
    expr = address.ipv6.fromBytes "ip.fromBytes" (builtins.genList (_: 0) 15 ++ [ 256 ]);
    expectedError.msg = "^libnet\\.ip\\.fromBytes: byte out of range \\[0, 255\\]: 256$";
  };
  testIpv6FromBytesChecksAtCall = {
    expr = builtins.seq (address.ipv6.fromBytes "ip.fromBytes" (builtins.genList (_: 0) 15)) true;
    expectedError.msg = "^libnet\\.ip\\.fromBytes: expected 16 bytes, got 15$";
  };

  testMacFromBytes = {
    expr = address.mac.fromBytes "mac.fromBytes" [
      160
      54
      159
      27
      30
      85
    ];
    expected = mkMac 176156458032725;
  };
  testMacFromBytesUnchecked = {
    expr = address.mac.fromBytesUnchecked [
      160
      54
      159
      27
      30
      85
    ];
    expected = mkMac 176156458032725;
  };
  testMacFromBytesRejectsLength = {
    expr = address.mac.fromBytes "mac.fromBytes" [ 160 ];
    expectedError.msg = "^libnet\\.mac\\.fromBytes: expected 6 bytes, got 1$";
  };
  testMacFromBytesChecksAtCall = {
    expr = builtins.seq (address.mac.fromBytes "mac.fromBytes" [
      160
      54
      159
      27
      30
      (-1)
    ]) true;
    expectedError.msg = "^libnet\\.mac\\.fromBytes: byte out of range \\[0, 255\\]: -1$";
  };
}
