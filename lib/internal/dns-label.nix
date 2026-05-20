/*
  Internal: shared RFC 1123 DNS label syntax and case folding.

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

  Not exposed via the public libnet attrset; consumers reach this
  module by relative import.
*/
let
  # `builtins.match` anchors the pattern against the whole string.
  labelPattern = "[[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?";

  isValidLabel = s: builtins.isString s && builtins.match labelPattern s != null;

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
  inherit labelPattern isValidLabel toLowerAscii;
}
