# Size guards on enumeration

Functions that build lists throw above a size limit, so a typo such as `/8` for `/28` fails fast instead of exhausting evaluation memory. `cidr.hosts` and `ipRange.addresses` stop at 2¹⁶ entries; `portRange.ports` and `ipBindpoint.endpoints` stop at 4096. Each has an `*Unbounded` sibling, and indexed access (`cidr.hostAt`, `portRange.portAt`, `ipRange.addressAt`, `ipBindpoint.endpointAt`) reaches into large ranges without listing them.
