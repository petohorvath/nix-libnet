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

  # Parsers return null on malformed input so callers can build tryParse
  # results without catching errors.
  decimal =
    input:
    if input == "" then
      null
    else if builtins.match "[0-9]+" input == null then
      null
    else
      let
        length = builtins.stringLength input;
        go =
          i: total:
          if i >= length then
            total
          else
            go (i + 1) (total * 10 + digitValues.${builtins.substring i 1 input});
      in
      go 0 0;

  hexInt =
    input:
    if input == "" then
      null
    else if builtins.match "[0-9a-fA-F]+" input == null then
      null
    else
      let
        length = builtins.stringLength input;
        go =
          i: total:
          if i >= length then total else go (i + 1) (total * 16 + hexValues.${builtins.substring i 1 input});
      in
      go 0 0;

  # Dotted-quad octet: 1 to 3 digits, no leading zero, at most 255.
  octet =
    input:
    if input == "" then
      null
    else if builtins.stringLength input > 3 then
      null
    else if builtins.stringLength input > 1 && builtins.substring 0 1 input == "0" then
      null
    else
      let
        value = decimal input;
      in
      if value == null || value > 255 then null else value;

  # IPv6 group: 1 to 4 hex digits.
  hexGroup =
    input:
    if input == "" then
      null
    else if builtins.stringLength input > 4 then
      null
    else
      hexInt input;

  # Byte: exactly 2 hex digits.
  hexByte =
    input:
    if input == "" then
      null
    else if builtins.stringLength input != 2 then
      null
    else
      hexInt input;

  splitOn =
    delimiter: input:
    let
      delimiterLength = builtins.stringLength delimiter;
      inputLength = builtins.stringLength input;
      go =
        start: i: parts:
        if i > inputLength - delimiterLength then
          parts ++ [ (builtins.substring start (inputLength - start) input) ]
        else if builtins.substring i delimiterLength input == delimiter then
          go (i + delimiterLength) (i + delimiterLength) (
            parts ++ [ (builtins.substring start (i - start) input) ]
          )
        else
          go start (i + 1) parts;
    in
    if inputLength == 0 then
      [ "" ]
    else if delimiterLength == 0 then
      [ input ]
    else
      go 0 0 [ ];

  countOccurrences = delimiter: input: builtins.length (splitOn delimiter input) - 1;

  startsWith =
    prefix: input:
    let
      prefixLength = builtins.stringLength prefix;
    in
    builtins.stringLength input >= prefixLength && builtins.substring 0 prefixLength input == prefix;

  endsWith =
    suffix: input:
    let
      suffixLength = builtins.stringLength suffix;
      inputLength = builtins.stringLength input;
    in
    inputLength >= suffixLength
    && builtins.substring (inputLength - suffixLength) suffixLength input == suffix;

  stripPrefix =
    prefix: input:
    let
      prefixLength = builtins.stringLength prefix;
    in
    builtins.substring prefixLength (builtins.stringLength input - prefixLength) input;

  stripSuffix =
    suffix: input:
    let
      suffixLength = builtins.stringLength suffix;
      inputLength = builtins.stringLength input;
    in
    builtins.substring 0 (inputLength - suffixLength) input;
in
{
  inherit
    countOccurrences
    decimal
    endsWith
    hexByte
    hexGroup
    hexInt
    octet
    splitOn
    startsWith
    stripPrefix
    stripSuffix
    ;
}
