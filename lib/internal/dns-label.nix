/*
  Internal: shared RFC 1123 DNS label syntax, numeric labels and case
  folding.

  A DNS label is a single component between dots: in `foo.example.com`
  the labels are `foo`, `example`, `com`. Both `libnet.hostname` (a
  single label) and `libnet.domain` (≥ 2 labels joined by dots) apply
  the same per-label rules — defined here once so both modules use one
  source of truth.

  Rules per RFC 1123 §2.1 / RFC 1035 §2.3.1:
  - 1..63 ASCII characters
  - Characters: alphanumeric or hyphen (`[A-Za-z0-9-]`)
  - Must start AND end with an alphanumeric (no leading or trailing
    hyphen)

  A label is numeric when it is all digits or `0x`/`0X` followed by zero
  or more hex digits: `inet_aton` reads a name whose rightmost label is
  numeric, such as `127.1`, as an IPv4 address (ADR 0021).

  Not exposed via the public libnet attrset; consumers reach this
  module by relative import.
*/
let
  errors = import ./errors.nix;
  types = import ./types.nix;

  # `builtins.match` anchors the pattern against the whole string.
  labelPattern = "[[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?";

  isValidLabel = input: builtins.isString input && builtins.match labelPattern input != null;

  isNumericLabel = label: builtins.match "[0-9]+|0[xX][0-9A-Fa-f]*" label != null;

  # Whether a resolver reads the dotted `name` as an IPv4 address.
  hasNumericRightmostLabel =
    name:
    let
      labels = builtins.split "[.]" name;
    in
    isNumericLabel (builtins.elemAt labels (builtins.length labels - 1));

  # A hostname value whose label is numeric: `hostname` accepts it, but no
  # DNS name reads as an IPv4 address (ADR 0021).
  isNumericHostname =
    value:
    types.isHostname value && builtins.isString (value.value or null) && isNumericLabel value.value;

  /*
    Return `value` when `isExpected value` holds, like `errors.expect`, for
    an argument that must be a DNS name. A numeric hostname is described
    by its text, since `got hostname value` would not say what is wrong.
  */
  expectDnsName =
    caller: expected: isExpected: value:
    if isExpected value then
      value
    else if isNumericHostname value then
      errors.fail caller "expected ${expected}, got hostname \"${value.value}\", which reads as an IPv4 address"
    else
      errors.fail caller "expected ${expected}, got ${errors.describe value}";

  # ASCII-only lowercase for case-insensitive equality and ordering (DNS
  # labels are case-insensitive). Names are ASCII by validation, so this
  # is exhaustive within the domain. Hand-rolled to keep the core
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
in
{
  inherit
    expectDnsName
    hasNumericRightmostLabel
    isNumericHostname
    isNumericLabel
    isValidLabel
    labelPattern
    toLowerAscii
    ;
}
