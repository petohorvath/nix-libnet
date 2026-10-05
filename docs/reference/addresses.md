# Addresses

## `libnet.ipv4`

Value: `{ _type = "ipv4"; value = Int; }` with `value` in `[0, 2³² − 1]`. Canonical text is the dotted quad. `parse` rejects leading zeros, octets above 255, and any count other than four octets.

Suites: parsing, comparison, arithmetic (`next` throws at `255.255.255.255`, `prev` at `0.0.0.0`).

| Function | Signature | Notes |
| --- | --- | --- |
| `fromInt`, `toInt` | `Int ↔ Ipv4` | `fromInt` throws out of range. |
| `fromOctets`, `toOctets` | `[Int] ↔ Ipv4` | Four octets, most significant first. |
| `fromBytes`, `toBytes` | `[Int] ↔ Ipv4` | Aliases of the octet functions, named as in `ipv6` and `mac`. |
| `toArpa` | `Ipv4 → String` | `1.2.3.4` → `4.3.2.1.in-addr.arpa`. |

Constants: `unspecified` (`0.0.0.0`), `broadcast` (`255.255.255.255`), `loopback` (`127.0.0.1`).

Predicates, each `Ipv4 → Bool`:

| Predicate | Block |
| --- | --- |
| `isLoopback` | `127.0.0.0/8` |
| `isPrivate` | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` (RFC 1918) |
| `isLinkLocal` | `169.254.0.0/16` |
| `isMulticast` | `224.0.0.0/4` |
| `isBroadcast` | `255.255.255.255` |
| `isUnspecified` | `0.0.0.0` |
| `isReserved` | `240.0.0.0/4` except the broadcast address |
| `isDocumentation` | `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` |
| `isThisNetwork` | `0.0.0.0/8` (RFC 1122) |
| `isSharedAddressSpace` | `100.64.0.0/10` (RFC 6598) |
| `isProtocolAssignment` | `192.0.0.0/24` (RFC 6890) |
| `isBenchmarking` | `198.18.0.0/15` (RFC 2544) |
| `isBogon` | Any predicate above |
| `isGlobal` | `!isBogon` |

## `libnet.ipv6`

Value: `{ _type = "ipv6"; words = [Int Int Int Int]; }`, four 32-bit words with the most significant first; `2001:db8::1` is `[ 536939960 0 0 1 ]`. `parse` accepts compression, mixed case, and embedded IPv4 (`::ffff:1.2.3.4`). Canonical text follows RFC 5952.

Suites: parsing, comparison (ordered by words), arithmetic (carry and borrow cross words; `diff` throws when the result does not fit in a Nix integer). There is no `toInt` or `fromInt`.

| Function | Signature | Notes |
| --- | --- | --- |
| `toStringCompressed` | `Ipv6 → String` | Alias of `toString`. |
| `toStringExpanded` | `Ipv6 → String` | `2001:0db8:0000:0000:0000:0000:0000:0001`. |
| `toStringBracketed` | `Ipv6 → String` | `[2001:db8::1]`. |
| `fromWords`, `toWords` | `[Int] ↔ Ipv6` | Four 32-bit words. |
| `fromGroups`, `toGroups` | `[Int] ↔ Ipv6` | Eight 16-bit groups. |
| `fromBytes`, `toBytes` | `[Int] ↔ Ipv6` | Sixteen bytes. |
| `toArpa` | `Ipv6 → String` | 32 reversed nibbles under `ip6.arpa`. |
| `fromEui64` | `Cidr → Mac → Ipv6` | Upper 64 bits from the CIDR, lower 64 from the MAC's modified EUI-64. Throws when the prefix exceeds 64. |
| `fromIpv4Mapped` | `Ipv4 → Ipv6` | `1.2.3.4` → `::ffff:1.2.3.4`. |
| `toIpv4Mapped` | `Ipv6 → Ipv4` | Throws outside `::ffff:0:0/96`. |

Constants: `unspecified` (`::`), `loopback` (`::1`). IPv6 has no broadcast.

Predicates, each `Ipv6 → Bool`:

| Predicate | Block |
| --- | --- |
| `isLoopback` | `::1` |
| `isUnspecified` | `::` |
| `isLinkLocal` | `fe80::/10` |
| `isUniqueLocal` | `fc00::/7` (RFC 4193) |
| `isMulticast` | `ff00::/8` |
| `isDocumentation` | `2001:db8::/32`, `3fff::/20` |
| `isDiscard` | `100::/64` (RFC 6666) |
| `isOrchid` | `2001:10::/28` (RFC 4843, deprecated) |
| `isSiteLocal` | `fec0::/10` (RFC 3879, deprecated) |
| `isIpv4Mapped` | `::ffff:0:0/96` |
| `isIpv4Compatible` | `::0.0.0.0/96` (deprecated) |
| `is6to4` | `2002::/16` |
| `isBogon` | Any predicate from `isLoopback` through `isSiteLocal` |
| `isGlobal` | Neither a bogon nor one of the three IPv4 transition forms |

## `libnet.ip`

Pass-through union over `ipv4` and `ipv6`; `parse` picks IPv6 when the input contains `:`.

Suites: parsing, comparison, arithmetic (dispatched by family; `diff` across families throws), address predicates.

| Function | Signature | Notes |
| --- | --- | --- |
| `version` | `Ip → Int` | `4` or `6`. |
| `isIpv4`, `isIpv6` | `Any → Bool` | |

## `libnet.mac`

Value: `{ _type = "mac"; value = Int; }` with `value` in `[0, 2⁴⁸ − 1]`. `parse` accepts `aa:bb:cc:dd:ee:ff`, `aa-bb-cc-dd-ee-ff`, `aabb.ccdd.eeff` and `aabbccddeeff` in any case. Canonical text is lowercase and colon-separated.

Suites: parsing, comparison, arithmetic.

| Function | Signature | Notes |
| --- | --- | --- |
| `toStringHyphen`, `toStringCisco`, `toStringBare` | `Mac → String` | The other three input forms. |
| `fromInt`, `toInt` | `Int ↔ Mac` | |
| `fromBytes`, `toBytes` | `[Int] ↔ Mac` | Six bytes, most significant first. |
| `oui`, `nic` | `Mac → Int` | Upper and lower 24 bits. |
| `fromOuiNic` | `Int → Int → Mac` | Inverse of `oui` and `nic`. |
| `ouiToString` | `Int → String` | `aa:bb:cc`. |
| `isUnicast`, `isMulticast` | `Mac → Bool` | Bit 0 of the first octet clear or set. |
| `isUniversal`, `isLocal` | `Mac → Bool` | Bit 1 of the first octet clear or set. |
| `isBroadcast`, `isUnspecified` | `Mac → Bool` | All ones, all zeros. |
| `setUnicast`, `setMulticast`, `setUniversal`, `setLocal` | `Mac → Mac` | Clear or set the matching bit. |
| `toEui64` | `Mac → [Int]` | Eight bytes of modified EUI-64 (RFC 4291 §2.5.1): `ff fe` inserted, universal/local bit flipped. |

Constants: `unspecified` (`00:00:00:00:00:00`), `broadcast` (`ff:ff:ff:ff:ff:ff`).
