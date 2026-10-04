{ harness }:
let
  parsing = import ../../lib/internal/parse.nix;
in
{
  # ===== decimal =====
  testDecimal0 = {
    expr = parsing.decimal "0";
    expected = 0;
  };
  testDecimal42 = {
    expr = parsing.decimal "42";
    expected = 42;
  };
  testDecimal255 = {
    expr = parsing.decimal "255";
    expected = 255;
  };
  testDecimalLeadingZero = {
    expr = parsing.decimal "007";
    expected = 7;
  };
  testDecimalEmpty = {
    expr = parsing.decimal "";
    expected = null;
  };
  testDecimalAlpha = {
    expr = parsing.decimal "a";
    expected = null;
  };
  testDecimalMixed = {
    expr = parsing.decimal "12a";
    expected = null;
  };
  testDecimalNegative = {
    expr = parsing.decimal "-1";
    expected = null;
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

  # ===== stripSuffix =====
  testStripSuffixSimple = {
    expr = parsing.stripSuffix "ef" "abcdef";
    expected = "abcd";
  };
  testStripSuffixWhole = {
    expr = parsing.stripSuffix "abc" "abc";
    expected = "";
  };
  testStripSuffixEmpty = {
    expr = parsing.stripSuffix "" "abc";
    expected = "abc";
  };
}
