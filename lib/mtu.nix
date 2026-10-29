/*
  libnet.mtu

  IP MTU — a tagged int in `[68, 65535]`. 68 is the IPv4 minimum
  forwarding MTU (RFC 791 §3.1, and the floor Linux's `ip link set
  mtu` accepts); 65535 is the IPv4 / IPv6 wire-format maximum (the
  16-bit Total Length field). This is a syntactic floor (the kernel
  will accept it), not a semantic recommendation — real-world MTUs are
  typically in `[1280, 9000]`.

  Note: `diff a b` returns `toInt b - toInt a` (second arg minus first),
  matching the other scalar modules for consistency.

  A bounded integer like `libnet.port`: `parse` reads decimal text,
  `fromInt` lifts a computed integer, and `is` tells a validated MTU
  from a bare int. The opt-in module type `libnet.types.mtu` accepts an
  integer or its decimal string and merges to an integer, so NixOS
  configs stay `mtu = 1500;`.

  Example:
    libnet.mtu.parse "1500"   # => { _type = "mtu"; value = 1500; }
    libnet.mtu.isValid "9000" # => true   (jumbo frames)
    libnet.mtu.isValid "67"   # => false  (below RFC 791 floor)
*/
import ./internal/bounded-int.nix {
  typeName = "mtu";
  lowestValue = 68;
  highestValue = 65535;
  arithmetic = true;
}
