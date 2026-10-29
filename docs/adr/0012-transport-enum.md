# Transport is a closed tcp/udp/sctp enum

`transport` admits exactly `tcp`, `udp` and `sctp`, the common port-bearing transport-layer protocols. DCCP and UDP-Lite are omitted, ICMP is a network-layer protocol (see `registry.icmpTypes`), QUIC runs over UDP, and Unix sockets have no transport. The name says "transport" rather than "proto" to make the layer explicit.

Parsing is case-sensitive, matching `nft`, `iptables` and `/etc/protocols`. Transport is the exception to [ADR 0020](0020-case-folded-at-parse.md): module types merge to the input string ([ADR 0016](0016-module-types-keep-strings.md)), so a case-insensitive `types.transport` would pass `"TCP"` to code that compares against `"tcp"`. Transports have no natural order, so they sort by name (`sctp < tcp < udp`) for determinism only, letting `sort` and `min` work without implying a ranking. URL forms likewise sort by canonical scheme name rather than a hand-picked scheme rank.
