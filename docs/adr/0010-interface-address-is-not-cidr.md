# Interface addresses are distinct from CIDRs and interface names

An interface address and a CIDR share the text form `192.168.1.5/24` but mean different things: a CIDR names network Y, while an interface address says host X is on network Y. They are separate types, so the two values are never `eq`; `interfaceAddress.network` derives the canonical CIDR, and `interfaceAddress.toCidr` keeps the host bits. This mirrors Python's `IPv4Interface` and `IPv4Network`.

A CIDR may still hold host bits (`10.0.0.5/24` parses), but its `eq` compares canonical networks. The interface name (`eth0`) is a third, independent type, matching how `ip addr add <address> dev <name>` keeps the two apart.
