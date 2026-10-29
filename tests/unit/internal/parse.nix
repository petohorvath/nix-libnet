{
  helpers,
  internal,
  libnet,
  ...
}:
let
  parsing = internal.parse;
  inherit (helpers) throws;
  inherit (internal) types;

  # A kind `digit` whose detail parser reads one decimal digit and
  # describes other text without a prefix.
  digit = parsing.suite "digit" (
    input:
    let
      value = parsing.decimal 9 input;
    in
    if value == null then types.tryErr "not a digit: \"${input}\"" else types.tryOk value
  );
in
{
  # ===== suite =====
  testSuiteTryParseSucceeds = {
    expr = digit.tryParse "7";
    expected = {
      success = true;
      value = 7;
      error = null;
    };
  };
  # The suite adds the prefix once, naming `parse`.
  testSuiteTryParseNamesParse = {
    expr = digit.tryParse "x";
    expected = {
      success = false;
      value = null;
      error = "libnet.digit.parse: not a digit: \"x\"";
    };
  };
  # A non-string never reaches the detail parser.
  testSuiteTryParseNonString = {
    expr = map (input: (digit.tryParse input).error) [
      7
      { _type = "digit"; }
    ];
    expected = [
      "libnet.digit.parse: expected string, got int"
      "libnet.digit.parse: expected string, got digit value"
    ];
  };
  testSuiteParse = {
    expr = map digit.parse [
      "0"
      "9"
    ];
    expected = [
      0
      9
    ];
  };
  testSuiteParseThrows = {
    expr = digit.parse "10";
    expectedError.msg = "^libnet\\.digit\\.parse: not a digit: \"10\"$";
  };
  testSuiteParseNonStringThrows = {
    expr = digit.parse null;
    expectedError.msg = "^libnet\\.digit\\.parse: expected string, got null$";
  };
  # Namespaces share their detail parsers with each other, not with users.
  testSuiteDetailIsNotPublic = {
    expr = builtins.filter (name: builtins.isAttrs libnet.${name} && libnet.${name} ? tryParseDetail) (
      builtins.attrNames libnet
    );
    expected = [ ];
  };
  testSuiteIsValid = {
    expr = map digit.isValid [
      "3"
      "x"
      ""
      3
      null
    ];
    expected = [
      true
      false
      false
      false
      false
    ];
  };

  # ===== isDecimal =====
  testIsDecimalAccepts = {
    expr = map parsing.isDecimal [
      "0"
      "7"
      "65535"
    ];
    expected = [
      true
      true
      true
    ];
  };
  testIsDecimalRejects = {
    expr = map parsing.isDecimal [
      ""
      "00"
      "07"
      "-1"
      "+1"
      " 1"
      "1a"
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

  # ===== isRepetitionOf =====
  testIsRepetitionOfAccepts = {
    expr = map (parsing.isRepetitionOf "[a-z]|%[0-9]") [
      "a"
      "abc"
      "%1"
      "a%1b%2"
    ];
    expected = [
      true
      true
      true
      true
    ];
  };
  testIsRepetitionOfRejects = {
    expr = map (parsing.isRepetitionOf "[a-z]|%[0-9]") [
      ""
      "A"
      "%"
      "a%"
      "%x"
      "ab1"
    ];
    expected = [
      false
      false
      false
      false
      false
      false
    ];
  };
  # A repetition in builtins.match would exhaust the stack.
  testIsRepetitionOfLongInput = {
    expr = parsing.isRepetitionOf "[0-9]" (
      builtins.concatStringsSep "" (builtins.genList (_: "1") 100000)
    );
    expected = true;
  };

  # ===== hasLeadingZero =====
  testHasLeadingZeroAccepts = {
    expr = map parsing.hasLeadingZero [
      "00"
      "08"
      "0080"
    ];
    expected = [
      true
      true
      true
    ];
  };
  testHasLeadingZeroRejects = {
    expr = map parsing.hasLeadingZero [
      ""
      "0"
      "80"
      "0x"
      "-08"
    ];
    expected = [
      false
      false
      false
      false
      false
    ];
  };

  # ===== isDottedDigits =====
  testIsDottedDigitsAccepts = {
    expr = map parsing.isDottedDigits [
      "1"
      "10.0.0.1"
      "1."
    ];
    expected = [
      true
      true
      true
    ];
  };
  testIsDottedDigitsRejects = {
    expr = map parsing.isDottedDigits [
      ""
      "a.1"
      "1:2"
    ];
    expected = [
      false
      false
      false
    ];
  };

  # ===== decimal =====
  testDecimal0 = {
    expr = parsing.decimal 255 "0";
    expected = 0;
  };
  testDecimal42 = {
    expr = parsing.decimal 255 "42";
    expected = 42;
  };
  testDecimalAtMaximum = {
    expr = parsing.decimal 255 "255";
    expected = 255;
  };
  testDecimalAboveMaximum = {
    expr = parsing.decimal 255 "256";
    expected = null;
  };
  testDecimalMoreDigitsThanMaximum = {
    expr = parsing.decimal 255 "1000";
    expected = null;
  };
  testDecimalOverflowingDigits = {
    expr = parsing.decimal 65535 "99999999999999999999";
    expected = null;
  };
  testDecimalWrappingDigits = {
    # 2^64 + 80, which wraps to 80 where integer overflow is silent.
    expr = parsing.decimal 65535 "18446744073709551696";
    expected = null;
  };
  testDecimalLeadingZero = {
    expr = parsing.decimal 255 "007";
    expected = null;
  };
  testDecimalDoubleZero = {
    expr = parsing.decimal 255 "00";
    expected = null;
  };
  testDecimalEmpty = {
    expr = parsing.decimal 255 "";
    expected = null;
  };
  testDecimalAlpha = {
    expr = parsing.decimal 255 "a";
    expected = null;
  };
  testDecimalMixed = {
    expr = parsing.decimal 255 "12a";
    expected = null;
  };
  testDecimalNegative = {
    expr = parsing.decimal 255 "-1";
    expected = null;
  };
  testDecimalBelowOverflowLimit = {
    expr = parsing.decimal 999999999999999999 "999999999999999999";
    expected = 999999999999999999;
  };
  testDecimalMaximumAtOverflowLimitThrows = {
    expr = throws (parsing.decimal 1000000000000000000 "1");
    expected = true;
  };
  testDecimalPartialApplication = {
    expr = map (parsing.decimal 9) [
      "9"
      "10"
    ];
    expected = [
      9
      null
    ];
  };

  # ===== hexInt =====
  testHexInt0 = {
    expr = parsing.hexInt "0";
    expected = 0;
  };
  testHexIntFf = {
    expr = parsing.hexInt "ff";
    expected = 255;
  };
  testHexIntUpper = {
    expr = parsing.hexInt "FF";
    expected = 255;
  };
  testHexIntMixed = {
    expr = parsing.hexInt "1aB2";
    expected = 6834;
  };
  testHexIntEmpty = {
    expr = parsing.hexInt "";
    expected = null;
  };
  testHexIntNonHex = {
    expr = parsing.hexInt "g";
    expected = null;
  };
  testHexIntPrefix = {
    expr = parsing.hexInt "0x1";
    expected = null;
  };

  # ===== octet =====
  testOctet0 = {
    expr = parsing.octet "0";
    expected = 0;
  };
  testOctet255 = {
    expr = parsing.octet "255";
    expected = 255;
  };
  testOctetEmpty = {
    expr = parsing.octet "";
    expected = null;
  };
  testOctet256 = {
    expr = parsing.octet "256";
    expected = null;
  };
  testOctet4Digits = {
    expr = parsing.octet "1234";
    expected = null;
  };
  testOctetLeadingZero = {
    expr = parsing.octet "01";
    expected = null;
  };
  testOctetDoubleZero = {
    expr = parsing.octet "00";
    expected = null;
  };
  testOctetNonDigit = {
    expr = parsing.octet "1a";
    expected = null;
  };

  # ===== hexGroup =====
  testHexGroup0 = {
    expr = parsing.hexGroup "0";
    expected = 0;
  };
  testHexGroupMax = {
    expr = parsing.hexGroup "ffff";
    expected = 65535;
  };
  testHexGroupEmpty = {
    expr = parsing.hexGroup "";
    expected = null;
  };
  testHexGroupFiveCharacters = {
    expr = parsing.hexGroup "10000";
    expected = null;
  };
  testHexGroupNonHex = {
    expr = parsing.hexGroup "zz";
    expected = null;
  };

  # ===== hexByte =====
  testHexByte00 = {
    expr = parsing.hexByte "00";
    expected = 0;
  };
  testHexByteFf = {
    expr = parsing.hexByte "ff";
    expected = 255;
  };
  testHexByteOneCharacter = {
    expr = parsing.hexByte "f";
    expected = null;
  };
  testHexByteThreeCharacters = {
    expr = parsing.hexByte "fff";
    expected = null;
  };
  testHexByteEmpty = {
    expr = parsing.hexByte "";
    expected = null;
  };
  testHexByteNonHex = {
    expr = parsing.hexByte "zz";
    expected = null;
  };

  # ===== splitOn =====
  testSplitOnSimple = {
    expr = parsing.splitOn "," "a,b,c";
    expected = [
      "a"
      "b"
      "c"
    ];
  };
  testSplitOnNoDelimiter = {
    expr = parsing.splitOn "," "abc";
    expected = [ "abc" ];
  };
  testSplitOnTrailing = {
    expr = parsing.splitOn "," "a,b,";
    expected = [
      "a"
      "b"
      ""
    ];
  };
  testSplitOnLeading = {
    expr = parsing.splitOn "," ",a";
    expected = [
      ""
      "a"
    ];
  };
  testSplitOnConsecutive = {
    expr = parsing.splitOn "," ",,a";
    expected = [
      ""
      ""
      "a"
    ];
  };
  testSplitOnMultiChar = {
    expr = parsing.splitOn "::" "a::b::c";
    expected = [
      "a"
      "b"
      "c"
    ];
  };
  testSplitOnEmptyString = {
    expr = parsing.splitOn "," "";
    expected = [ "" ];
  };
  testSplitOnEmptyDelimiter = {
    expr = parsing.splitOn "" "abc";
    expected = [ "abc" ];
  };
  testSplitOnRepeatedMultiChar = {
    expr = parsing.splitOn "::" "a:::b::::c";
    expected = [
      "a"
      ":b"
      ""
      "c"
    ];
  };
  # The delimiter is literal text, not a regular expression.
  testSplitOnRegexSpecialDelimiters = {
    expr = map (delimiter: parsing.splitOn delimiter "a${delimiter}b") [
      "."
      "]"
      "]:"
      "["
      "("
      ")"
      "{"
      "}"
      "*"
      "+"
      "?"
      "|"
      "^"
      "$"
      "\\"
      "%"
      "://"
    ];
    expected = builtins.genList (_: [
      "a"
      "b"
    ]) 17;
  };
  testSplitOnDotIsNotAWildcard = {
    expr = parsing.splitOn "." "abc";
    expected = [ "abc" ];
  };
  # Recursing once per character would exceed the maximum call depth.
  testSplitOnLongInput =
    let
      parts = parsing.splitOn "." (builtins.concatStringsSep "." (builtins.genList (_: "a") 20000));
    in
    {
      expr = {
        length = builtins.length parts;
        allA = builtins.all (part: part == "a") parts;
      };
      expected = {
        length = 20000;
        allA = true;
      };
    };

  # ===== countOccurrences =====
  testCountZero = {
    expr = parsing.countOccurrences "," "abc";
    expected = 0;
  };
  testCountOne = {
    expr = parsing.countOccurrences "," "a,b";
    expected = 1;
  };
  testCountMany = {
    expr = parsing.countOccurrences "," "a,b,c,d";
    expected = 3;
  };
  testCountMultiChar = {
    expr = parsing.countOccurrences "::" "a::b::c";
    expected = 2;
  };
  testCountEmptyString = {
    expr = parsing.countOccurrences "," "";
    expected = 0;
  };

  # ===== startsWith =====
  testStartsWithYes = {
    expr = parsing.startsWith "ab" "abcdef";
    expected = true;
  };
  testStartsWithNo = {
    expr = parsing.startsWith "ac" "abcdef";
    expected = false;
  };
  testStartsWithWhole = {
    expr = parsing.startsWith "abc" "abc";
    expected = true;
  };
  testStartsWithLongerPrefix = {
    expr = parsing.startsWith "abcd" "abc";
    expected = false;
  };
  testStartsWithEmptyPrefix = {
    expr = parsing.startsWith "" "abc";
    expected = true;
  };
  testStartsWithEmptyBoth = {
    expr = parsing.startsWith "" "";
    expected = true;
  };

  # ===== endsWith =====
  testEndsWithYes = {
    expr = parsing.endsWith "ef" "abcdef";
    expected = true;
  };
  testEndsWithNo = {
    expr = parsing.endsWith "eg" "abcdef";
    expected = false;
  };
  testEndsWithWhole = {
    expr = parsing.endsWith "abc" "abc";
    expected = true;
  };
  testEndsWithLongerSuffix = {
    expr = parsing.endsWith "abcd" "bcd";
    expected = false;
  };
  testEndsWithEmptySuffix = {
    expr = parsing.endsWith "" "abc";
    expected = true;
  };
  testEndsWithEmptyBoth = {
    expr = parsing.endsWith "" "";
    expected = true;
  };

  # ===== splitScheme =====
  testSplitSchemeKeepsCase = {
    expr = parsing.splitScheme "TCP://192.0.2.1:80";
    expected = {
      scheme = "TCP";
      rest = "192.0.2.1:80";
    };
  };
  # Only the first separator splits, so a later one stays in the rest.
  testSplitSchemeKeepsLaterSeparators = {
    expr = parsing.splitScheme "unix:///run/a://b";
    expected = {
      scheme = "unix";
      rest = "/run/a://b";
    };
  };
  testSplitSchemeEmptyParts = {
    expr = parsing.splitScheme "://";
    expected = {
      scheme = "";
      rest = "";
    };
  };
  testSplitSchemeMissingSeparator = {
    expr = map parsing.splitScheme [
      ""
      "tcp:/x"
      "tcp:x"
    ];
    expected = [
      null
      null
      null
    ];
  };

  # ===== stripPrefix =====
  testStripPrefixSimple = {
    expr = parsing.stripPrefix "ab" "abcdef";
    expected = "cdef";
  };
  testStripPrefixWhole = {
    expr = parsing.stripPrefix "abc" "abc";
    expected = "";
  };
  testStripPrefixEmpty = {
    expr = parsing.stripPrefix "" "abc";
    expected = "abc";
  };
}
