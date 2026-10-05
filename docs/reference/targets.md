# Targets

Endpoints are connect-side and bindpoints are bind-side ([ADR 0009](../adr/0009-endpoint-bindpoint-split.md)).

## `libnet.ipEndpoint`

Value: `{ _type = "ipEndpoint"; address = Ip; port = Port; }`. Text is `1.2.3.4:80` or `[2001:db8::1]:80`; IPv6 requires brackets and IPv4 rejects them.

Suites: parsing, comparison (by family, address, then port), address predicates.

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `Ip → Port → IpEndpoint` | |
| `address`, `port`, `version` | | Accessors. |
| `isIpv4`, `isIpv6` | `IpEndpoint → Bool` | |

## `libnet.dnsEndpoint`

Value: `{ _type = "dnsEndpoint"; address = Hostname or Domain; port = Port; }`. Text is `name:port`, never bracketed. IP literals are rejected; the address is unresolved, so there are no address predicates.

Suites: parsing, comparison (by name case-insensitively, then port).

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `DnsName → Port → DnsEndpoint` | |
| `address`, `port` | | Accessors. |
| `isHostname`, `isDomain` | `DnsEndpoint → Bool` | Kind of name held. |

## `libnet.unixSocket`

Value: `{ _type = "unixSocket"; path = String; }`: a pathname starting with `/` of at most 107 bytes, or an abstract name starting with `@` of at most 108 bytes (Linux `sun_path`). Text is the path verbatim.

Suites: parsing, comparison (byte-wise, case-sensitive).

| Function | Signature | Notes |
| --- | --- | --- |
| `path` | `UnixSocket → String` | |
| `isPathname`, `isAbstract` | `UnixSocket → Bool` | |

Constant: `sunPathMax` (`108`).

## `libnet.endpoint`

Pass-through union over `ipEndpoint`, `dnsEndpoint` and `unixSocket`. `parse` picks a Unix socket for a leading `/` or `@`, then tries an IP endpoint before a DNS endpoint.

Suites: parsing, comparison (IP, DNS, then Unix kinds; `eq` is `false` across kinds).

| Function | Signature | Notes |
| --- | --- | --- |
| `isIpEndpoint`, `isDnsEndpoint`, `isUnixSocket` | `Any → Bool` | Use the member namespace for accessors. |

## `libnet.ipBindpoint`

Value: `{ _type = "ipBindpoint"; address = Ip or null; portRange = PortRange; }`, where `null` is the wildcard. `parse` accepts `:8080`, `*:8080`, `any:8080`, `0.0.0.0:8080`, `[::]:8080`, `1.2.3.4:5000-6000` and `[::1]:5000-6000`. The first three give a `null` address and print as `:8080`; the explicit-family wildcards keep their address.

Suites: parsing, comparison (null address first, then by family, address and port range), address predicates (`false` for a null address; `toArpa` throws).

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `Ip or null → PortRange → IpBindpoint` | |
| `address`, `portRange` | | Accessors. |
| `version` | `IpBindpoint → Int or null` | `null` for a null address. |
| `isIpv4`, `isIpv6` | `IpBindpoint → Bool` | `false` for a null address. |
| `isAnyAddress`, `isWildcard` | `IpBindpoint → Bool` | Null, `0.0.0.0` or `::`. |
| `isRange` | `IpBindpoint → Bool` | More than one port. |
| `endpointAt` | `Int → IpBindpoint → IpEndpoint` | Offset into the port range. |
| `endpoints` | `IpBindpoint → [IpEndpoint]` | Throws for a null address or more than 4096 ports. |
| `endpointsUnbounded` | `IpBindpoint → [IpEndpoint]` | No size guard. |

## `libnet.bindpoint`

Pass-through union over `ipBindpoint` and `unixSocket`. `parse` picks a Unix socket for a leading `/` or `@`. DNS names, including `localhost`, are rejected.

Suites: parsing, comparison (IP before Unix kinds; `eq` is `false` across kinds).

| Function | Signature | Notes |
| --- | --- | --- |
| `isIpBindpoint`, `isUnixSocket` | `Any → Bool` | Use the member namespace for accessors. |
