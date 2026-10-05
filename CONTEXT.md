# libnet

libnet is a pure-Nix library of validated network values: addresses, networks, ports, names, connection and bind targets, and bounded URL forms. Each value is parsed from text, carries its kind, and supports the operations meaningful to that kind.

## Values

**Tagged value**:
An attribute set whose `_type` names its kind, produced by a library constructor. Every libnet value is one.
_Avoid_: object, record, struct

**Namespace**:
The attribute under `libnet` that owns one kind of value and its operations, such as `libnet.cidr`.
_Avoid_: module, family (when meaning the namespace)

**Family**:
The IP version of an address-bearing value: IPv4 or IPv6.
_Avoid_: version (except for the `version` accessor), protocol

**Pass-through union**:
A namespace that accepts several kinds and returns the member's own tagged value, adding no tag of its own: `ip`, `dnsName`, `host`, `endpoint`, `bindpoint`.
_Avoid_: sum type, wrapper

**Canonical text**:
The single text form a value's `toString` emits, such as RFC 5952 IPv6 or the colon-separated lowercase MAC.
_Avoid_: normalized string, pretty form

## Addresses

**Address**:
A single IPv4 or IPv6 address.
_Avoid_: IP (as a noun for the value), host

**MAC address**:
A 48-bit IEEE 802 hardware address (EUI-48).
_Avoid_: hardware address, ethernet address

**OUI** and **NIC**:
The upper and lower 24 bits of a MAC address: the organization identifier and the device-specific part.

**Modified EUI-64**:
The 64-bit IPv6 interface identifier derived from a MAC address per RFC 4291, with `ff:fe` inserted and the universal/local bit flipped.

**Bogon**:
An address that is not globally routable because a special-purpose RFC block contains it.
_Avoid_: martian, reserved address

**Global address**:
An address that is publicly routable. For IPv6 this also excludes the IPv4 transition forms.
_Avoid_: public address

## Networks

**CIDR**:
A network block written `address/prefix`. Its address may keep host bits; its canonical form zeros them.
_Avoid_: subnet (as the type name), netblock, network (as the type name)

**Prefix**:
The number of leading network bits in a CIDR or interface address.
_Avoid_: mask length, netmask (which is the address form of the prefix)

**Usable host**:
An address in a CIDR between its first and last host, excluding the network and broadcast addresses where the family and prefix reserve them.
_Avoid_: host (the `host` namespace means address-or-name)

**IP range**:
A contiguous, same-family span of addresses from one address to another, with no alignment constraint.
_Avoid_: address pool, range (unqualified)

**Interface address**:
A host address together with the prefix of the network it sits on, host bits preserved: "host X is on network Y".
_Avoid_: interface, CIDR (when the host bits matter)

**Interface name**:
A Linux network interface name such as `eth0`, valid under the kernel's `dev_valid_name` rules.
_Avoid_: interface, device, NIC

## Ports and transports

**Port**:
A transport-layer port number from 0 to 65535, classified as well-known, registered or dynamic per RFC 6335.

**Port range**:
A contiguous span of ports, possibly a single port.
_Avoid_: port list, port set

**Transport**:
One of the port-bearing transport-layer protocols `tcp`, `udp` and `sctp`.
_Avoid_: protocol, proto, L4

## Names

**Hostname**:
A single RFC 1123 label of 1 to 63 characters, the shape of a Linux kernel hostname.
_Avoid_: host, short name

**Domain**:
A DNS name of two or more labels, at most 253 characters.
_Avoid_: FQDN, zone

**DNS name**:
A hostname or a domain, never an IP literal.
_Avoid_: name (unqualified)

**Host**:
An address or a DNS name: the thing a client can be pointed at.
_Avoid_: target, server

**URL host**:
The host component of a URL authority under RFC 3986: an IP literal or a looser registered name with no DNS label structure.
_Avoid_: host (when the URL grammar applies)

## Targets

**Endpoint**:
A complete connection target answering "connect to where?": an IP endpoint, a DNS endpoint or a Unix socket. It never holds a wildcard or a port range.
_Avoid_: address, destination, socket address

**IP endpoint**:
An address and a port, such as `[::1]:443`.

**DNS endpoint**:
A DNS name and a port, such as `pool.ntp.org:123`; its address is unresolved.

**Unix socket**:
A Unix domain socket path, either a pathname (`/run/foo.sock`) or an abstract name (`@foo`). It is a complete target with no port and serves both connect and bind.
_Avoid_: socket path, UDS

**Bindpoint**:
A local bind target answering "bind where?": an IP bindpoint or a Unix socket. It carries what `bind(2)` takes, never a transport or a DNS name.
_Avoid_: listen address, listener

**IP bindpoint**:
An optional address and a port range, such as `:8080` or `[::1]:5000-6000`.

**Wildcard address**:
An IP bindpoint address meaning "every local interface": absent, `*`, `any`, `0.0.0.0` or `[::]`.
_Avoid_: any address, unspecified (which names the address `0.0.0.0` / `::` itself)

## URL forms

**Socket URL**:
An endpoint tagged with a transport, `<scheme>://<endpoint>`, such as `tcp://1.2.3.4:80` or `unix:///run/foo.sock`.

**Bind URL**:
A bindpoint tagged with a transport, `<scheme>://<bindpoint>`, such as `tcp://:8080`: the bind-side peer of a socket URL.

**Secure socket URL**:
A TLS-secured socket URL whose scheme is `tls`, `dtls` or `quic` (`ssl` is an alias of `tls`).

**URL**:
An absolute hierarchical URL over a closed scheme registry, with components stored verbatim.
_Avoid_: URI, link

**Authority**:
The `[userinfo@]host[:port]` component of a URL, usable on its own.

**Proxy URL**:
A proxy server address, `<scheme>://<authority>`, with an HTTP or SOCKS scheme and a required port.

**Scheme registry**:
The closed set of schemes a URL form accepts, with any per-scheme facts such as a default port or transport.

## Link and IP scalars

**Bounded integer**:
A tagged integer restricted to a protocol-defined range and built with `fromInt`: VLAN ID, MTU and ICMP type.

**VLAN ID**:
An IEEE 802.1Q VLAN identifier from 1 to 4094.

**MTU**:
An IP maximum transmission unit from 68 to 65535 bytes.

**ICMP type**:
The 8-bit message type of an ICMP or ICMPv6 message, shared by both families.

## Integration

**Registry**:
Static lookup tables of plain literals: bogon CIDRs, well-known service ports and ICMP type numbers.
_Avoid_: constants, database

**Module type**:
A NixOS option type for a libnet kind, available only through `libnet.withLib lib`.
_Avoid_: option type (unqualified), NixOS type
