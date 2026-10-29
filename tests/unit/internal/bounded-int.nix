{ helpers, internal, ... }:
let
  inherit (internal) boundedInt;
  inherit (helpers) throws;

  # A domain whose lower bound sits above zero, like `vlanId` and `mtu`.
  offset = boundedInt {
    typeName = "offset";
    minValue = 2;
    maxValue = 9;
    arithmetic = true;
  };
  # The defaults leave arithmetic out, as `icmpType` does.
  plain = boundedInt {
    typeName = "plain";
    minValue = 0;
    maxValue = 9;
  };
  # A domain of one value, where both bounds are the same integer.
  single = boundedInt {
    typeName = "single";
    minValue = 7;
    maxValue = 7;
    arithmetic = true;
  };
  # A second domain over the same range, to tell tags apart.
  other = boundedInt {
    typeName = "other";
    minValue = 2;
    maxValue = 9;
    arithmetic = true;
  };

  valid = offset.fromInt 2;
  wrong = other.fromInt 2;
  kindError = function: "^libnet\\.offset\\.${function}: expected offset value, got other value$";

  # Test names by function, for functions of one scalar.
  unaryFunctions = {
    Next = "next";
    Prev = "prev";
    ToInt = "toInt";
    ToString = "toString";
  };
  # Test names by function, for functions of two scalars.
  binaryFunctions = {
    Compare = "compare";
    Diff = "diff";
    Ge = "ge";
    Gt = "gt";
    Le = "le";
    Lt = "lt";
    Max = "max";
    Min = "min";
  };

  # Every function that takes a scalar names itself for another kind,
  # including those built on the shared comparison and offset logic.
  wrongKindTests =
    builtins.listToAttrs (
      map (name: {
        name = "test${name}RejectsOtherKind";
        value = {
          expr = offset.${unaryFunctions.${name}} wrong;
          expectedError.msg = kindError unaryFunctions.${name};
        };
      }) (builtins.attrNames unaryFunctions)
    )
    // builtins.listToAttrs (
      builtins.concatMap (name: [
        {
          name = "test${name}RejectsOtherKindFirst";
          value = {
            expr = offset.${binaryFunctions.${name}} wrong valid;
            expectedError.msg = kindError binaryFunctions.${name};
          };
        }
        {
          name = "test${name}RejectsOtherKindSecond";
          value = {
            expr = offset.${binaryFunctions.${name}} valid wrong;
            expectedError.msg = kindError binaryFunctions.${name};
          };
        }
      ]) (builtins.attrNames binaryFunctions)
    );

  coreNames = [
    "compare"
    "eq"
    "fromInt"
    "ge"
    "gt"
    "is"
    "isValid"
    "le"
    "lt"
    "max"
    "maxValue"
    "min"
    "minValue"
    "parse"
    "toInt"
    "toString"
    "tryParse"
  ];
in
wrongKindTests
// {
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
      offset.minValue
      offset.maxValue
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
          minValue = -1;
          maxValue = 1;
        }).minValue;
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
    # Mark the equal operands apart to see which one comes back.
    expr =
      (offset.min (offset.fromInt 3 // { operand = "first"; }) (
        offset.fromInt 3 // { operand = "second"; }
      )).operand;
    expected = "first";
  };
  testMaxTieReturnsFirst = {
    # Mark the equal operands apart to see which one comes back.
    expr =
      (offset.max (offset.fromInt 3 // { operand = "first"; }) (
        offset.fromInt 3 // { operand = "second"; }
      )).operand;
    expected = "first";
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
  testAddRejectsOtherKind = {
    expr = offset.add 1 wrong;
    expectedError.msg = kindError "add";
  };
  testSubRejectsOtherKind = {
    expr = offset.sub 1 wrong;
    expectedError.msg = kindError "sub";
  };
  testAddRejectsFloatOffset = {
    expr = offset.add 1.0 valid;
    expectedError.msg = "^libnet\\.offset\\.add: expected int, got float$";
  };
  testSubRejectsStringOffset = {
    expr = offset.sub "1" valid;
    expectedError.msg = "^libnet\\.offset\\.sub: expected int, got string$";
  };
  testAddZeroAtSingleValue = {
    expr = single.toInt (single.add 0 (single.fromInt 7));
    expected = 7;
  };
}
