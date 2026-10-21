# Interface addresses are distinct from CIDRs and interface names

An interface address and a CIDR share the text form `192.168.1.5/24` but mean different things: a CIDR names network Y, while an interface address says host X is on network Y. They are separate types, so the two values are never `eq`, and `interfaceAddress.network` derives the CIDR. This mirrors Python's `IPv4Interface` and `IPv4Network`.

A CIDR rejects host bits: `cidr.parse "10.0.0.5/24"` throws, as Python's strict `ip_network` does. Text with host bits names a host, so it parses only as an interface address. A CIDR then has one value per network, and `eq` and `toString` always agree. The interface name (`eth0`) is a third, independent type, matching how `ip addr add <address> dev <name>` keeps the two apart.
