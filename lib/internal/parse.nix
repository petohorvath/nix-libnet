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

  # Canonical decimal text: digits only, without a leading zero.
  isDecimal = input: builtins.match "0|[1-9][0-9]*" input != null;

  # Canonical decimal text at most `max`. Text with more digits than `max`
  # is rejected before it is read, so the accumulator cannot overflow;
  # that holds only for a `max` below 10^18, so a larger one throws.
  decimal =
    max:
    if max >= 1000000000000000000 then
      throw "libnet.internal.parse.decimal: max must be below 10^18: ${builtins.toString max}"
    else
      input:
      if !(isDecimal input) then
        null
      else if builtins.stringLength input > builtins.stringLength (builtins.toString max) then
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
          value = go 0 0;
        in
        if value > max then null else value;

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

  # Dotted-quad octet: decimal without a leading zero, at most 255.
  octet = decimal 255;

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
    isDecimal
    octet
    splitOn
    startsWith
    stripPrefix
    stripSuffix
    ;
}
