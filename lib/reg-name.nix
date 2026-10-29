/*
  libnet.regName

  An RFC 3986 registered name (§3.2.2): the URL host that is not an IP
  literal. A loose ASCII set — unreserved characters, sub-delimiters,
  and `%`-encoding — with no DNS label structure, so `my_host` and
  `a%20b` are valid where `libnet.dnsName` rejects them. Text that is a
  valid IPv4 address is an IP literal, not a registered name (RFC 3986
  §3.2.2). A member of the `libnet.urlHost` union.

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
  ipv4 = import ./ipv4.nix;
  errors = import ./internal/errors.nix;
  comparison = import ./internal/comparison.nix;
  parsing = import ./internal/parse.nix;

  upperHex = builtins.replaceStrings [ "a" "b" "c" "d" "e" "f" ] [ "A" "B" "C" "D" "E" "F" ];

  # Lowercase the text, then uppercase the two hex digits after each `%`.
  # Validation guarantees that every `%` starts a full escape.
  fold =
    input:
    let
      segments = parsing.splitOn "%" (dnsLabel.toLowerAscii input);
      foldEscape =
        segment:
        upperHex (builtins.substring 0 2 segment)
        + builtins.substring 2 (builtins.stringLength segment) segment;
    in
    builtins.concatStringsSep "%" (
      [ (builtins.head segments) ] ++ map foldEscape (builtins.tail segments)
    );

  # The stored text of a regName argument of `caller`.
  valueOf = caller: regName: (errors.expectKind caller "regName" regName).value;

  parseError = detail: types.tryErr (errors.message "regName.parse" detail);

  # reg-name = *( unreserved / pct-encoded / sub-delims ); we require >= 1.
  regNamePattern = "([-A-Za-z0-9._~!$&'()*+,;=]|%[0-9A-Fa-f][0-9A-Fa-f])+";

  mk = value: {
    _type = "regName";
    inherit value;
  };

  # ===== Parsing =====

  /*
    Parse a registered name without throwing, for callers that branch on
    validity.

    `input`: a non-empty string of unreserved characters, sub-delimiters,
    and `%XX` escapes that is not a valid IPv4 address.

    Returns a tryResult: `{ success = true; value = <regName>; }`, with
    letters lowercase and percent-encoding hex digits uppercase, or
    `{ success = false; error = <string>; }`. Never throws.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else if builtins.match regNamePattern input == null then
      parseError "invalid registered name \"${input}\""
    else if ipv4.isValid input then
      parseError "\"${input}\" is an IPv4 address, not a registered name"
    else
      types.tryOk (mk (fold input));

  /*
    Parse a registered name, for values that must be valid.

    `input`: registered-name text as accepted by `tryParse`.

    Returns a regName value; throws on invalid input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a registered name.

    `regName`: a regName value.

    Returns the name in canonical form: letters lowercase,
    percent-encoding hex digits uppercase.
  */
  toString = valueOf "regName.toString";

  # ===== Predicates =====

  /*
    Check whether a string parses as a registered name.

    `input`: candidate name text.

    Returns true when `tryParse` succeeds.
  */
  isValid = input: (tryParse input).success;

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
  eq = a: b: types.hasSameTag a b && a.value == b.value;

  # Byte-wise on the folded text.
  ordering = comparison.suite {
    namespace = "regName";
    compareFor =
      caller: a: b:
      comparison.order (valueOf caller a) (valueOf caller b);
  };
in
{
  inherit
    eq
    is
    isValid
    parse
    toString
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
