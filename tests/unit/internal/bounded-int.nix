{ helpers, internal, ... }:
let
  inherit (internal) boundedInt;
  inherit (helpers) throws;

  # A domain that crosses zero, unlike the public scalars built on it.
  signed = boundedInt {
    typeName = "signed";
    lowestValue = -3;
    highestValue = 3;
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
    lowestValue = -3;
    highestValue = 3;
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
    "toInt"
    "toString"
  ];
in
{
  # ===== Exports =====
  testExportsWithoutArithmetic = {
    expr = builtins.attrNames plain;
    expected = coreNames;
  };
  testExportsWithArithmetic = {
    expr = builtins.attrNames signed;
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
      signed.lowestValue
      signed.highestValue
    ];
    expected = [
      (-3)
      3
    ];
  };

  # ===== Tag =====
  testFromIntUsesTypeName = {
    expr = signed.fromInt 2;
    expected = {
      _type = "signed";
      value = 2;
    };
  };
  testIsRejectsOtherTypeName = {
    expr = signed.is (other.fromInt 2);
    expected = false;
  };
  testIsDoesNotForcePayload = {
    expr = signed.is {
      _type = "signed";
      value = throw "payload forced";
    };
    expected = true;
  };
  testEqRejectsOtherTypeName = {
    expr = signed.eq (signed.fromInt 2) (other.fromInt 2);
    expected = false;
  };

  # ===== Bounds =====
  testIsValidNegativeLowerBound = {
    expr = signed.isValid (-3);
    expected = true;
  };
  testIsValidBelowNegativeLowerBound = {
    expr = signed.isValid (-4);
    expected = false;
  };
  testIsValidUpperBound = {
    expr = signed.isValid 3;
    expected = true;
  };
  testIsValidAboveUpperBound = {
    expr = signed.isValid 4;
    expected = false;
  };
  testIsValidZeroInsideSignedDomain = {
    expr = signed.isValid 0;
    expected = true;
  };
  testIsValidSingleValue = {
    expr = map single.isValid [
      6
      7
      8
    ];
    expected = [
      false
      true
      false
    ];
  };
  testFromIntBelowNegativeLowerBoundThrows = {
    expr = throws (signed.fromInt (-4));
    expected = true;
  };
  testFromIntAboveUpperBoundThrows = {
    expr = throws (signed.fromInt 4);
    expected = true;
  };
  testFromIntRejectsNonInts = {
    expr = builtins.all (value: throws (signed.fromInt value)) [
      "1"
      1.0
      null
    ];
    expected = true;
  };
  testToStringNegative = {
    expr = signed.toString (signed.fromInt (-3));
    expected = "-3";
  };
  testToIntRoundTripsEveryValue = {
    expr = map (n: signed.toInt (signed.fromInt n)) [
      (-3)
      0
      3
    ];
    expected = [
      (-3)
      0
      3
    ];
  };

  # ===== Comparison =====
  testCompareAcrossZero = {
    expr = signed.compare (signed.fromInt (-1)) (signed.fromInt 1);
    expected = -1;
  };
  testMinTieReturnsFirst = {
    expr = (signed.min (signed.fromInt 1) (other.fromInt 1))._type;
    expected = "signed";
  };
  testMaxTieReturnsFirst = {
    expr = (signed.max (signed.fromInt 1) (other.fromInt 1))._type;
    expected = "signed";
  };

  # ===== Arithmetic =====
  testAddCrossesZero = {
    expr = signed.toInt (signed.add (-3) (signed.fromInt 1));
    expected = -2;
  };
  testAddBelowNegativeLowerBoundThrows = {
    expr = throws (signed.add (-1) (signed.fromInt (-3)));
    expected = true;
  };
  testSubIsAddNegated = {
    expr = signed.eq (signed.sub 2 (signed.fromInt 1)) (signed.add (-2) (signed.fromInt 1));
    expected = true;
  };
  testSubNegativeAddsUp = {
    expr = signed.toInt (signed.sub (-2) (signed.fromInt 1));
    expected = 3;
  };
  testDiffIsSecondMinusFirst = {
    expr = signed.diff (signed.fromInt 3) (signed.fromInt (-3));
    expected = -6;
  };
  testAddPartialApplication = {
    expr = map (value: signed.toInt value) (
      map (signed.add 1) [
        (signed.fromInt (-3))
        (signed.fromInt 0)
      ]
    );
    expected = [
      (-2)
      1
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
