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

  # ===== intList =====
  testIntListReturnsList = {
    expr =
      address.intList "mac.fromBytes"
        {
          count = 2;
          part = "byte";
          maxValue = 255;
        }
        [
          0
          255
        ];
    expected = [
      0
      255
    ];
  };
  testIntListRejectsLength = {
    expr = address.intList "mac.fromBytes" {
      count = 2;
      part = "byte";
      maxValue = 255;
    } [ 0 ];
    expectedError.msg = "^libnet\\.mac\\.fromBytes: expected 2 bytes, got 1$";
  };
  testIntListRejectsElementType = {
    expr =
      address.intList "mac.fromBytes"
        {
          count = 2;
          part = "byte";
          maxValue = 255;
        }
        [
          0
          { }
        ];
    expectedError.msg = "^libnet\\.mac\\.fromBytes: expected int byte, got set$";
  };
  testIntListRejectsElementRange = {
    expr =
      address.intList "mac.fromBytes"
        {
          count = 2;
          part = "byte";
          maxValue = 255;
        }
        [
          0
          256
        ];
    expectedError.msg = "^libnet\\.mac\\.fromBytes: byte out of range \\[0, 255\\]: 256$";
  };
  testIntListRejectsNonList = {
    expr = address.intList "mac.fromBytes" {
      count = 2;
      part = "byte";
      maxValue = 255;
    } "0 255";
    expectedError.msg = "^libnet\\.mac\\.fromBytes: expected list, got string$";
  };
}
