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

  # ASCII-only lowercase. Hostnames are ASCII by validation, so this is
  # exhaustive within the domain. Hand-rolled to keep the core
  # dependency-free of nixpkgs.lib.
  toLowerAscii =
    builtins.replaceStrings
      [
        "A"
        "B"
        "C"
        "D"
        "E"
        "F"
        "G"
        "H"
        "I"
        "J"
        "K"
        "L"
        "M"
        "N"
        "O"
        "P"
        "Q"
        "R"
        "S"
        "T"
        "U"
        "V"
        "W"
        "X"
        "Y"
        "Z"
      ]
      [
        "a"
        "b"
        "c"
        "d"
        "e"
        "f"
        "g"
        "h"
        "i"
        "j"
        "k"
        "l"
        "m"
        "n"
        "o"
        "p"
        "q"
        "r"
        "s"
        "t"
        "u"
        "v"
        "w"
        "x"
        "y"
        "z"
      ];

  mk = v: {
    _type = "hostname";
    value = v;
  };

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.hostname.parse: input must be a string"
    else if !(dnsLabel.isValidLabel s) then
      types.tryErr "libnet.hostname.parse: invalid hostname \"${s}\" (expected 1-63 ASCII alphanumerics or hyphens, starting and ending with alphanumeric)"
    else
      types.tryOk (mk s);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString = h: h.value;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isHostname;

  # ===== Normalization =====

  normalize = h: mk (toLowerAscii h.value);

  # ===== Comparison =====
  #
  # Case-insensitive per DNS semantics. `toString` still preserves the
  # verbatim input case; only `eq` / `compare` and friends fold case.

  eq = a: b: toLowerAscii a.value == toLowerAscii b.value;

  compare =
    a: b:
    let
      la = toLowerAscii a.value;
      lb = toLowerAscii b.value;
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
    ;
  inherit
    isValid
    is
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
