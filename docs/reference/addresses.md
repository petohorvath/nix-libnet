# Addresses

Every function on this page except `is`, `ip.isIpv4`, `ip.isIpv6`, `eq`, `isValid` and `tryParse` throws `libnet.<ns>.<fn>: expected <kind>, got <kind>` for an argument of the wrong kind. `ipv4` and `ipv6` accept only their own family, so `ipv4.compare` and `ipv4.lt` throw for an IPv6 value; `ip` accepts both and orders IPv4 before IPv6.

`add`, `sub`, `next` and `prev` throw for a non-integer offset, and for any offset whose result leaves the address space, checked before any arithmetic so that an offset near the integer limits cannot overflow. Errors name the function called, such as `libnet.ipv4.next: out of range: 255.255.255.255 + 1`.

`fromBytes`, `fromWords` and `fromGroups` throw for a non-list, a list of the wrong length, and an element that is not an integer in range, such as `libnet.ipv4.fromBytes: byte out of range [0, 255]: 256`.

`isBogon` and `isGlobal` follow the "Globally Reachable" column of IANA's IPv4 and IPv6 special-purpose address registries as of 2025-10-09 ([ADR 0014](../adr/0014-address-classification.md)). A block marked not reachable is a bogon with a named predicate, and a reachable allocation inside it is carved out and stays global. Multicast and the deprecated blocks are bogons too. The IPv6 transition forms are neither bogons nor global.

## `libnet.ipv4`

Value: `{ _type = "ipv4"; value = Int; }` with `value` in `[0, 2³² − 1]`. Canonical text is the dotted quad. `parse` rejects leading zeros, octets above 255, and any count other than four octets.

Suites: parsing, comparison, arithmetic (`next` throws at `255.255.255.255`, `prev` at `0.0.0.0`).

| Function               | Signature       | Notes                                                    |
| ---------------------- | --------------- | -------------------------------------------------------- |
| `fromInt`, `toInt`     | `Int ↔ Ipv4`    | `fromInt` throws for a non-integer or out of range.      |
| `fromBytes`, `toBytes` | `[Int] ↔ Ipv4`  | Four bytes (the RFC 791 octets), most significant first. |
| `toArpa`               | `Ipv4 → String` | `1.2.3.4` → `4.3.2.1.in-addr.arpa`.                      |

Constants: `unspecified` (`0.0.0.0`), `broadcast` (`255.255.255.255`), `loopback` (`127.0.0.1`).

Predicates, each `Ipv4 → Bool`:

| Predicate              | Block                                                         |
| ---------------------- | ------------------------------------------------------------- |
| `isLoopback`           | `127.0.0.0/8`                                                 |
| `isPrivate`            | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` (RFC 1918)    |
| `isLinkLocal`          | `169.254.0.0/16`                                              |
| `isMulticast`          | `224.0.0.0/4`                                                 |
| `isBroadcast`          | `255.255.255.255`                                             |
| `isUnspecified`        | `0.0.0.0`                                                     |
| `isReserved`           | `240.0.0.0/4` except the broadcast address                    |
| `isDocumentation`      | `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`           |
| `isThisNetwork`        | `0.0.0.0/8` (RFC 1122)                                        |
| `isSharedAddressSpace` | `100.64.0.0/10` (RFC 6598)                                    |
| `isProtocolAssignment` | `192.0.0.0/24` (RFC 6890) except `192.0.0.9` and `192.0.0.10` |
| `isBenchmarking`       | `198.18.0.0/15` (RFC 2544)                                    |
| `is6to4Relay`          | `192.88.99.0/24` (RFC 7526, deprecated)                       |
| `isBogon`              | Any predicate above                                           |
| `isGlobal`             | `!isBogon`                                                    |

## `libnet.ipv6`

Value: `{ _type = "ipv6"; words = [Int Int Int Int]; }`, four 32-bit words with the most significant first; `2001:db8::1` is `[ 536939960 0 0 1 ]`. `parse` accepts compression, mixed case, and embedded IPv4 (`::ffff:1.2.3.4`). A parse error names the first empty or invalid group or IPv4 part, or else the wrong group count: `ipv6.parse "gggg::"` throws `libnet.ipv6.parse: invalid group "gggg" in "gggg::"`, and `ipv6.parse "1:2:3:4:5:6:7"` throws `libnet.ipv6.parse: must have 8 groups, got 7: "1:2:3:4:5:6:7"`. Canonical text follows RFC 5952.

Suites: parsing, comparison (ordered by words), arithmetic (carry and borrow cross words; `diff` throws when the result falls outside the Nix integer range `[−2⁶³, 2⁶³ − 1]`, so a difference of exactly −2⁶³ is returned). There is no `toInt` or `fromInt`.

| Function                 | Signature           | Notes                                                                                                                                                                                                   |
| ------------------------ | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `toStringExpanded`       | `Ipv6 → String`     | `2001:0db8:0000:0000:0000:0000:0000:0001`.                                                                                                                                                              |
| `toStringBracketed`      | `Ipv6 → String`     | `[2001:db8::1]`.                                                                                                                                                                                        |
| `fromWords`, `toWords`   | `[Int] ↔ Ipv6`      | Four 32-bit words.                                                                                                                                                                                      |
| `fromGroups`, `toGroups` | `[Int] ↔ Ipv6`      | Eight 16-bit groups.                                                                                                                                                                                    |
| `fromBytes`, `toBytes`   | `[Int] ↔ Ipv6`      | Sixteen bytes.                                                                                                                                                                                          |
| `toArpa`                 | `Ipv6 → String`     | 32 reversed nibbles under `ip6.arpa`.                                                                                                                                                                   |
| `fromMac`                | `Cidr → Mac → Ipv6` | Upper 64 bits from the CIDR, lower 64 from the MAC's modified EUI-64. For a prefix shorter than /64 the address lands in the block's first /64. Throws for an IPv4 CIDR and when the prefix exceeds 64. |
| `fromIpv4`               | `Ipv4 → Ipv6`       | The IPv4-mapped form (RFC 4291 §2.5.5.2): `1.2.3.4` → `::ffff:1.2.3.4`.                                                                                                                                 |
| `toIpv4`                 | `Ipv6 → Ipv4`       | Inverse of `fromIpv4`. Throws outside `::ffff:0:0/96`.                                                                                                                                                  |

Constants: `unspecified` (`::`), `loopback` (`::1`). IPv6 has no broadcast.

Predicates, each `Ipv6 → Bool`:

| Predicate              | Block                                                                                                                                                                                    |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `isLoopback`           | `::1`                                                                                                                                                                                    |
| `isUnspecified`        | `::`                                                                                                                                                                                     |
| `isLinkLocal`          | `fe80::/10`                                                                                                                                                                              |
| `isUniqueLocal`        | `fc00::/7` (RFC 4193)                                                                                                                                                                    |
| `isMulticast`          | `ff00::/8`                                                                                                                                                                               |
| `isDocumentation`      | `2001:db8::/32`, `3fff::/20`                                                                                                                                                             |
| `isLocalNat64`         | `64:ff9b:1::/48` (RFC 8215)                                                                                                                                                              |
| `isDiscard`            | `100::/64` (RFC 6666)                                                                                                                                                                    |
| `isDummy`              | `100:0:0:1::/64` (RFC 9780)                                                                                                                                                              |
| `isProtocolAssignment` | `2001::/23` (RFC 2928) except Teredo (`2001::/32`) and the globally reachable `2001:1::1`, `2001:1::2`, `2001:1::3`, `2001:3::/32`, `2001:4:112::/48`, `2001:20::/28` and `2001:30::/28` |
| `isBenchmarking`       | `2001:2::/48` (RFC 5180)                                                                                                                                                                 |
| `isOrchid`             | `2001:10::/28` (RFC 4843, deprecated)                                                                                                                                                    |
| `isSrv6Sid`            | `5f00::/16` (RFC 9602)                                                                                                                                                                   |
| `isSiteLocal`          | `fec0::/10` (RFC 3879, deprecated)                                                                                                                                                       |
| `isIpv4Mapped`         | `::ffff:0:0/96`                                                                                                                                                                          |
| `isIpv4Compatible`     | `::0.0.0.0/96` (deprecated)                                                                                                                                                              |
| `is6to4`               | `2002::/16`                                                                                                                                                                              |
| `isTeredo`             | `2001::/32` (RFC 4380)                                                                                                                                                                   |
| `isBogon`              | Any predicate from `isLoopback` through `isSiteLocal`                                                                                                                                    |
| `isGlobal`             | Neither a bogon nor one of the four transition forms `isIpv4Mapped` through `isTeredo`                                                                                                   |

## `libnet.ip`

Pass-through union over `ipv4` and `ipv6`; `parse` picks IPv6 when the input contains `:`. A parse error names `ip.parse` and keeps the member's detail: `ip.parse "300.1.1.1"` throws `libnet.ip.parse: invalid octet in "300.1.1.1"`. Colon text that is not plausibly IPv6 names the syntax it belongs to instead: bracketed text, as in `ip.parse "[::1]"`, throws `libnet.ip.parse: "[::1]" is bracketed, which is URL and endpoint syntax`, and a host other than an IPv6 group followed by a port, as in `ip.parse "1.2.3.4:5"`, throws `libnet.ip.parse: "1.2.3.4:5" reads as host:port, which is endpoint syntax`.

Suites: parsing, comparison (IPv4 before IPv6), arithmetic (dispatched by family, with errors naming the `ip` function called; `diff` across families throws), address predicates.

| Function           | Signature    | Notes       |
| ------------------ | ------------ | ----------- |
| `version`          | `Ip → Int`   | `4` or `6`. |
| `isIpv4`, `isIpv6` | `Any → Bool` |             |

## `libnet.mac`

Value: `{ _type = "mac"; value = Int; }` with `value` in `[0, 2⁴⁸ − 1]`. `parse` accepts `aa:bb:cc:dd:ee:ff`, `aa-bb-cc-dd-ee-ff`, `aabb.ccdd.eeff` and `aabbccddeeff` in any case. Canonical text is lowercase and colon-separated.

Suites: parsing, comparison, arithmetic.

| Function                                                 | Signature         | Notes                                                                                            |
| -------------------------------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------ |
| `toStringHyphen`, `toStringCisco`, `toStringBare`        | `Mac → String`    | The other three input forms.                                                                     |
| `fromInt`, `toInt`                                       | `Int ↔ Mac`       | `fromInt` throws for a non-integer or out of range.                                              |
| `fromBytes`, `toBytes`                                   | `[Int] ↔ Mac`     | Six bytes, most significant first.                                                               |
| `oui`, `nic`                                             | `Mac → Int`       | Upper and lower 24 bits.                                                                         |
| `fromOuiNic`                                             | `Int → Int → Mac` | Inverse of `oui` and `nic`. Throws for a non-integer or out-of-range half.                       |
| `toStringOui`                                            | `Mac → String`    | The OUI as `aa:bb:cc`.                                                                           |
| `isUnicast`, `isMulticast`                               | `Mac → Bool`      | Bit 0 of the first octet clear or set.                                                           |
| `isUniversal`, `isLocal`                                 | `Mac → Bool`      | Bit 1 of the first octet clear or set.                                                           |
| `isBroadcast`, `isUnspecified`                           | `Mac → Bool`      | All ones, all zeros.                                                                             |
| `setUnicast`, `setMulticast`, `setUniversal`, `setLocal` | `Mac → Mac`       | Clear or set the matching bit.                                                                   |
| `toEui64`                                                | `Mac → [Int]`     | Eight bytes of modified EUI-64 (RFC 4291 §2.5.1): `ff fe` inserted, universal/local bit flipped. |

Constants: `unspecified` (`00:00:00:00:00:00`), `broadcast` (`ff:ff:ff:ff:ff:ff`).
