/*
  libnet.mtu

  Bounded-int validator for IP MTU values. Accepts ints in
  `[68, 65535]`:
  - 68 is the IPv4 minimum forwarding MTU per RFC 791 §3.1 and the
    floor Linux's `ip link set mtu` will accept.
  - 65535 is the IPv4 / IPv6 wire-format maximum (the 16-bit Total
    Length field in the IPv4 header). Linux loopback uses MTUs in
    this range.

  Intentionally permissive: this is a syntactic floor (kernel will
  accept it), not a semantic recommendation. Real-world MTUs are
  typically in `[1280, 9000]`; stricter consumers can layer
  additional checks.

  Like `vlanId`, this module is intentionally tiny — an MTU is just
  an int with a range. No tagged value, no parser, no arithmetic.

  Example:
    libnet.mtu.isValid 1500   # => true   (standard Ethernet)
    libnet.mtu.isValid 9000   # => true   (jumbo frames)
    libnet.mtu.isValid 67     # => false  (below RFC 791 floor)
    libnet.mtu.isValid 65536  # => false  (above 16-bit Total Length)
*/
let
  lowestValue = 68;
  highestValue = 65535;

  isValid = v: builtins.isInt v && v >= lowestValue && v <= highestValue;
in
{
  inherit isValid lowestValue highestValue;
}
