# Roadmap

Candidate additions, none committed. Each must stay additive and fit the existing conventions; scope limits are in [ADR 0003](adr/0003-syntax-not-resolution.md).

| Feature | Sketch |
| --- | --- |
| Deterministic address assignment | `cidr.assignIps`: stable hash-based mapping from hostnames to addresses in a pool, and a `mac.assignMacs` analog. Needs a hashing primitive. |
| Seeded local MAC | `mac.randomLocal :: String → Mac`: a stable locally administered unicast MAC from a seed. |
| IPv6 zone identifiers | Parse `fe80::1%eth0` and add a `zone` accessor. |
| Port service names | `port.serviceName :: Port → String or null`, the inverse of `registry.ports`. |
| Solicited-node multicast | `ipv6.toSolicitedNode` per RFC 4291 §2.7.1. |
| Flow | `{ transport; source; destination; }` composed from endpoints, for rule generation. |
| Route | `{ destination = Cidr; via = Ip; metric = Int; }` with validation and comparison. |
| Address block lookup | `ip.blockInfo`: name, RFC and description of the special-purpose block holding an address. |
| Large IPv6 sizes | Multi-word sizes so `size` stops throwing at 2⁶³. |

Lower-demand ideas: connection-tracking abstractions, DHCP lease and static ARP/NDP entries, constraint-based subnet partitioning, and IPv4-to-IPv6 transition tooling (6to4, Teredo, NAT64).
