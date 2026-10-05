# Transport is a closed tcp/udp/sctp enum with equality only

`transport` admits exactly `tcp`, `udp` and `sctp`, the common port-bearing transport-layer protocols. DCCP and UDP-Lite are omitted, ICMP is a network-layer protocol (see `registry.icmpTypes`), QUIC runs over UDP, and Unix sockets have no transport. The name says "transport" rather than "proto" to make the layer explicit.

Parsing is case-sensitive, matching `nft`, `iptables` and `/etc/protocols`. Transports have no natural order, so the namespace offers `eq` but no ordering. URL forms that sort by transport use their own fixed scheme rank.
