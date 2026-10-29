/*
  libnet.regName

  An RFC 3986 registered name (§3.2.2): the URL host that is not an IP
  literal. A loose ASCII set — unreserved characters, sub-delimiters,
  and `%`-encoding — with no DNS label structure, so `my_host` and
  `a%20b` are valid where `libnet.dnsName` rejects them. A member of
  the `libnet.urlHost` union.

  Equality and ordering are case-insensitive, like DNS names; `toString`
  preserves the input case.

  Example:
    libnet.regName.parse "my_host"
    => { _type = "regName"; value = "my_host"; }
*/
let
  types = import ./internal/types.nix;
  dnsLabel = import ./internal/dns-label.nix;

  lowerAscii = dnsLabel.toLowerAscii;

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
    and `%XX` escapes.

    Returns a tryResult: `{ success = true; value = <regName>; }` or
    `{ success = false; error = <string>; }`. Never throws.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.regName.parse: input must be a string"
    else if builtins.match regNamePattern input == null then
      types.tryErr "libnet.regName.parse: invalid registered name \"${input}\""
    else
      types.tryOk (mk input);

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

    Returns the name exactly as parsed, preserving case.
  */
  toString = regName: regName.value;

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
    Test two registered names for equality, ignoring case.

    `a`, `b`: values to compare.

    Returns true when both are regName values whose names match
    case-insensitively; false for values of different types.
  */
  eq = a: b: types.hasSameTag a b && lowerAscii a.value == lowerAscii b.value;

  /*
    Order two registered names case-insensitively.

    `a`, `b`: regName values.

    Returns -1, 0, or 1.
  */
  compare =
    a: b:
    let
      lowerA = lowerAscii a.value;
      lowerB = lowerAscii b.value;
    in
    if lowerA < lowerB then
      -1
    else if lowerA > lowerB then
      1
    else
      0;

  /*
    Check whether one registered name sorts before another.

    `a`, `b`: regName values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Check whether one registered name sorts before or equal to another.

    `a`, `b`: regName values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Check whether one registered name sorts after another.

    `a`, `b`: regName values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Check whether one registered name sorts after or equal to another.

    `a`, `b`: regName values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two registered names by `compare`.

    `a`, `b`: regName values.

    Returns `a` when it sorts first or equal, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two registered names by `compare`.

    `a`, `b`: regName values.

    Returns `a` when it sorts last or equal, otherwise `b`.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    compare
    eq
    ge
    gt
    is
    isValid
    le
    lt
    max
    min
    parse
    toString
    tryParse
    ;
}
