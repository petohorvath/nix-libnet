/*
  libnet.domain

  Validated multi-label DNS name (≥ 2 labels). Each label follows the
  same RFC 1123 syntax as `libnet.hostname` (delegated to the shared
  internal helper); the domain itself adds zone-arithmetic operations
  (`parent`, `isSubdomainOf`, `toHostname`).

  Validation: ≥ 2 labels separated by `.`, each label 1..63 ASCII
  chars from `[A-Za-z0-9-]` (must start and end with alnum), total
  ≤ 253 chars per RFC 1035 §3.1. No leading/trailing dot, no
  consecutive dots, no underscores, no IDN.

  Equality and ordering are case-insensitive (DNS semantics).
  `toString` preserves the input case verbatim; `normalize` returns a
  lowercase value.

  Example:
    libnet.domain.parse "foo.example.com"
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

  maxLength = 253;
  minLabels = 2;

  mk = value: {
    _type = "domain";
    inherit value;
  };

  # ===== Parsing =====

  /*
    Parse a domain without throwing, for callers that branch on
    validity or report the error themselves.

    `input`: candidate domain string.

    Returns a tryResult `{ success, value, error }` holding the domain
    on success or an error message on failure.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.domain.parse: input must be a string"
    else if builtins.stringLength input > maxLength then
      types.tryErr "libnet.domain.parse: too long (max ${builtins.toString maxLength} chars): \"${input}\""
    else
      let
        parts = parsing.splitOn "." input;
        partCount = builtins.length parts;
      in
      if partCount < minLabels then
        types.tryErr "libnet.domain.parse: needs at least ${builtins.toString minLabels} labels (got ${builtins.toString partCount}): \"${input}\""
      else if !(builtins.all dnsLabel.isValidLabel parts) then
        types.tryErr "libnet.domain.parse: invalid label in \"${input}\" (each label must be 1-63 ASCII alphanumerics or hyphens, starting and ending with alphanumeric)"
      else
        types.tryOk (mk input);

  /*
    Parse a multi-label domain, keeping its case verbatim.

    `input`: at least two dot-separated RFC 1123 labels, at most 253
    characters, without leading or trailing dot.

    Returns a domain value; throws on non-string or invalid input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a domain as a string.

    `domain`: domain value.

    Returns the domain exactly as parsed, preserving case.
  */
  toString = domain: domain.value;

  # ===== Construction =====

  /*
    Build a domain from its labels, for names assembled from parts.

    `labelStrings`: list of label strings, leftmost first.

    Returns the domain formed by joining the labels with "."; throws
    when `labelStrings` is not a list or the joined name is invalid.
  */
  fromLabels =
    labelStrings:
    if !(builtins.isList labelStrings) then
      throw "libnet.domain.fromLabels: expected a list of strings"
    else
      parse (builtins.concatStringsSep "." labelStrings);

  # ===== Predicates =====

  /*
    Check whether a value parses as a domain.

    `input`: any value; non-strings are invalid.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

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
  labels = domain: parsing.splitOn "." domain.value;

  /*
    Count the labels of a domain.

    `domain`: domain value.

    Returns the number of labels, always at least 2.
  */
  labelCount = domain: builtins.length (labels domain);

  # ===== Zone arithmetic =====

  /*
    Get the enclosing zone of a domain by dropping its leftmost label.

    `domain`: domain value.

    Returns the parent domain, or null when the parent would have a
    single label (for two-label domains such as `example.com`).
  */
  parent =
    domain:
    let
      parentLabels = builtins.tail (labels domain);
    in
    if builtins.length parentLabels < minLabels then
      null
    else
      mk (builtins.concatStringsSep "." parentLabels);

  /*
    Test whether one domain lies within another's zone.

    `a`: candidate subdomain.
    `b`: candidate enclosing domain.

    Returns true when the labels of `b` are a case-insensitive suffix
    of the labels of `a`; a domain is a subdomain of itself.
  */
  isSubdomainOf =
    a: b:
    let
      labelsA = map dnsLabel.toLowerAscii (labels a);
      labelsB = map dnsLabel.toLowerAscii (labels b);
      lengthA = builtins.length labelsA;
      lengthB = builtins.length labelsB;
      suffix = builtins.genList (i: builtins.elemAt labelsA (lengthA - lengthB + i)) lengthB;
    in
    lengthA >= lengthB && suffix == labelsB;

  /*
    Get the leftmost label of a domain as a hostname.

    `domain`: domain value.

    Returns a hostname value. Never throws for a valid domain, because
    every domain label satisfies the hostname syntax.
  */
  toHostname = domain: hostname.parse (builtins.head (labels domain));

  # ===== Normalization =====

  /*
    Lowercase a domain so equal names share one spelling.

    `domain`: domain value.

    Returns a domain value with an ASCII-lowercased `value`.
  */
  normalize = domain: mk (dnsLabel.toLowerAscii domain.value);

  # ===== Comparison =====
  #
  # Case-insensitive per DNS semantics. `toString` still preserves the
  # verbatim input case; only `eq` / `compare` and friends fold case.

  /*
    Test two domains for equality, ignoring case.

    `a`, `b`: values to compare.

    Returns true when both carry the same tag and their values match
    case-insensitively; false for values of different types.
  */
  eq = a: b: types.hasSameTag a b && dnsLabel.toLowerAscii a.value == dnsLabel.toLowerAscii b.value;

  /*
    Order two domains case-insensitively, for sorting.

    `a`, `b`: domain values.

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
    Test whether one domain sorts strictly before another.

    `a`, `b`: domain values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether one domain sorts before or equal to another.

    `a`, `b`: domain values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether one domain sorts strictly after another.

    `a`, `b`: domain values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether one domain sorts after or equal to another.

    `a`, `b`: domain values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the domain that sorts first.

    `a`, `b`: domain values.

    Returns `a` when `le a b`, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the domain that sorts last.

    `a`, `b`: domain values.

    Returns `a` when `ge a b`, otherwise `b`.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    compare
    eq
    fromLabels
    ge
    gt
    is
    isSubdomainOf
    isValid
    labelCount
    labels
    le
    lt
    max
    min
    normalize
    parent
    parse
    toHostname
    toString
    tryParse
    ;
}
