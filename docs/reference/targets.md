# Targets

Endpoints are connect-side and bindpoints are bind-side ([ADR 0009](../adr/0009-endpoint-bindpoint-split.md)).

## `libnet.ipEndpoint`

Value: `{ _type = "ipEndpoint"; address = Ip; port = Port; }`. Text is `1.2.3.4:80` or `[2001:db8::1]:80`; IPv6 requires brackets and IPv4 rejects them.

Suites: parsing, comparison (by family, address, then port), address predicates.

| Function                     | Signature                | Notes      |
| ---------------------------- | ------------------------ | ---------- |
| `make`                       | `Ip → Port → IpEndpoint` |            |
| `address`, `port`, `version` |                          | Accessors. |
| `isIpv4`, `isIpv6`           | `IpEndpoint → Bool`      |            |

## `libnet.dnsEndpoint`

Value: `{ _type = "dnsEndpoint"; name = Hostname or Domain; port = Port; }`. Text is `name:port`, never bracketed. The name is a `dnsName`, so IP literals and names that read as IPv4, such as `127.1` and `2130706433`, are rejected ([ADR 0021](../adr/0021-no-numeric-dns-names.md)). The DNS name is unresolved, so there are no address predicates.

Suites: parsing, comparison (hostnames before domains, then by name, then by port).

| Function                 | Signature                      | Notes                                                                   |
| ------------------------ | ------------------------------ | ----------------------------------------------------------------------- |
| `make`                   | `DnsName → Port → DnsEndpoint` | Throws for a name `dnsName.parse` rejects, such as the hostname `1234`. |
| `name`, `port`           |                                | Accessors.                                                              |
| `isHostname`, `isDomain` | `DnsEndpoint → Bool`           | Kind of name held.                                                      |

## `libnet.unixSocket`

Value: `{ _type = "unixSocket"; value = String; }`: a pathname starting with `/` of at most 107 bytes, or an abstract name starting with `@` of at most 108 bytes (Linux `sun_path`), with at least one character after the `/` or `@`. Text is the path verbatim; read it with `toString`.

Suites: parsing, comparison (byte-wise, case-sensitive).

| Function                   | Signature           | Notes |
| -------------------------- | ------------------- | ----- |
| `isPathname`, `isAbstract` | `UnixSocket → Bool` |       |

## `libnet.endpoint`

Pass-through union over `ipEndpoint`, `dnsEndpoint` and `unixSocket`. `parse` picks a Unix socket for a leading `/` or `@`, then tries an IP endpoint before a DNS endpoint, so `endpoint.parse "010.0.0.1:80"` throws, being neither. Its errors name `endpoint.parse`, so `endpoint.parse "@"` reports `libnet.endpoint.parse: invalid socket "@" …` with the Unix socket's detail.

Suites: parsing, comparison (IP, DNS, then Unix kinds; `eq` is `false` across kinds).

| Function                                        | Signature    | Notes                                   |
| ----------------------------------------------- | ------------ | --------------------------------------- |
| `isIpEndpoint`, `isDnsEndpoint`, `isUnixSocket` | `Any → Bool` | Use the member namespace for accessors. |

## `libnet.ipBindpoint`

Value: `{ _type = "ipBindpoint"; address = Ip or null; portRange = PortRange; }`, where `null` is the wildcard. `parse` accepts `:8080`, `*:8080`, `any:8080`, `0.0.0.0:8080`, `[::]:8080`, `1.2.3.4:5000-6000` and `[::1]:5000-6000`. The first three give a `null` address and print as `:8080`; the explicit-family wildcards keep their address.

Suites: parsing, comparison (null address first, then by family, address and port range), address predicates (`false` for a null address; `toArpa` throws).

| Function               | Signature                              | Notes                                                 |
| ---------------------- | -------------------------------------- | ----------------------------------------------------- |
| `make`                 | `Ip or null → PortRange → IpBindpoint` |                                                       |
| `address`, `portRange` |                                        | Accessors.                                            |
| `version`              | `IpBindpoint → Int or null`            | `null` for a null address.                            |
| `isIpv4`, `isIpv6`     | `IpBindpoint → Bool`                   | `false` for a null address.                           |
| `isWildcard`           | `IpBindpoint → Bool`                   | The wildcard address: null, `0.0.0.0` or `::`.        |
| `endpointAt`           | `Int → IpBindpoint → IpEndpoint`       | Index into the port range; throws for a null address. |
| `endpoints`            | `IpBindpoint → [IpEndpoint]`           | Throws for a null address or more than 4096 ports.    |
| `endpointsUnbounded`   | `IpBindpoint → [IpEndpoint]`           | No size guard; throws for a null address.             |

## `libnet.bindpoint`

Pass-through union over `ipBindpoint` and `unixSocket`. `parse` picks a Unix socket for a leading `/` or `@`. DNS names, including `localhost`, are rejected. Its errors name `bindpoint.parse` and keep the member's detail: `bindpoint.parse "x"` reports `libnet.bindpoint.parse: missing ':port' in "x"`.

Suites: parsing, comparison (IP before Unix kinds; `eq` is `false` across kinds).

| Function                        | Signature    | Notes                                   |
| ------------------------------- | ------------ | --------------------------------------- |
| `isIpBindpoint`, `isUnixSocket` | `Any → Bool` | Use the member namespace for accessors. |
