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
in
{
  inherit
    hex
    hex1
    hex2
    hex4
    longestZeroRun
    ;
}
