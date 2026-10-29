let
  bits = import ./bits.nix;

  hexDigits = [
    "0"
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "a"
    "b"
    "c"
    "d"
    "e"
    "f"
  ];

  # Lowercase hex renderers: `hex1` renders one digit, `hex2` and `hex4`
  # zero-pad to two and four digits, and `hex` uses no padding.
  hex1 = n: builtins.elemAt hexDigits n;

  hex2 = n: (hex1 (bits.shr 4 n)) + (hex1 (builtins.bitAnd n 15));

  hex4 =
    n:
    (hex1 (builtins.bitAnd (bits.shr 12 n) 15))
    + (hex1 (builtins.bitAnd (bits.shr 8 n) 15))
    + (hex1 (builtins.bitAnd (bits.shr 4 n) 15))
    + (hex1 (builtins.bitAnd n 15));

  hex =
    n:
    if n == 0 then
      "0"
    else
      let
        go =
          remaining: digits:
          if remaining == 0 then
            digits
          else
            go (bits.shr 4 remaining) ((hex1 (builtins.bitAnd remaining 15)) + digits);
      in
      go n "";

  # Longest run of at least two consecutive zeros in a list of ints, for
  # IPv6 `::` compression. Returns { start; len; }, with start = -1 and
  # len = 0 when no run qualifies; ties keep the first run.
  longestZeroRun =
    groups:
    let
      count = builtins.length groups;
      scan =
        i: bestStart: bestLength: currentStart: currentLength:
        if i == count then
          if bestLength >= 2 then
            {
              start = bestStart;
              len = bestLength;
            }
          else
            {
              start = -1;
              len = 0;
            }
        else if builtins.elemAt groups i == 0 then
          let
            runLength = currentLength + 1;
            runStart = if currentLength == 0 then i else currentStart;
          in
          if runLength > bestLength then
            scan (i + 1) runStart runLength runStart runLength
          else
            scan (i + 1) bestStart bestLength runStart runLength
        else
          scan (i + 1) bestStart bestLength (-1) 0;
    in
    scan 0 (-1) 0 (-1) 0;

  # The dotted-quad text of an IPv4 address held as one u32.
  ipv4 =
    value:
    builtins.concatStringsSep "." (
      map (shift: builtins.toString (bits.bits shift 8 value)) [
        24
        16
        8
        0
      ]
    );

  /*
    The RFC 5952 canonical text of an IPv6 address held as four u32
    words, most significant first: lowercase, leading zeros dropped, the
    longest run of zero groups compressed to `::`, and IPv4-mapped
    addresses in the mixed form `::ffff:a.b.c.d` (section 5).
  */
  ipv6 =
    words:
    let
      wordAt = builtins.elemAt words;
    in
    if wordAt 0 == 0 && wordAt 1 == 0 && wordAt 2 == 65535 then
      "::ffff:${ipv4 (wordAt 3)}"
    else
      let
        groups = builtins.concatMap (word: [
          (bits.shr 16 word)
          (builtins.bitAnd word bits.mask16)
        ]) words;
        zeroRun = longestZeroRun groups;
        groupTexts = map hex groups;
      in
      if zeroRun.len == 0 then
        builtins.concatStringsSep ":" groupTexts
      else
        let
          prefix = builtins.genList (i: builtins.elemAt groupTexts i) zeroRun.start;
          suffix = builtins.genList (i: builtins.elemAt groupTexts (zeroRun.start + zeroRun.len + i)) (
            8 - zeroRun.start - zeroRun.len
          );
          prefixText = builtins.concatStringsSep ":" prefix;
          suffixText = builtins.concatStringsSep ":" suffix;
        in
        "${prefixText}::${suffixText}";
in
{
  inherit
    hex
    hex1
    hex2
    hex4
    ipv4
    ipv6
    longestZeroRun
    ;
}
