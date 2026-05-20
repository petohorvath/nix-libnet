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
  parse' = import ./internal/parse.nix;
  hostname = import ./hostname.nix;

  maxLength = 253;
  minLabels = 2;

  mk = v: {
    _type = "domain";
    value = v;
  };

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.domain.parse: input must be a string"
    else if builtins.stringLength s > maxLength then
      types.tryErr "libnet.domain.parse: too long (max ${builtins.toString maxLength} chars): \"${s}\""
    else
      let
        parts = parse'.splitOn "." s;
        partCount = builtins.length parts;
      in
      if partCount < minLabels then
        types.tryErr "libnet.domain.parse: needs at least ${builtins.toString minLabels} labels (got ${builtins.toString partCount}): \"${s}\""
      else if !(builtins.all dnsLabel.isValidLabel parts) then
        types.tryErr "libnet.domain.parse: invalid label in \"${s}\" (each label must be 1-63 ASCII alphanumerics or hyphens, starting and ending with alphanumeric)"
      else
        types.tryOk (mk s);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString = d: d.value;

  # ===== Construction =====

  fromLabels =
    ls:
    if !(builtins.isList ls) then
      builtins.throw "libnet.domain.fromLabels: expected a list of strings"
    else
      parse (builtins.concatStringsSep "." ls);

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isDomain;

  # ===== Accessors =====

  labels = d: parse'.splitOn "." d.value;
  labelCount = d: builtins.length (labels d);

  # ===== Zone arithmetic =====

  # Drops the leftmost label. Returns null when the parent would
  # be a single-label string (not a valid Domain).
  parent =
    d:
    let
      ls = labels d;
      rest = builtins.tail ls;
    in
    if builtins.length rest < minLabels then null else mk (builtins.concatStringsSep "." rest);

  # Reflexive: a domain is a subdomain of itself. Case-insensitive
  # per DNS semantics.
  isSubdomainOf =
    a: b:
    let
      la = map dnsLabel.toLowerAscii (labels a);
      lb = map dnsLabel.toLowerAscii (labels b);
      lenA = builtins.length la;
      lenB = builtins.length lb;
      suffix = builtins.genList (i: builtins.elemAt la (lenA - lenB + i)) lenB;
    in
    lenA >= lenB && suffix == lb;

  # Leftmost label as a Hostname. Always succeeds because every domain
  # label satisfies the hostname syntax by construction.
  toHostname = d: hostname.parse (builtins.head (labels d));

  # ===== Normalization =====

  normalize = d: mk (dnsLabel.toLowerAscii d.value);

  # ===== Comparison =====
  #
  # Case-insensitive per DNS semantics. `toString` still preserves the
  # verbatim input case; only `eq` / `compare` and friends fold case.

  eq = a: b: dnsLabel.toLowerAscii a.value == dnsLabel.toLowerAscii b.value;

  compare =
    a: b:
    let
      la = dnsLabel.toLowerAscii a.value;
      lb = dnsLabel.toLowerAscii b.value;
    in
    if la < lb then
      -1
    else if la > lb then
      1
    else
      0;

  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;
in
{
  inherit
    parse
    tryParse
    toString
    fromLabels
    ;
  inherit
    isValid
    is
    ;
  inherit
    labels
    labelCount
    ;
  inherit
    parent
    isSubdomainOf
    toHostname
    ;
  inherit normalize;
  inherit
    eq
    lt
    le
    gt
    ge
    compare
    min
    max
    ;
}
