/*
  libnet.domain

  Validated multi-label DNS name (≥ 2 labels). Each label follows the
  same RFC 1123 syntax as `libnet.hostname` (delegated to the shared
  internal helper); the domain itself adds label-hierarchy operations
  (`parent`, `isSubdomainOf`, `isSuperdomainOf`, `toHostname`).

  Validation: ≥ 2 labels separated by `.`, each label 1..63 ASCII
  chars from `[A-Za-z0-9-]` (must start and end with alnum), total
  ≤ 253 chars per RFC 1035 §3.1. No leading/trailing dot, no
  consecutive dots, no underscores, no IDN. The rightmost label is not
  numeric (all digits, or `0x` followed by hex digits), because a
  resolver reads such text as an IPv4 address (ADR 0021).

  Domains are case-insensitive (DNS semantics), so `parse` lowercases
  them (ADR 0020): `toString` prints canonical text, and equality,
  ordering and the subdomain relations compare the stored text.

  Example:
    libnet.domain.parse "Foo.Example.com"
    => { _type = "domain"; value = "foo.example.com"; }

    libnet.domain.toString (libnet.domain.parent
      (libnet.domain.parse "foo.example.com"))
    => "example.com"
*/
let
  types = import ./internal/types.nix;
  dnsLabel = import ./internal/dns-label.nix;
  parsing = import ./internal/parse.nix;
  hostname = import ./hostname.nix;
  errors = import ./internal/errors.nix;
  comparison = import ./internal/comparison.nix;

  maxLength = 253;
  minLabels = 2;

  mk = value: {
    _type = "domain";
    inherit value;
  };

  # The stored text of a domain argument of `function`.
  valueOf = function: domain: (errors.expectKind "domain.${function}" "domain" domain).value;

  labelsOf = function: domain: parsing.splitOn "." (valueOf function domain);

  # Whether `a` is `b` or lies below it, for the subdomain relation
  # named `function`.
  subdomainFor =
    function: a: b:
    let
      labelsA = labelsOf function a;
      labelsB = labelsOf function b;
      lengthA = builtins.length labelsA;
      lengthB = builtins.length labelsB;
      suffix = builtins.genList (i: builtins.elemAt labelsA (lengthA - lengthB + i)) lengthB;
    in
    lengthA >= lengthB && suffix == labelsB;

  # ===== Parsing =====

  /*
    Parse a multi-label domain, lowercasing it: the detail parser of the
    parsing suite.

    `input`: at least two dot-separated RFC 1123 labels, at most 253
    characters, without leading or trailing dot, whose rightmost label
    is neither all digits nor `0x` followed by hex digits.

    Returns a tryResult holding the domain on success, or the detail of
    the failure.
  */
  tryParseDetail =
    input:
    if builtins.stringLength input > maxLength then
      types.tryErr "too long (max ${builtins.toString maxLength} chars): \"${input}\""
    else
      let
        parts = parsing.splitOn "." input;
        partCount = builtins.length parts;
      in
      if partCount < minLabels then
        types.tryErr "needs at least ${builtins.toString minLabels} labels (got ${builtins.toString partCount}): \"${input}\""
      else if !(builtins.all dnsLabel.isValidLabel parts) then
        types.tryErr "invalid label in \"${input}\" (each label must be 1-63 ASCII alphanumerics or hyphens, starting and ending with alphanumeric)"
      else if dnsLabel.isNumericLabel (builtins.elemAt parts (partCount - 1)) then
        types.tryErr "\"${input}\" reads as an IPv4 address (numeric rightmost label)"
      else
        types.tryOk (mk (dnsLabel.toLowerAscii input));

  parsers = parsing.suite "domain" tryParseDetail;

  /*
    Render a domain as a string.

    `domain`: domain value.

    Returns the domain in lowercase.
  */
  toString = valueOf "toString";

  # ===== Construction =====

  /*
    Build a domain from its labels, for names assembled from parts.

    `labelStrings`: list of label strings, leftmost first.

    Returns the domain formed by joining the labels with ".", in
    lowercase; throws when `labelStrings` is not a list of strings or the
    joined name is invalid.
  */
  fromLabels =
    labelStrings:
    let
      caller = "domain.fromLabels";
      labels = errors.expectType caller "list" labelStrings;
      nonString = builtins.filter (i: !(builtins.isString (builtins.elemAt labels i))) (
        builtins.genList (i: i) (builtins.length labels)
      );
    in
    if nonString != [ ] then
      let
        index = builtins.head nonString;
      in
      errors.fail caller "expected list of strings, got ${errors.describe (builtins.elemAt labels index)} at index ${builtins.toString index}"
    else
      let
        result = tryParseDetail (builtins.concatStringsSep "." labels);
      in
      if result.success then result.value else errors.fail caller result.error;

  # ===== Predicates =====

  /*
    Recognize a tagged domain value without validating its payload.

    `value`: any value.

    Returns true when `value` carries the `domain` tag.
  */
  is = value: types.isDomain value;

  # ===== Accessors =====

  /*
    Split a domain into its labels.

    `domain`: domain value.

    Returns the list of label strings, leftmost first.
  */
  labels = labelsOf "labels";

  # ===== Label hierarchy =====

  /*
    Get the enclosing domain by dropping the leftmost label.

    `domain`: domain value.

    Returns the parent domain, or null when the parent would have a
    single label (for two-label domains such as `example.com`).
  */
  parent =
    domain:
    let
      parentLabels = builtins.tail (labelsOf "parent" domain);
    in
    if builtins.length parentLabels < minLabels then
      null
    else
      mk (builtins.concatStringsSep "." parentLabels);

  /*
    Test whether one domain is another or lies below it.

    `a`: candidate subdomain.
    `b`: candidate enclosing domain.

    Returns true when the labels of `b` are a suffix of the labels of
    `a`; a domain is a subdomain of itself.
  */
  isSubdomainOf = subdomainFor "isSubdomainOf";

  /*
    Test whether one domain is another or lies above it; the converse of
    `isSubdomainOf`.

    `a`: candidate enclosing domain.
    `b`: candidate subdomain.

    Returns true when the labels of `a` are a suffix of the labels of
    `b`; a domain is a superdomain of itself.
  */
  isSuperdomainOf = a: b: subdomainFor "isSuperdomainOf" b a;

  /*
    Get the leftmost label of a domain as a hostname.

    `domain`: domain value.

    Returns a hostname value. Never throws for a valid domain, because
    every domain label satisfies the hostname syntax.
  */
  toHostname = domain: hostname.parse (builtins.head (labelsOf "toHostname" domain));

  # ===== Comparison =====

  /*
    Test two domains for equality.

    `a`, `b`: values to compare.

    Returns true when both are domains with the same text; false for
    values of different types.
  */
  eq = a: b: types.bothHaveTag types.tags.domain a b && a.value == b.value;

  # Byte-wise on the lowercase text.
  ordering = comparison.suite (
    function: a: b:
    comparison.order (valueOf function a) (valueOf function b)
  );
in
{
  inherit
    eq
    fromLabels
    is
    isSubdomainOf
    isSuperdomainOf
    labels
    parent
    toHostname
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
