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

  /*
    Whether `input` is one or more occurrences of `token`, a regular
    expression that matches no empty text. builtins.split matches one
    occurrence at a time, whereas a repetition in builtins.match recurses
    once per occurrence and exhausts the stack on long input.
  */
  isRepetitionOf =
    token: input:
    input != ""
    && builtins.all (part: part == "") (builtins.filter builtins.isString (builtins.split token input));

  # Canonical decimal text: digits only, without a leading zero.
  isDecimal =
    input: input == "0" || (builtins.substring 0 1 input != "0" && isRepetitionOf "[0-9]" input);

  # Digits with a leading zero, which canonical decimal text forbids.
  hasLeadingZero =
    input:
    builtins.stringLength input > 1
    && builtins.substring 0 1 input == "0"
    && isRepetitionOf "[0-9]" input;

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

  # Escape the characters special in builtins.split's POSIX extended
  # regular expressions. `]` stays bare: it is literal outside a bracket
  # expression, and builtins.split rejects `\]`.
  escapeRegex =
    builtins.replaceStrings
      [
        "\\"
        "."
        "["
        "("
        ")"
        "{"
        "*"
        "+"
        "?"
        "|"
        "^"
        "$"
      ]
      [
        "\\\\"
        "\\."
        "\\["
        "\\("
        "\\)"
        "\\{"
        "\\*"
        "\\+"
        "\\?"
        "\\|"
        "\\^"
        "\\$"
      ];

  # builtins.split, rather than recursion per character, so long input
  # cannot exceed the maximum call depth.
  splitOn =
    delimiter: input:
    if delimiter == "" then
      [ input ]
    else
      builtins.filter builtins.isString (builtins.split (escapeRegex delimiter) input);

  /*
    Text shaped like an IPv4 address: digits and dots only. A union whose
    members all reject such text reports the IP member's error, since no
    name is written that way (ADR 0021).
  */
  isDottedDigits = isRepetitionOf "[0-9.]";

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
    hasLeadingZero
    hexByte
    hexGroup
    hexInt
    isDecimal
    isDottedDigits
    isRepetitionOf
    octet
    splitOn
    startsWith
    stripPrefix
    stripSuffix
    ;
}
