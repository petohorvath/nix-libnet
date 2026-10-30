# Registry

`libnet.registry` holds plain literals, not libnet values; lift entries with `cidr.parse` or `port.fromInt` as needed.

| Attribute                          | Shape             | Contents                                                                                                                                 |
| ---------------------------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `bogons.ipv4`, `bogons.ipv6`       | `[String]`        | The bogon space as CIDR text: IANA special-purpose blocks not globally reachable as of 2025-10-09, plus multicast and deprecated blocks. |
| `ports.tcp`, `ports.udp`           | `{ name = Int; }` | Common service ports; the source of `url` default ports.                                                                                 |
| `icmpTypes.ipv4`, `icmpTypes.ipv6` | `{ name = Int; }` | Curated ICMP and ICMPv6 message types.                                                                                                   |

A service on both protocols has the same number under each key. Port 853 is the exception by name: `tcp.dnsTls` (RFC 7858) and `udp.dnsQuic` (RFC 9250).

`bogons` covers the same space as `isBogon` but splits it differently: a block with a reachable allocation carved out, such as `192.0.0.0/24` without `192.0.0.9` and `192.0.0.10`, is listed as the fewest CIDR blocks that cover the rest. Tests keep the two in step ([ADR 0014](../adr/0014-address-classification.md)).
