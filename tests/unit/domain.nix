{ helpers, libnet, ... }:
let
  inherit (libnet) domain hostname;
  inherit (helpers) throws;
  inherit (domain) parse;

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
  testParseFoldsCase = {
    expr = (parse "MyHost.Example.COM").value;
    expected = "myhost.example.com";
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
    expr = domain.parse 42;
    expectedError.msg = "^libnet\\.domain\\.parse: expected string, got int$";
  };
  testRejectSingleLabelNamesParse = {
    expr = parse "single";
    expectedError.msg = "^libnet\\.domain\\.parse: needs at least 2 labels";
  };
  testRejectSlash = {
    expr = throws (parse "foo/bar.com");
    expected = true;
  };

  # ===== Numeric rightmost label (ADR 0021) =====
  testRejectDottedQuad = {
    expr = parse "192.0.2.1";
    expectedError.msg = "^libnet\\.domain\\.parse: \"192\\.0\\.2\\.1\" reads as an IPv4 address \\(numeric rightmost label\\)$";
  };
  testRejectHexRightmostLabel = {
    expr = parse "127.1.0x1";
    expectedError.msg = "^libnet\\.domain\\.parse: \"127\\.1\\.0x1\" reads as an IPv4 address";
  };
  testRejectNumericRightmostLabels = {
    expr = map domain.isValid [
      "example.1"
      "127.1"
      "010.0.0.1"
      "192.0.2.300"
      "example.0x"
      "example.0X7F"
      "example.0xdeadBEEF"
    ];
    expected = [
      false
      false
      false
      false
      false
      false
      false
    ];
  };
  # Only the rightmost label counts, and only digits or `0x` hex.
  testAcceptNonNumericRightmostLabel = {
    expr = map domain.isValid [
      "192.0.2.example"
      "example.1a"
      "example.0x7g"
      "example.x7f"
      "example.00x1"
    ];
    expected = [
      true
      true
      true
      true
      true
    ];
  };
  testFromLabelsRejectsNumericRightmostLabel = {
    expr = domain.fromLabels [
      "a"
      "1"
    ];
    expectedError.msg = "^libnet\\.domain\\.fromLabels: \"a\\.1\" reads as an IPv4 address";
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
  testFromLabelsFoldsCase = {
    expr = domain.toString (
      domain.fromLabels [
        "WWW"
        "Example"
        "com"
      ]
    );
    expected = "www.example.com";
  };
  testFromLabelsBadLabelNamesFromLabels = {
    expr = domain.fromLabels [
      "host_name"
      "com"
    ];
    expectedError.msg = "^libnet\\.domain\\.fromLabels: invalid label in \"host_name\\.com\"";
  };
  testFromLabelsNotListThrows = {
    expr = domain.fromLabels "example.com";
    expectedError.msg = "^libnet\\.domain\\.fromLabels: expected list, got string$";
  };
  testFromLabelsNonStringLabelThrows = {
    expr = domain.fromLabels [
      "example"
      { }
    ];
    expectedError.msg = "^libnet\\.domain\\.fromLabels: expected list of strings, got set at index 1$";
  };

  # ===== Round-trip =====
  testRoundTripToString = {
    expr = domain.toString (parse "foo.example.com");
    expected = "foo.example.com";
  };
  testToStringLowercase = {
    expr = domain.toString (parse "Example.COM");
    expected = "example.com";
  };
  testToStringRejectsHostname = {
    expr = domain.toString (hostname.parse "nas");
    expectedError.msg = "^libnet\\.domain\\.toString: expected domain value, got hostname value$";
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
  testLabelsLowercase = {
    expr = domain.labels (parse "Example.COM");
    expected = [
      "example"
      "com"
    ];
  };
  testLabelsRejectsString = {
    expr = domain.labels "example.com";
    expectedError.msg = "^libnet\\.domain\\.labels: expected domain value, got string$";
  };
  testLabelsTwo = {
    expr = domain.labels (parse "example.com");
    expected = [
      "example"
      "com"
    ];
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
  testParentRejectsString = {
    expr = domain.parent "foo.example.com";
    expectedError.msg = "^libnet\\.domain\\.parent: expected domain value, got string$";
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
  testSubdomainRejectsString = {
    expr = domain.isSubdomainOf (parse "foo.example.com") "example.com";
    expectedError.msg = "^libnet\\.domain\\.isSubdomainOf: expected domain value, got string$";
  };
  testSubdomainMixedCaseSpellings = {
    expr = domain.isSubdomainOf (parse "Foo.Example.COM") (parse "EXAMPLE.com");
    expected = true;
  };
  # "example.com.foo" is NOT a subdomain of "example.com" — the suffix
  # has to align at the trailing edge.
  testSubdomainNotPrefixMatch = {
    expr = domain.isSubdomainOf (parse "example.com.foo") (parse "example.com");
    expected = false;
  };

  # ===== isSuperdomainOf =====
  testSuperdomainDirect = {
    expr = domain.isSuperdomainOf (parse "example.com") (parse "foo.example.com");
    expected = true;
  };
  testSuperdomainSelf = {
    expr = domain.isSuperdomainOf (parse "example.com") (parse "example.com");
    expected = true;
  };
  testSuperdomainLonger = {
    expr = domain.isSuperdomainOf (parse "foo.example.com") (parse "example.com");
    expected = false;
  };
  testSuperdomainNotSuffix = {
    expr = domain.isSuperdomainOf (parse "example.com") (parse "evil.foo.com");
    expected = false;
  };
  testSuperdomainNamesItself = {
    expr = domain.isSuperdomainOf "example.com" (parse "foo.example.com");
    expectedError.msg = "^libnet\\.domain\\.isSuperdomainOf: expected domain value, got string$";
  };
  testSuperdomainMixedCaseSpellings = {
    expr = domain.isSuperdomainOf (parse "EXAMPLE.com") (parse "Foo.Example.COM");
    expected = true;
  };
  # Partially applied, it keeps the names inside the zone.
  testSuperdomainPartial = {
    expr = map domain.toString (
      builtins.filter (domain.isSuperdomainOf (parse "example.com")) (
        map parse [
          "www.example.com"
          "example.org"
          "example.com"
        ]
      )
    );
    expected = [
      "www.example.com"
      "example.com"
    ];
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
  testToHostnameLowercase = {
    expr = (domain.toHostname (parse "Foo.example.com")).value;
    expected = "foo";
  };
  testToHostnameRejectsHostname = {
    expr = domain.toHostname (hostname.parse "foo");
    expectedError.msg = "^libnet\\.domain\\.toHostname: expected domain value, got hostname value$";
  };

  testNoNormalize = {
    expr = domain ? normalize;
    expected = false;
  };

  # ===== Equality (structural on the folded text) =====
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

  # ===== Comparison =====
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
  testLtFoldedCase = {
    expr = domain.lt (parse "alpha.com") (parse "Beta.com");
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
  testGeNamesItself = {
    expr = domain.ge (parse "example.com") (hostname.parse "example");
    expectedError.msg = "^libnet\\.domain\\.ge: expected domain value, got hostname value$";
  };
}
