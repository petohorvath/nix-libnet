/*
  Internal: shared RFC 1123 DNS label syntax.

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
in
{
  inherit labelPattern isValidLabel;
}
