let
  errors = import ./errors.nix;
  types = import ./types.nix;

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
    if !(isRepetitionOf "[0-9a-fA-F]" input) then
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

  # Split a URL at its first `://` into the scheme, as written, and the
  # rest, or return null when `input` has no `://`.
  splitScheme =
    input:
    let
      parts = splitOn "://" input;
    in
    if builtins.length parts < 2 then
      null
    else
      {
        scheme = builtins.head parts;
        rest = builtins.concatStringsSep "://" (builtins.tail parts);
      };

  /*
    Parse `address/prefix` text, for the kinds that pair an address with
    a prefix length. `tryParseAddress` is the address's detail parser,
    such as `ip.tryParseDetail`, and the prefix must fit the family of
    the address it returns.

    Returns a tryResult whose `value` is `{ address, prefix }`, or whose
    `error` is the detail of the failure.
  */
  addressPrefix =
    tryParseAddress: input:
    let
      parts = splitOn "/" input;
    in
    if builtins.length parts != 2 then
      types.tryErr "missing '/': \"${input}\""
    else
      let
        addressResult = tryParseAddress (builtins.elemAt parts 0);
        prefixText = builtins.elemAt parts 1;
        maxPrefix = if addressResult.value._type == "ipv4" then 32 else 128;
        prefix = decimal maxPrefix prefixText;
      in
      if !addressResult.success then
        addressResult
      else if !(isDecimal prefixText) then
        types.tryErr "invalid prefix \"${prefixText}\""
      else if prefix == null then
        types.tryErr "prefix /${prefixText} out of range"
      else
        types.tryOk {
          address = addressResult.value;
          inherit prefix;
        };

  /*
    Split a URL with `splitScheme` and check its scheme against a closed
    registry, for the URL forms whose unknown-scheme error carries a hint.
    `canonicalize` maps the scheme as written to a registry key, such as
    by lowercasing it, `schemes` is the registry keyed by canonical
    scheme, and `hint` lists the accepted schemes.

    Returns a tryResult whose `value` is `{ scheme, rest }` with the
    canonical scheme, or whose `error` is the detail of the failure.
  */
  splitKnownScheme =
    {
      canonicalize,
      schemes,
      hint,
    }:
    input:
    let
      split = splitScheme input;
      canonicalScheme = canonicalize split.scheme;
    in
    if split == null then
      types.tryErr "missing '<scheme>://': \"${input}\""
    else if !(schemes ? ${canonicalScheme}) then
      types.tryErr "unknown scheme \"${split.scheme}\" (${hint})"
    else
      types.tryOk {
        scheme = canonicalScheme;
        inherit (split) rest;
      };

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

  /*
    `suite namespace tryParseDetail` builds the parsing suite of the kind
    `namespace`, such as `ipv4`, from its detail parser, as
    `comparison.suite` builds ordering from one comparison.

    `tryParseDetail` takes a string and returns a tryResult whose `error`
    is the detail alone, without the `libnet.<namespace>.parse: ` prefix,
    so a union or a composite can report a member's failure under its
    own name. The suite rejects a non-string before calling it and adds
    the prefix once.

    The public namespaces export the returned functions, so their headers
    describe public API.
  */
  suite =
    namespace: tryParseDetail:
    let
      caller = "${namespace}.parse";

      /*
        Parse text without throwing, for validating untrusted input or
        reporting the error yourself.

        `input`: any value; a non-string fails.

        Returns a tryResult `{ success, value, error }`, whose `error` is
        the message `parse` would throw, naming `<namespace>.parse`.
      */
      tryParse =
        input:
        let
          result =
            if builtins.isString input then tryParseDetail input else types.tryErr (errors.notString input);
        in
        if result.success then result else types.tryErr (errors.message caller result.error);
    in
    {
      inherit tryParse;

      /*
        Parse text, for trusted configuration values.

        `input`: text of the kind.

        Returns a value of the kind; throws on a non-string or invalid
        input.
      */
      parse =
        input:
        let
          result = tryParse input;
        in
        if result.success then result.value else throw result.error;

      /*
        Check whether a value is text that parses as the kind.

        `input`: any value; non-strings yield false.

        Returns a Boolean; never throws.
      */
      isValid = input: (tryParse input).success;
    };
in
{
  inherit
    addressPrefix
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
    splitKnownScheme
    splitOn
    splitScheme
    startsWith
    stripPrefix
    suite
    ;
}
