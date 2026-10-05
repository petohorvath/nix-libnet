# Integer-backed representations, IPv6 as four 32-bit words

IPv4 is stored as one integer, a MAC address as one 48-bit integer, and IPv6 as four unsigned 32-bit words, most significant first. Nix integers are signed 64-bit, so each word has headroom for carry, and four words make simpler carry arithmetic than the eight 16-bit groups the nixpkgs GSoC PRs used.

As a consequence, `ipv6` has no `toInt` or `fromInt`, and sizes or differences of 2⁶³ or more (`cidr.size` on prefixes shorter than `/65`, `ipv6.diff` across distant addresses) throw instead of overflowing.
