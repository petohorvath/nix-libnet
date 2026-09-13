/*
  libnet.icmpType

  ICMP / ICMPv6 message type — a tagged int in `[0, 255]` (the 8-bit
  Type field, RFC 792 / RFC 4443). One family-agnostic type: v4 and
  v6 share the range, so family correctness is not range-checkable —
  type 3 is destination-unreachable in ICMP but time-exceeded in
  ICMPv6 — exactly like a UDP port in a TCP list. Named constants
  live in `libnet.registry.icmpTypes.{ipv4,ipv6}` (bare ints).

  Tagged like `libnet.port` so a validated ICMP type is
  distinguishable from a bare int (`is`). There is no string `parse`:
  ICMP types are written as integers, so the constructor is
  `fromInt`. The opt-in module type `libnet.types.icmpType` validates
  and returns a bare int (coerced, like `types.port`), so NixOS
  configs stay `icmpv4 = [ 8 ];`.

  Example:
    libnet.icmpType.fromInt 8     # => { _type = "icmpType"; value = 8; }
    libnet.icmpType.isValid 255   # => true   (reserved, but in range)
    libnet.icmpType.isValid 256   # => false  (the Type field is 8 bits)
*/
# Adjacent type numbers are unrelated messages, so arithmetic stays absent.
import ./internal/bounded-int.nix {
  typeName = "icmpType";
  lowestValue = 0;
  highestValue = 255;
}
