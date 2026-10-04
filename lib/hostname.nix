/*
  libnet.hostname

  Validated single-label RFC 1123 hostname — the shape Linux uses for
  kernel hostnames (what `gethostname(2)` returns, what
  `networking.hostName` accepts). Multi-label / FQDN names live in
  `libnet.domain`, not here.

  Validation: 1..63 ASCII chars from `[A-Za-z0-9-]`, must start and
  end with an alphanumeric character, no dots, no underscores. Leading
  digit allowed (RFC 1123 §2.1 relaxed the older RFC 952 rule).

  Equality and ordering are case-insensitive (DNS semantics — two
  hostnames that differ only in case refer to the same host).
  `toString` preserves the input case verbatim; `normalize` returns a
  lowercase value.

  Example:
    libnet.hostname.parse "MyHost"
    => { _type = "hostname"; value = "MyHost"; }

    libnet.hostname.eq (libnet.hostname.parse "NAS")
                       (libnet.hostname.parse "nas")
    => true
*/
let
  types = import ./internal/types.nix;
  dnsLabel = import ./internal/dns-label.nix;

  mk = value: {
    _type = "hostname";
    inherit value;
  };

  # ===== Parsing =====

  /*
    Parse a hostname without throwing, for callers that branch on
    validity or report the error themselves.

    `input`: candidate hostname string.

    Returns a tryResult `{ success, value, error }` holding the hostname
    on success or an error message on failure.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.hostname.parse: input must be a string"
    else if !(dnsLabel.isValidLabel input) then
      types.tryErr "libnet.hostname.parse: invalid hostname \"${input}\" (expected 1-63 ASCII alphanumerics or hyphens, starting and ending with alphanumeric)"
    else
      types.tryOk (mk input);

  /*
    Parse a single-label hostname, keeping its case verbatim.

    `input`: 1-63 ASCII alphanumerics or hyphens, starting and ending
    with an alphanumeric.

    Returns a hostname value; throws on non-string or invalid input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a hostname as a string.

    `hostname`: hostname value.

    Returns the hostname exactly as parsed, preserving case.
  */
  toString = hostname: hostname.value;

  # ===== Predicates =====

  /*
    Check whether a value parses as a hostname.

    `input`: any value; non-strings are invalid.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

  /*
    Recognize a tagged hostname value without validating its payload.

    `value`: any value.

    Returns true when `value` carries the `hostname` tag.
  */
  is = value: types.isHostname value;

  # ===== Normalization =====

  /*
    Lowercase a hostname so equal names share one spelling.

    `hostname`: hostname value.

    Returns a hostname value with an ASCII-lowercased `value`.
  */
  normalize = hostname: mk (dnsLabel.toLowerAscii hostname.value);

  # ===== Comparison =====
  #
  # Case-insensitive per DNS semantics. `toString` still preserves the
  # verbatim input case; only `eq` / `compare` and friends fold case.

  /*
    Test two hostnames for equality, ignoring case.

    `a`, `b`: values to compare.

    Returns true when both carry the same tag and their values match
    case-insensitively; false for values of different types.
  */
  eq = a: b: types.hasSameTag a b && dnsLabel.toLowerAscii a.value == dnsLabel.toLowerAscii b.value;

  /*
    Order two hostnames case-insensitively, for sorting.

    `a`, `b`: hostname values.

    Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`.
  */
  compare =
    a: b:
    let
      lowerA = dnsLabel.toLowerAscii a.value;
      lowerB = dnsLabel.toLowerAscii b.value;
    in
    if lowerA < lowerB then
      -1
    else if lowerA > lowerB then
      1
    else
      0;

  /*
    Test whether one hostname sorts strictly before another.

    `a`, `b`: hostname values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether one hostname sorts before or equal to another.

    `a`, `b`: hostname values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether one hostname sorts strictly after another.

    `a`, `b`: hostname values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether one hostname sorts after or equal to another.

    `a`, `b`: hostname values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the hostname that sorts first.

    `a`, `b`: hostname values.

    Returns `a` when `le a b`, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the hostname that sorts last.

    `a`, `b`: hostname values.

    Returns `a` when `ge a b`, otherwise `b`.
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
    normalize
    parse
    toString
    tryParse
    ;
}
