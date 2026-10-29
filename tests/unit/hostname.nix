{ helpers, libnet, ... }:
let
  inherit (libnet) hostname;
  inherit (helpers) throws;
  inherit (hostname) parse;

  # 1 + 60 ("123456789-" × 6) + 2 = 63 chars (maximum valid)
  label63Chars = "a123456789-123456789-123456789-123456789-123456789-123456789-xy";
  # 1 + 60 + 3 = 64 chars (one over the limit)
  label64Chars = "a123456789-123456789-123456789-123456789-123456789-123456789-xyz";
in
{
  # ===== Parse =====
  testParseSimple = {
    expr = (parse "nas").value;
    expected = "nas";
  };
  testParseSingleChar = {
    expr = (parse "b").value;
    expected = "b";
  };
  testParseWithDigits = {
    expr = (parse "host01").value;
    expected = "host01";
  };
  testParseLeadingDigit = {
    expr = (parse "3com").value;
    expected = "3com";
  };
  testParseWithHyphen = {
    expr = (parse "my-server").value;
    expected = "my-server";
  };
  testParseFoldsCase = {
    expr = (parse "MyHost").value;
    expected = "myhost";
  };
  testParseMaxLength = {
    expr = (parse label63Chars).value;
    expected = label63Chars;
  };
  testParseTagged = {
    expr = (parse "nas")._type;
    expected = "hostname";
  };

  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectUnderscore = {
    expr = throws (parse "host_name");
    expected = true;
  };
  testRejectDot = {
    expr = throws (parse "host.example.com");
    expected = true;
  };
  testRejectLeadingHyphen = {
    expr = throws (parse "-foo");
    expected = true;
  };
  testRejectTrailingHyphen = {
    expr = throws (parse "foo-");
    expected = true;
  };
  testRejectSingleHyphen = {
    expr = throws (parse "-");
    expected = true;
  };
  testRejectTooLong = {
    expr = throws (parse label64Chars);
    expected = true;
  };
  testRejectWhitespaceLeading = {
    expr = throws (parse " nas");
    expected = true;
  };
  testRejectWhitespaceTrailing = {
    expr = throws (parse "nas ");
    expected = true;
  };
  testRejectWhitespaceMiddle = {
    expr = throws (parse "my host");
    expected = true;
  };
  testRejectNonAscii = {
    expr = throws (parse "café");
    expected = true;
  };
  testRejectNotString = {
    expr = hostname.parse 42;
    expectedError.msg = "^libnet\\.hostname\\.parse: expected string, got int$";
  };
  testRejectInvalidNamesParse = {
    expr = parse "host_name";
    expectedError.msg = "^libnet\\.hostname\\.parse: invalid hostname \"host_name\"";
  };
  testRejectSlash = {
    expr = throws (parse "foo/bar");
    expected = true;
  };

  testTryParseOk = {
    expr = (hostname.tryParse "nas").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (hostname.tryParse "host_name").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = builtins.isString (hostname.tryParse "host_name").error;
    expected = true;
  };
  testTryParseNotString = {
    expr = (hostname.tryParse 42).success;
    expected = false;
  };

  # ===== Round-trip =====
  testRoundTripToString = {
    expr = hostname.toString (parse "nas");
    expected = "nas";
  };
  testToStringLowercase = {
    expr = hostname.toString (parse "MyHost");
    expected = "myhost";
  };
  testToStringRejectsString = {
    expr = hostname.toString "nas";
    expectedError.msg = "^libnet\\.hostname\\.toString: expected hostname value, got string$";
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = hostname.is (parse "nas");
    expected = true;
  };
  testIsString = {
    expr = hostname.is "nas";
    expected = false;
  };
  testIsUntagged = {
    expr = hostname.is { value = "nas"; };
    expected = false;
  };
  testIsValidOk = {
    expr = hostname.isValid "nas";
    expected = true;
  };
  testIsValidBad = {
    expr = hostname.isValid "host_name";
    expected = false;
  };
  testIsValidNotString = {
    expr = hostname.isValid 42;
    expected = false;
  };

  testNoNormalize = {
    expr = hostname ? normalize;
    expected = false;
  };

  # ===== Equality (structural on the folded text) =====
  testEqSame = {
    expr = hostname.eq (parse "nas") (parse "nas");
    expected = true;
  };
  testEqCaseUpper = {
    expr = hostname.eq (parse "NAS") (parse "nas");
    expected = true;
  };
  testEqCaseMixed = {
    expr = hostname.eq (parse "MyHost") (parse "myhost");
    expected = true;
  };
  testEqDifferent = {
    expr = hostname.eq (parse "nas") (parse "router");
    expected = false;
  };

  # ===== Comparison =====
  testGtYes = {
    expr = hostname.gt (parse "beta") (parse "alpha");
    expected = true;
  };
  testLtYes = {
    expr = hostname.lt (parse "alpha") (parse "beta");
    expected = true;
  };
  testLtNo = {
    expr = hostname.lt (parse "beta") (parse "alpha");
    expected = false;
  };
  testLtFoldedCase = {
    expr = hostname.lt (parse "Alpha") (parse "beta");
    expected = true;
  };
  testCompareLt = {
    expr = hostname.compare (parse "alpha") (parse "beta");
    expected = -1;
  };
  testCompareEqCase = {
    expr = hostname.compare (parse "NAS") (parse "nas");
    expected = 0;
  };
  testCompareGt = {
    expr = hostname.compare (parse "z") (parse "a");
    expected = 1;
  };
  testLeEqual = {
    expr = hostname.le (parse "nas") (parse "nas");
    expected = true;
  };
  testGeEqual = {
    expr = hostname.ge (parse "nas") (parse "nas");
    expected = true;
  };
  testMinPick = {
    expr = (hostname.min (parse "beta") (parse "alpha")).value;
    expected = "alpha";
  };
  testMaxPick = {
    expr = (hostname.max (parse "beta") (parse "alpha")).value;
    expected = "beta";
  };
  testSortPartiallyApplied = {
    expr = map hostname.toString (
      builtins.filter (hostname.lt (parse "beta")) (
        map parse [
          "Alpha"
          "Gamma"
          "beta"
        ]
      )
    );
    expected = [ "gamma" ];
  };
  testLtNamesItself = {
    expr = hostname.lt (parse "nas") "nas";
    expectedError.msg = "^libnet\\.hostname\\.lt: expected hostname value, got string$";
  };
  testMinRejectsDomain = {
    expr = hostname.min (libnet.domain.parse "example.com") (parse "nas");
    expectedError.msg = "^libnet\\.hostname\\.min: expected hostname value, got domain value$";
  };
}
