/*
  libnet.hostname

  Validated single-label RFC 1123 hostname — the shape Linux uses for
  kernel hostnames (what `gethostname(2)` returns, what
  `networking.hostName` accepts). Multi-label / FQDN names live in
  `libnet.domain`, not here.

  Validation: 1..63 ASCII chars from `[A-Za-z0-9-]`, must start and
  end with an alphanumeric character, no dots, no underscores. Leading
  digit allowed (RFC 1123 §2.1 relaxed the older RFC 952 rule).

  Hostnames are case-insensitive (DNS semantics), so `parse` lowercases
  them (ADR 0020): `toString` prints canonical text, and equality and
  ordering compare the stored text.

  Example:
    libnet.hostname.parse "MyHost"
    => { _type = "hostname"; value = "myhost"; }

    libnet.hostname.eq (libnet.hostname.parse "NAS")
                       (libnet.hostname.parse "nas")
    => true
*/
let
  types = import ./internal/types.nix;
  dnsLabel = import ./internal/dns-label.nix;
  errors = import ./internal/errors.nix;
  comparison = import ./internal/comparison.nix;

  mk = value: {
    _type = "hostname";
    inherit value;
  };

  # The stored text of a hostname argument of `caller`.
  valueOf = caller: hostname: (errors.expectKind caller "hostname" hostname).value;

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
      types.tryErr (errors.message "hostname.parse" "expected string, got ${errors.describe input}")
    else if !(dnsLabel.isValidLabel input) then
      types.tryErr (
        errors.message "hostname.parse" "invalid hostname \"${input}\" (expected 1-63 ASCII alphanumerics or hyphens, starting and ending with alphanumeric)"
      )
    else
      types.tryOk (mk (dnsLabel.toLowerAscii input));

  /*
    Parse a single-label hostname, lowercasing it.

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

    Returns the hostname in lowercase.
  */
  toString = valueOf "hostname.toString";

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

  # ===== Comparison =====

  /*
    Test two hostnames for equality.

    `a`, `b`: values to compare.

    Returns true when both are hostnames with the same text; false for
    values of different types.
  */
  eq = a: b: types.bothHaveTag types.tags.hostname a b && a.value == b.value;

  # Byte-wise on the lowercase text.
  ordering = comparison.suite {
    namespace = "hostname";
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
