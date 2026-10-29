# Ports and transports

## `libnet.port`

A [bounded integer](bounded-integers.md) in `[0, 65535]`: `{ _type = "port"; value = Int; }`. That page documents the functions every bounded integer shares; ports add the RFC 6335 classes below.

| Function       | Signature     | Notes                                                        |
| -------------- | ------------- | ------------------------------------------------------------ |
| `isWellKnown`  | `Port → Bool` | `0`–`1023`.                                                  |
| `isRegistered` | `Port → Bool` | `1024`–`49151`.                                              |
| `isDynamic`    | `Port → Bool` | `49152`–`65535`.                                             |
| `isReserved`   | `Port → Bool` | `0`, which is also well-known: the RFC 6335 classes overlap. |

Constants, as plain integers: `wellKnownMax` (`1023`) and `registeredMax` (`49151`), besides the bounds `lowestValue` (`0`) and `highestValue` (`65535`). Service names live in [`registry.ports`](registry.md).

## `libnet.portRange`

Value: `{ _type = "portRange"; from = Port; to = Port; }` with `from ≤ to`. `parse` accepts `8080`, `5500-6000`, and the iptables form `5500:6000`. Canonical text uses `-`, and a single port prints without one.

Suites: parsing, comparison (by `from`, then `to`).

| Function                         | Signature                                   | Notes                                            |
| -------------------------------- | ------------------------------------------- | ------------------------------------------------ |
| `make`                           | `Port → Port → PortRange`                   | Throws when `from > to`.                         |
| `fromPort`                       | `Port → PortRange`                          | A single port.                                   |
| `toStringColon`                  | `PortRange → String`                        | `from:to`.                                       |
| `from`, `to`                     | `PortRange → Port`                          |                                                  |
| `size`                           | `PortRange → Int`                           |                                                  |
| `isSingleton`                    | `PortRange → Bool`                          |                                                  |
| `contains`                       | `PortRange → Port → Bool`                   |                                                  |
| `overlaps`, `isAdjacent`         | `PortRange → PortRange → Bool`              | Symmetric.                                       |
| `isSubrangeOf`, `isSuperrangeOf` | `PortRange → PortRange → Bool`              | Subject first.                                   |
| `merge`                          | `PortRange → PortRange → PortRange or null` | Union when overlapping or adjacent, else `null`. |
| `portAt`                         | `Int → PortRange → Port`                    | Offset from `from`.                              |
| `ports`                          | `PortRange → [Port]`                        | Throws when `size` exceeds 4096.                 |
| `portsUnbounded`                 | `PortRange → [Port]`                        | No guard.                                        |

## `libnet.transport`

Value: `{ _type = "transport"; value = "tcp" | "udp" | "sctp"; }`. `parse` is case-sensitive ([ADR 0012](../adr/0012-transport-enum.md)).

Suites: parsing, comparison (by name, `sctp < tcp < udp`, for determinism only).

| Function                   | Signature          | Notes |
| -------------------------- | ------------------ | ----- |
| `isTcp`, `isUdp`, `isSctp` | `Transport → Bool` |       |

Constants: `tcp`, `udp` and `sctp` as transport values, and `values`, all three in sorted order: `[ sctp tcp udp ]`.
