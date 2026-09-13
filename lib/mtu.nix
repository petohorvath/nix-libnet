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

  Tagged like `libnet.port` so a validated MTU is distinguishable from
  a bare int (`is`). There is no string `parse`: MTUs are written as
  integers, so the constructor is `fromInt`. The opt-in module type
  `libnet.types.mtu` validates and returns a bare int (coerced, like
  `types.port`), so NixOS configs stay `mtu = 1500;`.

  Example:
    libnet.mtu.fromInt 1500   # => { _type = "mtu"; value = 1500; }
    libnet.mtu.isValid 9000   # => true   (jumbo frames)
    libnet.mtu.isValid 67     # => false  (below RFC 791 floor)
*/
import ./internal/bounded-int.nix {
  typeName = "mtu";
  lowestValue = 68;
  highestValue = 65535;
  arithmetic = true;
}
