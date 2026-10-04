{ harness }:
let
  domain = import ../lib/domain.nix;
  hostname = import ../lib/hostname.nix;
  inherit (harness) throws;
  parse = domain.parse;

  # 62 copies of "abc." = 248 chars; plus a 5/6-char final label.
  longPrefix = builtins.concatStringsSep "" (builtins.genList (_: "abc.") 62);
  name253Chars = longPrefix + "abcde"; # 248 + 5
  name254Chars = longPrefix + "abcdef"; # 248 + 6
in
{
  # ===== Parse =====
  testParseSimple = {
    expr = (parse "example.com").value;
    expected = "example.com";
  };
  testParseThreeLabels = {
    expr = (parse "foo.example.com").value;
    expected = "foo.example.com";
  };
  testParseDeep = {
    expr = (parse "a.b.c.d.e.f.example.com").value;
    expected = "a.b.c.d.e.f.example.com";
  };
  testParseTwoSingleChar = {
    expr = (parse "a.b").value;
    expected = "a.b";
  };
  testParseMixedCase = {
    expr = (parse "MyHost.Example.COM").value;
    expected = "MyHost.Example.COM";
  };
  testParseLeadingDigit = {
    expr = (parse "3com.example.com").value;
    expected = "3com.example.com";
  };
  testParseWithHyphen = {
    expr = (parse "my-server.example.com").value;
    expected = "my-server.example.com";
  };
  testParseMaxLength = {
    expr = (parse name253Chars).value;
    expected = name253Chars;
  };
  testParseTagged = {
    expr = (parse "example.com")._type;
    expected = "domain";
  };

  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectSingleLabel = {
    expr = throws (parse "example");
    expected = true;
  };
  testRejectLeadingDot = {
    expr = throws (parse ".example.com");
    expected = true;
  };
  testRejectTrailingDot = {
    expr = throws (parse "example.com.");
    expected = true;
  };
  testRejectConsecutiveDots = {
    expr = throws (parse "a..b");
    expected = true;
  };
  testRejectUnderscore = {
    expr = throws (parse "host_name.com");
    expected = true;
  };
  testRejectLeadingHyphenLabel = {
    expr = throws (parse "-foo.com");
    expected = true;
  };
  testRejectTrailingHyphenLabel = {
    expr = throws (parse "foo-.com");
    expected = true;
  };
  testRejectLongLabel = {
    # 64-char first label
    expr = throws (parse "a123456789-123456789-123456789-123456789-123456789-123456789-xyz.com");
    expected = true;
  };
  testRejectTooLongTotal = {
    expr = throws (parse name254Chars);
    expected = true;
  };
  testRejectWhitespaceLeading = {
    expr = throws (parse " example.com");
    expected = true;
  };
  testRejectWhitespaceMiddle = {
    expr = throws (parse "ex ample.com");
    expected = true;
  };
  testRejectNonAscii = {
    expr = throws (parse "café.com");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (domain.parse 42);
    expected = true;
  };
  testRejectSlash = {
    expr = throws (parse "foo/bar.com");
    expected = true;
  };

  testTryParseOk = {
    expr = (domain.tryParse "example.com").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (domain.tryParse "single").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = builtins.isString (domain.tryParse "single").error;
    expected = true;
  };
  testTryParseNotString = {
    expr = (domain.tryParse 42).success;
    expected = false;
  };

  # ===== fromLabels =====
  testFromLabelsThree = {
    expr =
      (domain.fromLabels [
        "foo"
        "example"
        "com"
      ]).value;
    expected = "foo.example.com";
  };
  testFromLabelsTwo = {
    expr =
      (domain.fromLabels [
        "example"
        "com"
      ]).value;
    expected = "example.com";
  };
  testFromLabelsSingleThrows = {
    expr = throws (domain.fromLabels [ "example" ]);
    expected = true;
  };
  testFromLabelsEmptyThrows = {
    expr = throws (domain.fromLabels [ ]);
    expected = true;
  };
  testFromLabelsBadLabelThrows = {
    expr = throws (
      domain.fromLabels [
        "host_name"
        "com"
      ]
    );
    expected = true;
  };
  testFromLabelsNotListThrows = {
    expr = throws (domain.fromLabels "example.com");
    expected = true;
  };

  # ===== Round-trip =====
  testRoundTripToString = {
    expr = domain.toString (parse "foo.example.com");
    expected = "foo.example.com";
  };
  testRoundTripPreservesCase = {
    expr = domain.toString (parse "Example.COM");
    expected = "Example.COM";
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = domain.is (parse "example.com");
    expected = true;
  };
  testIsString = {
    expr = domain.is "example.com";
    expected = false;
  };
  testIsHostnameValue = {
    expr = domain.is (hostname.parse "nas");
    expected = false;
  };
  testIsValidOk = {
    expr = domain.isValid "example.com";
    expected = true;
  };
  testIsValidBad = {
    expr = domain.isValid "example";
    expected = false;
  };
  testIsValidNotString = {
    expr = domain.isValid 42;
    expected = false;
  };

  # ===== Accessors =====
  testLabelsThree = {
    expr = domain.labels (parse "foo.example.com");
    expected = [
      "foo"
      "example"
      "com"
    ];
  };
  testLabelsTwo = {
    expr = domain.labels (parse "example.com");
    expected = [
      "example"
      "com"
    ];
  };
  testLabelCountThree = {
    expr = domain.labelCount (parse "foo.example.com");
    expected = 3;
  };
  testLabelCountTwo = {
    expr = domain.labelCount (parse "example.com");
    expected = 2;
  };

  # ===== parent =====
  testParentThree = {
    expr = (domain.parent (parse "foo.example.com")).value;
    expected = "example.com";
  };
  testParentDeep = {
    expr = (domain.parent (parse "a.b.c.example.com")).value;
    expected = "b.c.example.com";
  };
  testParentTwoIsNull = {
    expr = domain.parent (parse "example.com");
    expected = null;
  };
  testParentPreservesTag = {
    expr = (domain.parent (parse "foo.example.com"))._type;
    expected = "domain";
  };

  # ===== isSubdomainOf =====
  testSubdomainDirect = {
    expr = domain.isSubdomainOf (parse "foo.example.com") (parse "example.com");
    expected = true;
  };
  testSubdomainDeep = {
    expr = domain.isSubdomainOf (parse "a.b.c.example.com") (parse "example.com");
    expected = true;
  };
  testSubdomainSelf = {
    expr = domain.isSubdomainOf (parse "example.com") (parse "example.com");
    expected = true;
  };
  testSubdomainNotSuffix = {
    expr = domain.isSubdomainOf (parse "evil.foo.com") (parse "example.com");
    expected = false;
  };
  testSubdomainShorter = {
    expr = domain.isSubdomainOf (parse "example.com") (parse "foo.example.com");
    expected = false;
  };
  testSubdomainDifferentTld = {
    expr = domain.isSubdomainOf (parse "foo.example.org") (parse "example.com");
    expected = false;
  };
  testSubdomainCaseInsensitive = {
    expr = domain.isSubdomainOf (parse "Foo.Example.COM") (parse "EXAMPLE.com");
    expected = true;
  };
  # "example.com.foo" is NOT a subdomain of "example.com" — the suffix
  # has to align at the trailing edge.
  testSubdomainNotPrefixMatch = {
    expr = domain.isSubdomainOf (parse "example.com.foo") (parse "example.com");
    expected = false;
  };

  # ===== toHostname =====
  testToHostnameExtractsLeftmost = {
    expr = (domain.toHostname (parse "foo.example.com")).value;
    expected = "foo";
  };
  testToHostnameTwoLabels = {
    expr = (domain.toHostname (parse "example.com")).value;
    expected = "example";
  };
  testToHostnameTaggedAsHostname = {
    expr = (domain.toHostname (parse "foo.example.com"))._type;
    expected = "hostname";
  };
  testToHostnamePreservesCase = {
    expr = (domain.toHostname (parse "Foo.example.com")).value;
    expected = "Foo";
  };

  # ===== Normalize =====
  testNormalizeUpper = {
    expr = (domain.normalize (parse "FOO.EXAMPLE.COM")).value;
    expected = "foo.example.com";
  };
  testNormalizeAlreadyLower = {
    expr = (domain.normalize (parse "foo.example.com")).value;
    expected = "foo.example.com";
  };
  testNormalizeMixed = {
    expr = (domain.normalize (parse "MyHost.Example.com")).value;
    expected = "myhost.example.com";
  };
  testNormalizePreservesTag = {
    expr = domain.is (domain.normalize (parse "FOO.EXAMPLE.COM"));
    expected = true;
  };

  # ===== Equality (case-insensitive) =====
  testEqSame = {
    expr = domain.eq (parse "example.com") (parse "example.com");
    expected = true;
  };
  testEqCaseUpper = {
    expr = domain.eq (parse "EXAMPLE.COM") (parse "example.com");
    expected = true;
  };
  testEqCaseMixed = {
    expr = domain.eq (parse "MyHost.example.COM") (parse "myhost.EXAMPLE.com");
    expected = true;
  };
  testEqDifferent = {
    expr = domain.eq (parse "example.com") (parse "example.org");
    expected = false;
  };

  # ===== Comparison (case-insensitive) =====
  testGtYes = {
    expr = domain.gt (parse "beta.com") (parse "alpha.com");
    expected = true;
  };
  testLtYes = {
    expr = domain.lt (parse "alpha.com") (parse "beta.com");
    expected = true;
  };
  testLtNo = {
    expr = domain.lt (parse "beta.com") (parse "alpha.com");
    expected = false;
  };
  testLtCaseInsensitive = {
    expr = domain.lt (parse "Alpha.com") (parse "beta.com");
    expected = true;
  };
  testCompareLt = {
    expr = domain.compare (parse "alpha.com") (parse "beta.com");
    expected = -1;
  };
  testCompareEqCase = {
    expr = domain.compare (parse "EXAMPLE.COM") (parse "example.com");
    expected = 0;
  };
  testCompareGt = {
    expr = domain.compare (parse "z.com") (parse "a.com");
    expected = 1;
  };
  testLeEqual = {
    expr = domain.le (parse "example.com") (parse "example.com");
    expected = true;
  };
  testGeEqual = {
    expr = domain.ge (parse "example.com") (parse "example.com");
    expected = true;
  };
  testMinPick = {
    expr = (domain.min (parse "beta.com") (parse "alpha.com")).value;
    expected = "alpha.com";
  };
  testMaxPick = {
    expr = (domain.max (parse "beta.com") (parse "alpha.com")).value;
    expected = "beta.com";
  };
}
