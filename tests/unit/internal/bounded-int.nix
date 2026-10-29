{ helpers, internal, ... }:
let
  inherit (internal) boundedInt;
  inherit (helpers) throws;

  # A domain whose lower bound sits above zero, like `vlanId` and `mtu`.
  offset = boundedInt {
    typeName = "offset";
    lowestValue = 2;
    highestValue = 9;
    arithmetic = true;
  };
  # The defaults leave arithmetic out, as `icmpType` does.
  plain = boundedInt {
    typeName = "plain";
    lowestValue = 0;
    highestValue = 9;
  };
  # A domain of one value, where both bounds are the same integer.
  single = boundedInt {
    typeName = "single";
    lowestValue = 7;
    highestValue = 7;
    arithmetic = true;
  };
  # A second domain over the same range, to tell tags apart.
  other = boundedInt {
    typeName = "other";
    lowestValue = 2;
    highestValue = 9;
    arithmetic = true;
  };

  coreNames = [
    "compare"
    "eq"
    "fromInt"
    "ge"
    "gt"
    "highestValue"
    "is"
    "isValid"
    "le"
    "lowestValue"
    "lt"
    "max"
    "min"
    "parse"
    "toInt"
    "toString"
    "tryParse"
  ];
in
{
  # ===== Exports =====
  testExportsWithoutArithmetic = {
    expr = builtins.attrNames plain;
    expected = coreNames;
  };
  testExportsWithArithmetic = {
    expr = builtins.attrNames offset;
    expected = builtins.sort builtins.lessThan (
      coreNames
      ++ [
        "add"
        "diff"
        "next"
        "prev"
        "sub"
      ]
    );
  };
  testBoundsPassThrough = {
    expr = [
      offset.lowestValue
      offset.highestValue
    ];
    expected = [
      2
      9
    ];
  };
  testNegativeLowerBoundThrows = {
    expr =
      throws
        (boundedInt {
          typeName = "negative";
          lowestValue = -1;
          highestValue = 1;
        }).lowestValue;
    expected = true;
  };

  # ===== Parsing =====
  testParseDecimal = {
    expr = plain.parse "5";
    expected = {
      _type = "plain";
      value = 5;
    };
  };
  testParseBounds = {
    expr = map (input: offset.toInt (offset.parse input)) [
      "2"
      "9"
    ];
    expected = [
      2
      9
    ];
  };
  testParseRoundTrip = {
    expr = offset.toString (offset.parse "7");
    expected = "7";
  };
  testParseOutOfRangeThrows = {
    expr = map (input: throws (offset.parse input)) [
      "0"
      "1"
      "10"
    ];
    expected = [
      true
      true
      true
    ];
  };
  testParseRejectsNonDecimal = {
    expr = builtins.all (input: throws (offset.parse input)) [
      ""
      "-2"
      "+2"
      " 2"
      "2 "
      "0x2"
      "2.0"
      "two"
    ];
    expected = true;
  };
  testParseRejectsLeadingZeros = {
    expr = map (input: (plain.tryParse input).success) [
      "0"
      "00"
      "05"
      "009"
    ];
    expected = [
      true
      false
      false
      false
    ];
  };
  testParseLeadingZeroError = {
    expr = map (input: (plain.tryParse input).error) [
      "05"
      "00"
    ];
    expected = [
      "libnet.plain.parse: leading zero in \"05\""
      "libnet.plain.parse: leading zero in \"00\""
    ];
  };
  testTryParseRejectsOverlongDigits = {
    # The second is 2^64 + 9, which wraps to 9 where integer overflow is
    # silent.
    expr = map (input: (plain.tryParse input).success) [
      "99999999999999999999"
      "18446744073709551625"
    ];
    expected = [
      false
      false
    ];
  };
  testParseOverlongErrorIsOutOfRange = {
    expr = (plain.tryParse "99999999999999999999").error;
    expected = "libnet.plain.parse: out of range [0, 9]: 99999999999999999999";
  };
  testParseRejectsNonStrings = {
    expr = builtins.all (value: throws (offset.parse value)) [
      2
      null
      [ "2" ]
    ];
    expected = true;
  };
  testParseErrorNamesTypeAndFunction = {
    expr = builtins.match "libnet[.]offset[.]parse: out of range \\[2, 9]: 10" (offset.tryParse "10")
    .error;
    expected = [ ];
  };
  testTryParseOk = {
    expr = offset.tryParse "3";
    expected = {
      success = true;
      value = offset.fromInt 3;
      error = null;
    };
  };
  testTryParseRecovers = {
    expr = map (value: (offset.tryParse value).success) [
      "1"
      "x"
      3
    ];
    expected = [
      false
      false
      false
    ];
  };

  # ===== Tag =====
  testFromIntUsesTypeName = {
    expr = offset.fromInt 2;
    expected = {
      _type = "offset";
      value = 2;
    };
  };
  testIsRejectsOtherTypeName = {
    expr = offset.is (other.fromInt 2);
    expected = false;
  };
  testIsDoesNotForcePayload = {
    expr = offset.is {
      _type = "offset";
      value = throw "payload forced";
    };
    expected = true;
  };
  testEqRejectsOtherTypeName = {
    expr = offset.eq (offset.fromInt 2) (other.fromInt 2);
    expected = false;
  };

  # ===== Bounds =====
  testIsValidLowerBound = {
    expr = offset.isValid "2";
    expected = true;
  };
  testIsValidBelowLowerBound = {
    expr = offset.isValid "1";
    expected = false;
  };
  testIsValidUpperBound = {
    expr = offset.isValid "9";
    expected = true;
  };
  testIsValidAboveUpperBound = {
    expr = offset.isValid "10";
    expected = false;
  };
  testIsValidRejectsIntegers = {
    expr = offset.isValid 5;
    expected = false;
  };
  testIsValidSingleValue = {
    expr = map single.isValid [
      "6"
      "7"
      "8"
    ];
    expected = [
      false
      true
      false
    ];
  };
  testFromIntBelowLowerBoundThrows = {
    expr = throws (offset.fromInt 1);
    expected = true;
  };
  testFromIntAboveUpperBoundThrows = {
    expr = throws (offset.fromInt 10);
    expected = true;
  };
  testFromIntRejectsNonInts = {
    expr = builtins.all (value: throws (offset.fromInt value)) [
      "3"
      3.0
      null
    ];
    expected = true;
  };
  testToIntRoundTripsEveryValue = {
    expr = map (n: offset.toInt (offset.fromInt n)) [
      2
      5
      9
    ];
    expected = [
      2
      5
      9
    ];
  };

  # ===== Comparison =====
  testCompareLess = {
    expr = offset.compare (offset.fromInt 3) (offset.fromInt 5);
    expected = -1;
  };
  testMinTieReturnsFirst = {
    expr = (offset.min (offset.fromInt 3) (other.fromInt 3))._type;
    expected = "offset";
  };
  testMaxTieReturnsFirst = {
    expr = (offset.max (offset.fromInt 3) (other.fromInt 3))._type;
    expected = "offset";
  };

  # ===== Arithmetic =====
  testAddNegative = {
    expr = offset.toInt (offset.add (-3) (offset.fromInt 6));
    expected = 3;
  };
  testAddBelowLowerBoundThrows = {
    expr = throws (offset.add (-1) (offset.fromInt 2));
    expected = true;
  };
  testSubIsAddNegated = {
    expr = offset.eq (offset.sub 2 (offset.fromInt 6)) (offset.add (-2) (offset.fromInt 6));
    expected = true;
  };
  testSubNegativeAddsUp = {
    expr = offset.toInt (offset.sub (-2) (offset.fromInt 3));
    expected = 5;
  };
  testDiffIsSecondMinusFirst = {
    expr = offset.diff (offset.fromInt 9) (offset.fromInt 2);
    expected = -7;
  };
  testAddPartialApplication = {
    expr = map (value: offset.toInt value) (
      map (offset.add 1) [
        (offset.fromInt 2)
        (offset.fromInt 5)
      ]
    );
    expected = [
      3
      6
    ];
  };
  testNextAtSingleValueThrows = {
    expr = throws (single.next (single.fromInt 7));
    expected = true;
  };
  testPrevAtSingleValueThrows = {
    expr = throws (single.prev (single.fromInt 7));
    expected = true;
  };
  testAddZeroAtSingleValue = {
    expr = single.toInt (single.add 0 (single.fromInt 7));
    expected = 7;
  };
}
