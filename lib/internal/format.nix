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
        go = v: acc: if v == 0 then acc else go (bits.shr 4 v) ((hex1 (builtins.bitAnd v 15)) + acc);
      in
      go n "";

  # Longest run of consecutive zeros of length >= 2 in a list of ints.
  # Returns { start; len; }; len == 0 if no qualifying run.
  longestZeroRun =
    groups:
    let
      n = builtins.length groups;
      scan =
        i: bestStart: bestLen: curStart: curLen:
        if i == n then
          if bestLen >= 2 then
            {
              start = bestStart;
              len = bestLen;
            }
          else
            {
              start = -1;
              len = 0;
            }
        else
          let
            g = builtins.elemAt groups i;
          in
          if g == 0 then
            let
              nCurLen = curLen + 1;
              nCurStart = if curLen == 0 then i else curStart;
            in
            if nCurLen > bestLen then
              scan (i + 1) nCurStart nCurLen nCurStart nCurLen
            else
              scan (i + 1) bestStart bestLen nCurStart nCurLen
          else
            scan (i + 1) bestStart bestLen (-1) 0;
    in
    scan 0 (-1) 0 (-1) 0;

in
{
  inherit
    hex1
    hex2
    hex4
    hex
    longestZeroRun
    ;
}
