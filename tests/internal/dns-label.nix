{ harness }:
let
  dnsLabel = import ../../lib/internal/dns-label.nix;
  inherit (dnsLabel) isValidLabel;
in
{
  # ===== positive =====
  testSimple = {
    expr = isValidLabel "nas";
    expected = true;
  };
  testSingleChar = {
    expr = isValidLabel "a";
    expected = true;
  };
  testDigits = {
    expr = isValidLabel "host01";
    expected = true;
  };
  testLeadingDigit = {
    expr = isValidLabel "3com";
    expected = true;
  };
  testWithHyphen = {
    expr = isValidLabel "my-server";
    expected = true;
  };
  testMixedCase = {
    expr = isValidLabel "MyHost";
    expected = true;
  };
  testAllDigits = {
    expr = isValidLabel "12345";
    expected = true;
  };
  # 1 + 60 ("123456789-" × 6) + 2 = 63 chars (maximum)
  testMaxLength = {
    expr = isValidLabel "a123456789-123456789-123456789-123456789-123456789-123456789-xy";
    expected = true;
  };

  # ===== negative =====
  testEmpty = {
    expr = isValidLabel "";
    expected = false;
  };
  testUnderscore = {
    expr = isValidLabel "host_name";
    expected = false;
  };
  testDot = {
    expr = isValidLabel "host.example";
    expected = false;
  };
  testLeadingHyphen = {
    expr = isValidLabel "-foo";
    expected = false;
  };
  testTrailingHyphen = {
    expr = isValidLabel "foo-";
    expected = false;
  };
  testSingleHyphen = {
    expr = isValidLabel "-";
    expected = false;
  };
  # 64 chars (one over)
  testTooLong = {
    expr = isValidLabel "a123456789-123456789-123456789-123456789-123456789-123456789-xyz";
    expected = false;
  };
  testWhitespace = {
    expr = isValidLabel "my host";
    expected = false;
  };
  testNonAscii = {
    expr = isValidLabel "café";
    expected = false;
  };
  testSlash = {
    expr = isValidLabel "foo/bar";
    expected = false;
  };
  testNotStringInt = {
    expr = isValidLabel 42;
    expected = false;
  };
  testNotStringNull = {
    expr = isValidLabel null;
    expected = false;
  };

  # ===== pattern is exposed =====
  testPatternExists = {
    expr = builtins.isString dnsLabel.labelPattern;
    expected = true;
  };
}
