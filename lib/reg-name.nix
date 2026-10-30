/*
  libnet.regName

  An RFC 3986 registered name (§3.2.2): the URL host that is not an IP
  literal. A loose ASCII set — unreserved characters, sub-delimiters,
  and `%`-encoding — with no DNS label structure, so `my_host` and
  `a%20b` are valid where `libnet.dnsName` rejects them. Text whose
  rightmost label is numeric, all digits or `0x` followed by hex
  digits, is not a registered name (ADR 0021): RFC 3986 §3.2.2 reads
  only a dotted quad as an IP literal, but curl and browsers read
  `127.1` and `0x7f.0.0.1` as IPv4 addresses too, and ignore one
  trailing dot when they do. A member of the `libnet.urlHost` union.

  Registered names are case-insensitive, like DNS names, so `parse`
  folds them to the RFC 3986 §6.2.2.1 canonical form (ADR 0020): letters
  lowercase and the hex digits of percent-encodings uppercase. `toString`
  prints canonical text, and equality and ordering compare the stored
  text.

  Example:
    libnet.regName.parse "My_Host%2f"
    => { _type = "regName"; value = "my_host%2F"; }
*/
let
  types = import ./internal/types.nix;
  dnsLabel = import ./internal/dns-label.nix;
  errors = import ./internal/errors.nix;
  comparison = import ./internal/comparison.nix;
  parsing = import ./internal/parse.nix;

  # Lowercase the text, then uppercase the two hex digits after each `%`.
  # Validation guarantees that every `%` starts a full escape.
  fold = input: parsing.uppercasePercentEncodings (dnsLabel.toLowerAscii input);

  # The stored text of a regName argument of `function`.
  valueOf = function: regName: (errors.expectKind "regName.${function}" "regName" regName).value;

  # Whether a client reads `input` as an IPv4 address, ignoring one
  # trailing dot as browsers do.
  readsAsIpv4 =
    input:
    let
      length = builtins.stringLength input;
      withoutTrailingDot =
        if builtins.substring (length - 1) 1 input == "." then
          builtins.substring 0 (length - 1) input
        else
          input;
    in
    dnsLabel.hasNumericRightmostLabel withoutTrailingDot;

  # reg-name = *( unreserved / pct-encoded / sub-delims ); we require >= 1.
  isRegName = parsing.isRepetitionOf "[-A-Za-z0-9._~!$&'()*+,;=]|%[0-9A-Fa-f][0-9A-Fa-f]";

  mk = value: {
    _type = "regName";
    inherit value;
  };

  # ===== Parsing =====

  /*
    Parse a registered name: the detail parser of the parsing suite.

    `input`: a non-empty string of unreserved characters, sub-delimiters,
    and `%XX` escapes whose rightmost label is not numeric.

    Returns a tryResult holding a regName value, with letters lowercase
    and percent-encoding hex digits uppercase, or the detail of the
    failure.
  */
  tryParseDetail =
    input:
    if !(isRegName input) then
      types.tryErr "invalid registered name \"${input}\""
    else if readsAsIpv4 input then
      types.tryErr "\"${input}\" reads as an IPv4 address, not a registered name"
    else
      types.tryOk (mk (fold input));

  parsers = parsing.suite "regName" tryParseDetail;

  /*
    Render a registered name.

    `regName`: a regName value.

    Returns the name in canonical form: letters lowercase,
    percent-encoding hex digits uppercase.
  */
  toString = valueOf "toString";

  # ===== Predicates =====

  /*
    Check whether a value is a regName value.

    `value`: any value.

    Returns true for a regName-tagged attrset.
  */
  is = value: types.isRegName value;

  # ===== Comparison =====

  /*
    Test two registered names for equality.

    `a`, `b`: values to compare.

    Returns true when both are regName values with the same text; false
    for values of different types.
  */
  eq = a: b: types.bothHaveTag types.tags.regName a b && a.value == b.value;

  # Byte-wise on the folded text.
  ordering = comparison.suite (
    function: a: b:
    comparison.order (valueOf function a) (valueOf function b)
  );
in
{
  inherit
    eq
    is
    toString
    tryParseDetail
    ;
  inherit (parsers)
    isValid
    parse
    tryParse
    ;
  inherit (ordering)
    compare
    ge
    gt
    le
    lt
    max
    min
    ;
}
