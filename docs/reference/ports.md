# Ports and transports

## `libnet.port`

Value: `{ _type = "port"; value = Int; }` with `value` in `[0, 65535]`. `parse` accepts decimal digits only: no sign, whitespace or hex.

Suites: parsing, comparison, arithmetic.

| Function | Signature | Notes |
| --- | --- | --- |
| `fromInt`, `toInt` | `Int ↔ Port` | `fromInt` throws out of range. |
| `isWellKnown` | `Port → Bool` | `0`–`1023`. |
| `isRegistered` | `Port → Bool` | `1024`–`49151`. |
| `isDynamic`, `isEphemeral` | `Port → Bool` | `49152`–`65535`. |
| `isReserved` | `Port → Bool` | `0`, which is also well-known: the RFC 6335 classes overlap. |

Constants, as plain integers: `lowestValue` (`0`), `highestValue` (`65535`), `wellKnownMax` (`1023`), `registeredMax` (`49151`). Service names live in [`registry.ports`](registry.md).

## `libnet.portRange`

Value: `{ _type = "portRange"; from = Port; to = Port; }` with `from ≤ to`. `parse` accepts `8080`, `5500-6000`, and the iptables form `5500:6000`. Canonical text uses `-`, and a single port prints without one.

Suites: parsing, comparison (by `from`, then `to`).

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `Int → Int → PortRange` | Throws out of range or when `from > to`. |
| `fromPort` | `Port → PortRange` | A single port. |
| `toStringColon` | `PortRange → String` | `from:to`. |
| `from`, `to` | `PortRange → Port` | |
| `size` | `PortRange → Int` | |
| `isSingleton` | `PortRange → Bool` | |
| `contains` | `PortRange → Port → Bool` | |
| `overlaps`, `isAdjacent` | `PortRange → PortRange → Bool` | Symmetric. |
| `isSubrangeOf`, `isSuperrangeOf` | `PortRange → PortRange → Bool` | Subject first. |
| `merge` | `PortRange → PortRange → PortRange or null` | Union when overlapping or adjacent, else `null`. |
| `portAt` | `Int → PortRange → Port` | Offset from `from`. |
| `ports` | `PortRange → [Port]` | Throws when `size` exceeds 4096. |
| `portsUnbounded` | `PortRange → [Port]` | No guard. |

## `libnet.transport`

Value: `{ _type = "transport"; value = "tcp" | "udp" | "sctp"; }`. `parse` is case-sensitive ([ADR 0012](../adr/0012-transport-enum.md)).

Suites: parsing. Comparison is `eq` only.

| Function | Signature | Notes |
| --- | --- | --- |
| `isTcp`, `isUdp`, `isSctp` | `Transport → Bool` | |

Constants: `tcp`, `udp` and `sctp` as transport values, and `values`, the list of name strings.
