let
  digitValues = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
  };

  hexValues = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  };

  decimal =
    s:
    if s == "" then
      null
    else if builtins.match "[0-9]+" s == null then
      null
    else
      let
        len = builtins.stringLength s;
        go =
          i: acc: if i >= len then acc else go (i + 1) (acc * 10 + digitValues.${builtins.substring i 1 s});
      in
      go 0 0;

  hexInt =
    s:
    if s == "" then
      null
    else if builtins.match "[0-9a-fA-F]+" s == null then
      null
    else
      let
        len = builtins.stringLength s;
        go =
          i: acc: if i >= len then acc else go (i + 1) (acc * 16 + hexValues.${builtins.substring i 1 s});
      in
      go 0 0;

  octet =
    s:
    if s == "" then
      null
    else if builtins.stringLength s > 3 then
      null
    else if builtins.stringLength s > 1 && builtins.substring 0 1 s == "0" then
      null
    else
      let
        r = decimal s;
      in
      if r == null || r > 255 then null else r;

  hexGroup =
    s:
    if s == "" then
      null
    else if builtins.stringLength s > 4 then
      null
    else
      hexInt s;

  hexByte =
    s:
    if s == "" then
      null
    else if builtins.stringLength s != 2 then
      null
    else
      hexInt s;

  splitOn =
    delim: s:
    let
      dlen = builtins.stringLength delim;
      slen = builtins.stringLength s;
      go =
        start: i: acc:
        if i > slen - dlen then
          acc ++ [ (builtins.substring start (slen - start) s) ]
        else if builtins.substring i dlen s == delim then
          go (i + dlen) (i + dlen) (acc ++ [ (builtins.substring start (i - start) s) ])
        else
          go start (i + 1) acc;
    in
    if slen == 0 then
      [ "" ]
    else if dlen == 0 then
      [ s ]
    else
      go 0 0 [ ];

  countOccurrences = sub: s: builtins.length (splitOn sub s) - 1;

  startsWith =
    prefix: s:
    let
      plen = builtins.stringLength prefix;
    in
    builtins.stringLength s >= plen && builtins.substring 0 plen s == prefix;

  endsWith =
    suffix: s:
    let
      slen = builtins.stringLength suffix;
      total = builtins.stringLength s;
    in
    total >= slen && builtins.substring (total - slen) slen s == suffix;

  stripPrefix =
    prefix: s:
    let
      plen = builtins.stringLength prefix;
    in
    builtins.substring plen (builtins.stringLength s - plen) s;

  stripSuffix =
    suffix: s:
    let
      slen = builtins.stringLength suffix;
      total = builtins.stringLength s;
    in
    builtins.substring 0 (total - slen) s;
in
{
  inherit
    decimal
    hexInt
    octet
    hexGroup
    hexByte
    ;
  inherit
    splitOn
    countOccurrences
    startsWith
    endsWith
    stripPrefix
    stripSuffix
    ;
}
