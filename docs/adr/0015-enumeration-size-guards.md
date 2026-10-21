# Size guards on enumeration

Functions that build lists throw above a size limit, so a typo such as `/8` for `/28` fails fast instead of exhausting evaluation memory. `cidr.hosts` and `ipRange.addresses` stop at 2¹⁶ entries; `portRange.ports` and `ipBindpoint.endpoints` stop at 4096. Each has an `*Unbounded` sibling, and indexed access (`cidr.addressAt`, `portRange.portAt`, `ipRange.addressAt`, `ipBindpoint.endpointAt`) reaches into large ranges without listing them. Indexed access still needs the range's size, so `cidr.addressAt` and `ipRange.addressAt` throw on ranges of 2⁶³ or more addresses, such as an IPv6 `/64`.

`cidr.subnets` caps its split depth at 16, or 2¹⁶ blocks, and has no unbounded sibling: its argument states the block count directly, rather than deriving it from a prefix where one mistyped digit multiplies the size.
