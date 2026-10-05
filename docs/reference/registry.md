# Registry

`libnet.registry` holds plain literals, not libnet values; lift entries with `cidr.parse` or `port.fromInt` as needed.

| Attribute | Shape | Contents |
| --- | --- | --- |
| `bogons.ipv4`, `bogons.ipv6` | `[String]` | RFC 6890 special-purpose blocks as CIDR text. |
| `ports.tcp`, `ports.udp` | `{ name = Int; }` | Common service ports; the source of `url` default ports. |
| `icmpTypes.ipv4`, `icmpTypes.ipv6` | `{ name = Int; }` | Curated ICMP and ICMPv6 message types. |

A service on both protocols has the same number under each key. Port 853 is the exception by name: `tcp.dnsTls` (RFC 7858) and `udp.dnsQuic` (RFC 9250).

`bogons` covers the same space as `isBogon` but splits it differently; tests keep the two in step ([ADR 0014](../adr/0014-address-classification.md)).
