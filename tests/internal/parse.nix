{ harness }:
let
  parse = import ../../lib/internal/parse.nix;
in
{
  # ===== decimal =====
  decimal-0 = {
    expr = parse.decimal "0";
    expected = 0;
  };
  decimal-42 = {
    expr = parse.decimal "42";
    expected = 42;
  };
  decimal-255 = {
    expr = parse.decimal "255";
    expected = 255;
  };
  decimal-leading-zero = {
    expr = parse.decimal "007";
    expected = 7;
  };
  decimal-empty = {
    expr = parse.decimal "";
    expected = null;
  };
  decimal-alpha = {
    expr = parse.decimal "a";
    expected = null;
  };
  decimal-mixed = {
    expr = parse.decimal "12a";
    expected = null;
  };
  decimal-neg = {
    expr = parse.decimal "-1";
    expected = null;
  };

  # ===== hexInt =====
  hexInt-0 = {
    expr = parse.hexInt "0";
    expected = 0;
  };
  hexInt-ff = {
    expr = parse.hexInt "ff";
    expected = 255;
  };
  hexInt-upper = {
    expr = parse.hexInt "FF";
    expected = 255;
  };
  hexInt-mixed = {
    expr = parse.hexInt "1aB2";
    expected = 6834;
  };
  hexInt-empty = {
    expr = parse.hexInt "";
    expected = null;
  };
  hexInt-non-hex = {
    expr = parse.hexInt "g";
    expected = null;
  };
  hexInt-prefix = {
    expr = parse.hexInt "0x1";
    expected = null;
  };

  # ===== octet =====
  octet-0 = {
    expr = parse.octet "0";
    expected = 0;
  };
  octet-255 = {
    expr = parse.octet "255";
    expected = 255;
  };
  octet-empty = {
    expr = parse.octet "";
    expected = null;
  };
  octet-256 = {
    expr = parse.octet "256";
    expected = null;
  };
  octet-4-digits = {
    expr = parse.octet "1234";
    expected = null;
  };
  octet-leading-zero = {
    expr = parse.octet "01";
    expected = null;
  };
  octet-double-zero = {
    expr = parse.octet "00";
    expected = null;
  };
  octet-non-digit = {
    expr = parse.octet "1a";
    expected = null;
  };

  # ===== hexGroup =====
  hexGroup-0 = {
    expr = parse.hexGroup "0";
    expected = 0;
  };
  hexGroup-max = {
    expr = parse.hexGroup "ffff";
    expected = 65535;
  };
  hexGroup-empty = {
    expr = parse.hexGroup "";
    expected = null;
  };
  hexGroup-5-chars = {
    expr = parse.hexGroup "10000";
    expected = null;
  };
  hexGroup-non-hex = {
    expr = parse.hexGroup "zz";
    expected = null;
  };

  # ===== hexByte =====
  hexByte-00 = {
    expr = parse.hexByte "00";
    expected = 0;
  };
  hexByte-ff = {
    expr = parse.hexByte "ff";
    expected = 255;
  };
  hexByte-1-char = {
    expr = parse.hexByte "f";
    expected = null;
  };
  hexByte-3-chars = {
    expr = parse.hexByte "fff";
    expected = null;
  };
  hexByte-empty = {
    expr = parse.hexByte "";
    expected = null;
  };
  hexByte-non-hex = {
    expr = parse.hexByte "zz";
    expected = null;
  };

  # ===== splitOn =====
  splitOn-simple = {
    expr = parse.splitOn "," "a,b,c";
    expected = [
      "a"
      "b"
      "c"
    ];
  };
  splitOn-no-delim = {
    expr = parse.splitOn "," "abc";
    expected = [ "abc" ];
  };
  splitOn-trailing = {
    expr = parse.splitOn "," "a,b,";
    expected = [
      "a"
      "b"
      ""
    ];
  };
  splitOn-leading = {
    expr = parse.splitOn "," ",a";
    expected = [
      ""
      "a"
    ];
  };
  splitOn-consecutive = {
    expr = parse.splitOn "," ",,a";
    expected = [
      ""
      ""
      "a"
    ];
  };
  splitOn-multi-char = {
    expr = parse.splitOn "::" "a::b::c";
    expected = [
      "a"
      "b"
      "c"
    ];
  };
  splitOn-empty-string = {
    expr = parse.splitOn "," "";
    expected = [ "" ];
  };
  splitOn-empty-delim = {
    expr = parse.splitOn "" "abc";
    expected = [ "abc" ];
  };

  # ===== countOccurrences =====
  count-zero = {
    expr = parse.countOccurrences "," "abc";
    expected = 0;
  };
  count-one = {
    expr = parse.countOccurrences "," "a,b";
    expected = 1;
  };
  count-many = {
    expr = parse.countOccurrences "," "a,b,c,d";
    expected = 3;
  };
  count-multi-char = {
    expr = parse.countOccurrences "::" "a::b::c";
    expected = 2;
  };
  count-empty-string = {
    expr = parse.countOccurrences "," "";
    expected = 0;
  };

  # ===== startsWith =====
  startsWith-yes = {
    expr = parse.startsWith "ab" "abcdef";
    expected = true;
  };
  startsWith-no = {
    expr = parse.startsWith "ac" "abcdef";
    expected = false;
  };
  startsWith-whole = {
    expr = parse.startsWith "abc" "abc";
    expected = true;
  };
  startsWith-longer-prefix = {
    expr = parse.startsWith "abcd" "abc";
    expected = false;
  };
  startsWith-empty-prefix = {
    expr = parse.startsWith "" "abc";
    expected = true;
  };
  startsWith-empty-both = {
    expr = parse.startsWith "" "";
    expected = true;
  };

  # ===== endsWith =====
  endsWith-yes = {
    expr = parse.endsWith "ef" "abcdef";
    expected = true;
  };
  endsWith-no = {
    expr = parse.endsWith "eg" "abcdef";
    expected = false;
  };
  endsWith-whole = {
    expr = parse.endsWith "abc" "abc";
    expected = true;
  };
  endsWith-longer-suffix = {
    expr = parse.endsWith "abcd" "bcd";
    expected = false;
  };
  endsWith-empty-suffix = {
    expr = parse.endsWith "" "abc";
    expected = true;
  };
  endsWith-empty-both = {
    expr = parse.endsWith "" "";
    expected = true;
  };

  # ===== stripPrefix =====
  stripPrefix-simple = {
    expr = parse.stripPrefix "ab" "abcdef";
    expected = "cdef";
  };
  stripPrefix-whole = {
    expr = parse.stripPrefix "abc" "abc";
    expected = "";
  };
  stripPrefix-empty = {
    expr = parse.stripPrefix "" "abc";
    expected = "abc";
  };

  # ===== stripSuffix =====
  stripSuffix-simple = {
    expr = parse.stripSuffix "ef" "abcdef";
    expected = "abcd";
  };
  stripSuffix-whole = {
    expr = parse.stripSuffix "abc" "abc";
    expected = "";
  };
  stripSuffix-empty = {
    expr = parse.stripSuffix "" "abc";
    expected = "abc";
  };
}
