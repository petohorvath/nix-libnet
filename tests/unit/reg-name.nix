{ helpers, libnet, ... }:
let
  inherit (libnet) regName;
  inherit (helpers) throws;
  inherit (regName) parse tryParse;
in
{
  # ===== tryParse: standard record =====
  testTryParseOkSuccess = {
    expr = (tryParse "example.com").success;
    expected = true;
  };
  testTryParseOkValue = {
    expr = (tryParse "example.com").value;
    expected = {
      _type = "regName";
      value = "example.com";
    };
  };
  testTryParseBadSuccess = {
    expr = (tryParse "bad host").success;
    expected = false;
  };
  testTryParseErrorString = {
    expr = builtins.isString (tryParse "bad host").error;
    expected = true;
  };
  testTryParseNotString = {
    expr = (tryParse 42).success;
    expected = false;
  };
  testParseThrows = {
    expr = throws (parse "bad host");
    expected = true;
  };

  # ===== Grammar (RFC 3986 reg-name) =====
  testUnderscore = {
    expr = regName.toString (parse "my_host");
    expected = "my_host";
  };
  testTilde = {
    expr = regName.isValid "~user";
    expected = true;
  };
  testSubDelimiters = {
    expr = regName.toString (parse "a+b!c$d&e'f(g)h*i,j;k=l");
    expected = "a+b!c$d&e'f(g)h*i,j;k=l";
  };
  testPercentEncoded = {
    expr = regName.toString (parse "a%20b");
    expected = "a%20b";
  };
  testNoLabelStructure = {
    expr = regName.isValid "..a..";
    expected = true;
  };
  # RFC 3986 §3.2.2: text that matches IPv4address is an IPv4 literal,
  # never a registered name.
  testRejectIpv4 = {
    expr = regName.isValid "1.2.3.4";
    expected = false;
  };
  testRejectIpv4Throws = {
    expr = throws (parse "192.0.2.1");
    expected = true;
  };
  testOutOfRangeQuad = {
    expr = regName.toString (parse "256.0.0.1");
    expected = "256.0.0.1";
  };
  testRejectEmpty = {
    expr = regName.isValid "";
    expected = false;
  };
  testRejectSpace = {
    expr = regName.isValid "bad host";
    expected = false;
  };
  testRejectColon = {
    expr = regName.isValid "h:80";
    expected = false;
  };
  testRejectAt = {
    expr = regName.isValid "u@h";
    expected = false;
  };
  testRejectBracket = {
    expr = regName.isValid "[::1]";
    expected = false;
  };
  testRejectTruncatedPercent = {
    expr = regName.isValid "a%2";
    expected = false;
  };
  testRejectBadPercent = {
    expr = regName.isValid "a%zz";
    expected = false;
  };

  # ===== toString / predicates =====
  testToStringPreservesCase = {
    expr = regName.toString (parse "Example.COM");
    expected = "Example.COM";
  };
  testIsValidOk = {
    expr = regName.isValid "example.com";
    expected = true;
  };
  testIsValidNotString = {
    expr = regName.isValid 42;
    expected = false;
  };
  testIsYes = {
    expr = regName.is (parse "example.com");
    expected = true;
  };
  testIsString = {
    expr = regName.is "example.com";
    expected = false;
  };
  testIsDomain = {
    expr = regName.is (libnet.domain.parse "example.com");
    expected = false;
  };

  # ===== Comparison (case-insensitive) =====
  testEqCaseInsensitive = {
    expr = regName.eq (parse "Example.COM") (parse "example.com");
    expected = true;
  };
  testEqDifferent = {
    expr = regName.eq (parse "a") (parse "b");
    expected = false;
  };
  testEqDomainSameText = {
    expr = regName.eq (parse "example.com") (libnet.domain.parse "example.com");
    expected = false;
  };
  testCompareOrder = {
    expr = regName.compare (parse "alpha") (parse "beta");
    expected = -1;
  };
  testCompareCaseInsensitiveEqual = {
    expr = regName.compare (parse "Example.COM") (parse "example.com");
    expected = 0;
  };
  testCompareCaseFolded = {
    expr = regName.compare (parse "B") (parse "a");
    expected = 1;
  };
  testLt = {
    expr = regName.lt (parse "alpha") (parse "beta");
    expected = true;
  };
  testLe = {
    expr = regName.le (parse "ALPHA") (parse "alpha");
    expected = true;
  };
  testGt = {
    expr = regName.gt (parse "beta") (parse "alpha");
    expected = true;
  };
  testGe = {
    expr = regName.ge (parse "alpha") (parse "beta");
    expected = false;
  };
  testMin = {
    expr = regName.toString (regName.min (parse "beta") (parse "alpha"));
    expected = "alpha";
  };
  testMax = {
    expr = regName.toString (regName.max (parse "beta") (parse "alpha"));
    expected = "beta";
  };
  testSortPartiallyApplied = {
    expr = map regName.toString (
      builtins.filter (regName.lt (parse "b")) [
        (parse "a")
        (parse "C")
        (parse "b")
      ]
    );
    expected = [ "C" ];
  };
}
