# URL forms

Every URL form is bounded: a closed scheme registry, components stored verbatim, and no relative or opaque URIs ([ADR 0011](../adr/0011-bounded-url-forms.md)). Every form matches schemes case-insensitively and prints them lowercase; `transport` stays case-sensitive ([ADR 0012](../adr/0012-transport-enum.md)).

Hosts are case-insensitive, so every form folds its host at parse, as `regName`, `hostname` and `domain` do, and prints it in lowercase ([ADR 0020](../adr/0020-case-folded-at-parse.md)). Userinfo, path, query, fragment and Unix socket paths keep their case.

| Form              | Text                                               | Schemes                                                   | Holds                                    |
| ----------------- | -------------------------------------------------- | --------------------------------------------------------- | ---------------------------------------- |
| `socketUrl`       | `<scheme>://<endpoint>`                            | `sctp`, `tcp`, `udp`, `unix`                              | transport and endpoint                   |
| `bindUrl`         | `<scheme>://<bindpoint>`                           | `sctp`, `tcp`, `udp`, `unix`                              | transport and bindpoint                  |
| `secureSocketUrl` | `<scheme>://<endpoint>`                            | `dtls`, `quic`, `tls`                                     | scheme and endpoint                      |
| `url`             | `<scheme>://<authority>[/path][?query][#fragment]` | 30 application schemes                                    | scheme, authority, path, query, fragment |
| `proxyUrl`        | `<scheme>://<authority>`, with a port              | `http`, `https`, `socks4`, `socks4a`, `socks5`, `socks5h` | scheme and authority                     |

## Shared surface

Every URL form has the same scheme-derived functions:

| Function    | Signature               | Notes                                        |
| ----------- | ----------------------- | -------------------------------------------- |
| `scheme`    | `X → String`            | The canonical, lowercase scheme name.        |
| `transport` | `X → Transport or null` | `null` only for a `unix` socket or bind URL. |
| `isSecure`  | `X → Bool`              | Whether the scheme implies TLS.              |

Each form's `schemes` constant is a scheme registry: an attribute set from canonical scheme name to `{ transport; secure; }` of plain literals, where `transport` is a name string or `null`. `url` adds `defaultPort`, an integer. `transport` and `isSecure` read the form's own table and return a tagged `Transport` and a `Bool`.

Every form compares schemes by canonical name, then its other parts. The order is for determinism only: schemes, like transports, have no natural order.

## `libnet.socketUrl`

Value: `{ _type = "socketUrl"; transport = Transport or null; endpoint = Endpoint; }`. `transport` is `null` exactly when the endpoint is a Unix socket (`unix:///run/foo.sock`); otherwise the endpoint is an IP or DNS endpoint (`tcp://1.2.3.4:80`, `udp://[::1]:53`).

Suites: parsing, comparison (by scheme, `sctp < tcp < udp < unix`, then endpoint).

| Function                | Signature                                  | Notes                                 |
| ----------------------- | ------------------------------------------ | ------------------------------------- |
| `make`                  | `Transport or null → Endpoint → SocketUrl` | Enforces the transport/Unix coupling. |
| `transport`, `endpoint` |                                            | Accessors.                            |
| `scheme`                | `SocketUrl → String`                       | `unix` when `transport` is `null`.    |
| `isUnix`                | `SocketUrl → Bool`                         |                                       |
| `isSecure`              | `SocketUrl → Bool`                         | Always `false`.                       |

Constant: `schemes`, `{ sctp = { transport = "sctp"; secure = false; }; …; unix = { transport = null; secure = false; }; }`.

## `libnet.bindUrl`

Value: `{ _type = "bindUrl"; transport = Transport or null; bindpoint = Bindpoint; }`, coupled like `socketUrl`. It keeps the wildcard address and port range: `tcp://:8080`, `udp://0.0.0.0:53`, `tcp://[::]:8000-8100`.

Suites: parsing, comparison (by scheme as in `socketUrl`, then bindpoint).

| Function                 | Signature                                 | Notes                                 |
| ------------------------ | ----------------------------------------- | ------------------------------------- |
| `make`                   | `Transport or null → Bindpoint → BindUrl` | Enforces the transport/Unix coupling. |
| `transport`, `bindpoint` |                                           | Accessors.                            |
| `scheme`                 | `BindUrl → String`                        | `unix` when `transport` is `null`.    |
| `isUnix`                 | `BindUrl → Bool`                          |                                       |
| `isSecure`               | `BindUrl → Bool`                          | Always `false`.                       |

Constant: `schemes`, equal to `socketUrl.schemes`.

## `libnet.secureSocketUrl`

Value: `{ _type = "secureSocketUrl"; scheme = "dtls" | "quic" | "tls"; endpoint = IpEndpoint or DnsEndpoint; }`. The port is always explicit, and there is no Unix scheme.

Suites: parsing (`parse` and `make` also accept `ssl`, an input spelling that canonicalizes to `tls`), comparison (by scheme, `dtls < quic < tls`, then endpoint; `dtls` never equals `quic`).

| Function             | Signature                             | Notes                                           |
| -------------------- | ------------------------------------- | ----------------------------------------------- |
| `make`               | `String → Endpoint → SecureSocketUrl` | Accepts `ssl` for `tls`; rejects a Unix socket. |
| `scheme`, `endpoint` |                                       | Accessors.                                      |
| `transport`          | `SecureSocketUrl → Transport`         | `tcp` for `tls`, `udp` otherwise.               |
| `isSecure`           | `SecureSocketUrl → Bool`              | Always `true`.                                  |

Constant: `schemes`, `{ dtls = { transport = "udp"; secure = true; }; quic = …; tls = { transport = "tcp"; secure = true; }; }`.

## `libnet.urlHost`

Pass-through union over `ip` and `regName`: a URL host is an IPv4 address, a bracketed IPv6 literal, or an RFC 3986 registered name. `parse` returns the member's own value, so `urlHost.parse "[::1]"` is an `ipv6` value and `urlHost.parse "my_host"` a `regName` value. IPs are tried first, so a dotted quad is an `ipv4` value. Other text that reads as IPv4, such as `127.1`, is neither member, so `parse` throws for it.

|           | `host`                            | `urlHost`                                      |
| --------- | --------------------------------- | ---------------------------------------------- |
| Grammar   | IP, hostname or domain (RFC 1123) | IP literal, IPv4 or registered name (RFC 3986) |
| IPv6 text | `::1`                             | `[::1]`                                        |
| Used by   | targets, interface addresses      | `authority`, `url`, `proxyUrl`                 |

Suites: parsing (`toString` brackets IPv6), comparison (IPv4, IPv6, then registered names by their folded text).

| Function    | Signature                | Notes                                                |
| ----------- | ------------------------ | ---------------------------------------------------- |
| `isIp`      | `Any → Bool`             | An `ipv4` or `ipv6` value.                           |
| `isRegName` | `Any → Bool`             | A `regName` value.                                   |
| `toHost`    | `UrlHost → Host or null` | `null` for a registered name that is not a DNS name. |

## `libnet.regName`

Value: `{ _type = "regName"; value = String; }`, a non-empty RFC 3986 registered name: unreserved characters, sub-delimiters and percent-encoding, with no label structure, such as `my_host` or `a%20b`. Text whose rightmost label is numeric, meaning all digits or `0x` or `0X` followed by zero or more hex digits, is rejected, ignoring one trailing dot: `192.0.2.1`, `127.1`, `0x7f.0.0.1`, `2130706433` and `127.1.`. RFC 3986 reads only a dotted quad as an IP literal, but curl and browsers read the others as IPv4 addresses too, so `url.parse "http://127.1/"` throws ([ADR 0021](../adr/0021-no-numeric-dns-names.md)). Percent-encoded digits are not decoded for this check. `parse` folds the name to its RFC 3986 §6.2.2.1 canonical form, lowercase letters and uppercase percent-encoding hex digits, so `regName.parse "My_Host%2f"` prints `my_host%2F` ([ADR 0020](../adr/0020-case-folded-at-parse.md)).

Suites: parsing, comparison (byte-wise on the folded text).

## `libnet.authority`

Value: `{ _type = "authority"; userinfo = String or null; host = UrlHost; port = Port or null; }`. Text is `[userinfo@]host[:port]`: `example.com`, `host:8443`, `user@[::1]:443`. `userinfo` is opaque and may carry credentials; a missing port stays `null`, because an authority has no scheme default. The port rejects leading zeros (`host:0080`), although RFC 3986 allows them, so every port round-trips ([ADR 0013](../adr/0013-strict-input-canonical-output.md)).

Suites: parsing, comparison (by host, port with `null` first, then userinfo with `null` first; `eq` includes userinfo and ignores host case).

| Function                   | Signature                                             | Notes                                             |
| -------------------------- | ----------------------------------------------------- | ------------------------------------------------- |
| `make`                     | `{ host; userinfo ? null; port ? null; } → Authority` | `host` is a `UrlHost`; `port` a `Port` or `null`. |
| `userinfo`, `host`, `port` |                                                       | Accessors.                                        |

## `libnet.url`

Value: `{ _type = "url"; scheme; authority = Authority; path; query; fragment; }`. `path` is `""` or starts with `/`; `query` and `fragment` are strings or `null`. `toString` round-trips, printing a port only when the input had one.

`url.schemes` maps each scheme to `{ defaultPort; transport; secure; }`, with default ports from `registry.ports`: `amqp`, `amqps`, `coap`, `coaps`, `ftp`, `ftps`, `git`, `http`, `https`, `irc`, `ircs`, `ldap`, `ldaps`, `mongodb`, `mqtt`, `mqtts`, `mysql`, `postgres`, `rdp`, `redis`, `rsync`, `sftp`, `ssh`, `svn`, `telnet`, `tftp`, `vnc`, `ws`, `wss`, `xmpp`.

Suites: parsing, comparison. `eq` compares the scheme, the authority with its effective port, then path, query and fragment, so `https://h` equals `https://h:443` and `https://alice@h` differs from `https://bob@h`. `compare` orders by scheme, host, effective port, userinfo (`null` first), path, query, then fragment (`null` first).

| Function                                           | Signature                                                                | Notes                                                                         |
| -------------------------------------------------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| `make`                                             | `{ scheme; authority; path ? ""; query ? null; fragment ? null; } → Url` | A `null` authority port means the scheme default.                             |
| `scheme`, `authority`, `path`, `query`, `fragment` |                                                                          | Accessors.                                                                    |
| `host`, `port`, `userinfo`                         |                                                                          | Forwarded from the authority; `port` is the explicit port or `null`.          |
| `defaultPort`                                      | `Url → Port`                                                             | From the scheme.                                                              |
| `effectivePort`                                    | `Url → Port`                                                             | Explicit port, else the default.                                              |
| `transport`                                        | `Url → Transport`                                                        | From the scheme.                                                              |
| `isSecure`                                         | `Url → Bool`                                                             | From the scheme.                                                              |
| `toEndpoint`                                       | `Url → IpEndpoint or DnsEndpoint`                                        | Host and effective port. Throws for a registered name that is not a DNS name. |

`port.eq (url.effectivePort u) (url.defaultPort u)` tests whether a URL uses its scheme's default port.

## `libnet.proxyUrl`

Value: `{ _type = "proxyUrl"; scheme = String; authority = Authority; }`. The port is required, and nothing may follow the authority: `socks5://127.0.0.1:1080`, `http://user:pass@proxy.corp:8080`.

Suites: parsing, comparison (by scheme, then authority; `socks5` never equals `socks5h`).

| Function                   | Signature                              | Notes                                                                       |
| -------------------------- | -------------------------------------- | --------------------------------------------------------------------------- |
| `make`                     | `String → Authority → ProxyUrl`        | Requires a port.                                                            |
| `scheme`, `authority`      |                                        | Accessors.                                                                  |
| `host`, `port`, `userinfo` |                                        | Forwarded from the authority.                                               |
| `transport`                | `ProxyUrl → Transport`                 | Always `tcp`.                                                               |
| `isSecure`                 | `ProxyUrl → Bool`                      | `true` only for `https`; every other scheme reaches the proxy in plaintext. |
| `toEndpoint`               | `ProxyUrl → IpEndpoint or DnsEndpoint` | Host and port. Throws for a registered name that is not a DNS name.         |

Constant: `schemes`, `{ http = { transport = "tcp"; secure = false; }; https = { transport = "tcp"; secure = true; }; socks4 = …; }`.
