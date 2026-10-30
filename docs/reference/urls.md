# URL forms

Every URL form is bounded: a closed scheme registry, components stored as written and never percent-decoded, and no relative or opaque URIs ([ADR 0011](../adr/0011-bounded-url-forms.md)). Every form reports an unknown scheme with the list of its schemes, such as `libnet.proxyUrl.parse: unknown scheme "ftp" (expected http, https, socks4, socks4a, socks5, or socks5h)`, and text without one as `missing '<scheme>://'`. Every form matches schemes case-insensitively and prints them lowercase; `transport` stays case-sensitive ([ADR 0012](../adr/0012-transport-enum.md)).

Hosts are case-insensitive, so every form folds its host at parse, as `regName`, `hostname` and `domain` do, and prints it in lowercase ([ADR 0020](../adr/0020-case-folded-at-parse.md)). Userinfo, path, query and fragment keep their case, except that `parse` and `make` uppercase the two hex digits of every percent-encoding (RFC 3986 §6.2.2.1), so `url.parse "http://h/a%2f"` prints `http://h/a%2F` and equals `url.parse "http://h/a%2F"`. Unix socket paths keep their case.

| Form              | Text                                               | Schemes                                                   | Holds                                    |
| ----------------- | -------------------------------------------------- | --------------------------------------------------------- | ---------------------------------------- |
| `socketUrl`       | `<scheme>://<endpoint>`                            | `sctp`, `tcp`, `udp`, `unix`                              | scheme and endpoint                      |
| `bindUrl`         | `<scheme>://<bindpoint>`                           | `sctp`, `tcp`, `udp`, `unix`                              | scheme and bindpoint                     |
| `secureSocketUrl` | `<scheme>://<endpoint>`                            | `dtls`, `quic`, `tls`                                     | scheme and endpoint                      |
| `url`             | `<scheme>://<authority>[/path][?query][#fragment]` | 30 application schemes                                    | scheme, authority, path, query, fragment |
| `proxyUrl`        | `<scheme>://<authority>`, with a port              | `http`, `https`, `socks4`, `socks4a`, `socks5`, `socks5h` | scheme and authority                     |

## Shared surface

Every URL form stores its canonical scheme and has the same scheme-derived functions:

| Function    | Signature               | Notes                                                                                     |
| ----------- | ----------------------- | ----------------------------------------------------------------------------------------- |
| `scheme`    | `X → String`            | The canonical, lowercase scheme name.                                                     |
| `transport` | `X → Transport or null` | `null` only for the `unix` scheme of a socket or bind URL.                                |
| `isSecure`  | `X → Bool`              | Whether the scheme is secure: its protocol encrypts the connection, with TLS or as `ssh`. |

Each form's `schemes` constant is a scheme registry: an attribute set from canonical scheme name to `{ transport; secure; }` of plain literals, where `transport` is a name string or `null`. `url` adds `defaultPort`, an integer. `transport` and `isSecure` read the form's own table and return a tagged `Transport` and a `Bool`.

Every form compares schemes by canonical name, then its other parts. The order is for determinism only: schemes, like transports, have no natural order.

## `libnet.socketUrl`

Value: `{ _type = "socketUrl"; scheme = "sctp" | "tcp" | "udp" | "unix"; endpoint = Endpoint; }`. The scheme is `unix` exactly when the endpoint is a Unix socket (`unix:///run/foo.sock`); otherwise the endpoint is an IP or DNS endpoint (`tcp://1.2.3.4:80`, `udp://[::1]:53`).

Suites: parsing (an unknown scheme is reported before an invalid address), comparison (by scheme, `sctp < tcp < udp < unix`, then endpoint).

| Function             | Signature                       | Notes                                                                                                        |
| -------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `make`               | `String → Endpoint → SocketUrl` | Matches the scheme case-insensitively; `unix` takes a Unix socket, every other scheme an IP or DNS endpoint. |
| `scheme`, `endpoint` |                                 | Accessors.                                                                                                   |
| `transport`          | `SocketUrl → Transport or null` | From the scheme; `null` for `unix`.                                                                          |
| `isUnix`             | `SocketUrl → Bool`              | The `unix` scheme.                                                                                           |
| `isSecure`           | `SocketUrl → Bool`              | Always `false`.                                                                                              |

Constant: `schemes`, `{ sctp = { transport = "sctp"; secure = false; }; …; unix = { transport = null; secure = false; }; }`.

## `libnet.bindUrl`

Value: `{ _type = "bindUrl"; scheme = "sctp" | "tcp" | "udp" | "unix"; bindpoint = Bindpoint; }`, coupled like `socketUrl`: `unix` exactly for a Unix socket, otherwise an IP bindpoint. It keeps the wildcard address and port range: `tcp://:8080`, `udp://0.0.0.0:53`, `tcp://[::]:8000-8100`.

Suites: parsing (an unknown scheme is reported before an invalid bind address), comparison (by scheme as in `socketUrl`, then bindpoint).

| Function              | Signature                      | Notes                                                                                                  |
| --------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------ |
| `make`                | `String → Bindpoint → BindUrl` | Matches the scheme case-insensitively; `unix` takes a Unix socket, every other scheme an IP bindpoint. |
| `scheme`, `bindpoint` |                                | Accessors.                                                                                             |
| `transport`           | `BindUrl → Transport or null`  | From the scheme; `null` for `unix`.                                                                    |
| `isUnix`              | `BindUrl → Bool`               | The `unix` scheme.                                                                                     |
| `isSecure`            | `BindUrl → Bool`               | Always `false`.                                                                                        |

Constant: `schemes`, equal to `socketUrl.schemes`.

## `libnet.secureSocketUrl`

Value: `{ _type = "secureSocketUrl"; scheme = "dtls" | "quic" | "tls"; endpoint = IpEndpoint or DnsEndpoint; }`. The port is always explicit, and there is no Unix scheme.

Suites: parsing (`parse` and `make` also accept `ssl`, an input spelling that canonicalizes to `tls`), comparison (by scheme, `dtls < quic < tls`, then endpoint; `dtls` never equals `quic`).

| Function             | Signature                                              | Notes                                           |
| -------------------- | ------------------------------------------------------ | ----------------------------------------------- |
| `make`               | `String → IpEndpoint or DnsEndpoint → SecureSocketUrl` | Accepts `ssl` for `tls`; rejects a Unix socket. |
| `scheme`, `endpoint` |                                                        | Accessors.                                      |
| `transport`          | `SecureSocketUrl → Transport`                          | `tcp` for `tls`, `udp` otherwise.               |
| `isSecure`           | `SecureSocketUrl → Bool`                               | Always `true`.                                  |

Constant: `schemes`, `{ dtls = { transport = "udp"; secure = true; }; quic = …; tls = { transport = "tcp"; secure = true; }; }`.

## `libnet.urlHost`

Pass-through union over `ip` and `regName`: a URL host is an IPv4 address, a bracketed IPv6 literal, or an RFC 3986 registered name. `parse` returns the member's own value, so `urlHost.parse "[::1]"` is an `ipv6` value and `urlHost.parse "my_host"` a `regName` value. IPs are tried first, so a dotted quad is an `ipv4` value. Other text that reads as IPv4, such as `127.1`, is neither member, so `parse` throws for it. A parse error names `urlHost.parse` and keeps the IPv4 detail for text of only digits and dots, says an unbracketed IPv6 address must be bracketed, and keeps the registered name's detail otherwise, such as `libnet.urlHost.parse: invalid registered name "bad host"`.

|           | `host`                            | `urlHost`                                      |
| --------- | --------------------------------- | ---------------------------------------------- |
| Grammar   | IP, hostname or domain (RFC 1123) | IP literal, IPv4 or registered name (RFC 3986) |
| IPv6 text | `::1`                             | `[::1]`                                        |
| Used by   | `types.host`, `urlHost.toHost`    | `authority`, `url`, `proxyUrl`                 |

Suites: parsing (`toString` brackets IPv6), comparison (IPv4, IPv6, then registered names by their folded text).

| Function    | Signature        | Notes                                                                                                                                                                                     |
| ----------- | ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `isIp`      | `Any → Bool`     | An `ipv4` or `ipv6` value.                                                                                                                                                                |
| `isRegName` | `Any → Bool`     | A `regName` value.                                                                                                                                                                        |
| `toHost`    | `UrlHost → Host` | The IP itself, or the registered name as a `dnsName` value. Throws for a registered name that is not a DNS name, such as `my_host`; guard with `dnsName.isValid (regName.toString name)`. |

## `libnet.regName`

Value: `{ _type = "regName"; value = String; }`, a non-empty RFC 3986 registered name: unreserved characters, sub-delimiters and percent-encoding, with no label structure, such as `my_host` or `a%20b`. Text whose rightmost label is numeric, meaning all digits or `0x` or `0X` followed by zero or more hex digits, is rejected, ignoring one trailing dot: `192.0.2.1`, `127.1`, `0x7f.0.0.1`, `2130706433` and `127.1.`. RFC 3986 reads only a dotted quad as an IP literal, but curl and browsers read the others as IPv4 addresses too, so `url.parse "http://127.1/"` throws ([ADR 0021](../adr/0021-no-numeric-dns-names.md)). Percent-encoded digits are not decoded for this check. `parse` folds the name to its RFC 3986 §6.2.2.1 canonical form, lowercase letters and uppercase percent-encoding hex digits, so `regName.parse "My_Host%2f"` prints `my_host%2F` ([ADR 0020](../adr/0020-case-folded-at-parse.md)).

Suites: parsing, comparison (byte-wise on the folded text).

## `libnet.authority`

Value: `{ _type = "authority"; userinfo = String or null; host = UrlHost; port = Port or null; }`. Text is `[userinfo@]host[:port]`: `example.com`, `host:8443`, `user@[::1]:443`. `userinfo` is opaque and may carry credentials; a missing port stays `null`, because an authority has no scheme default. The port rejects leading zeros (`host:0080`), although RFC 3986 allows them, so every port round-trips ([ADR 0013](../adr/0013-strict-input-canonical-output.md)).

Userinfo must match RFC 3986 `*( unreserved / pct-encoded / sub-delims / ":" )`: ASCII only, with every `%` followed by two hex digits, so `a b@h`, `a/b@h` and `%zz@h` are rejected. It keeps its case and is never percent-decoded, but `parse` and `make` uppercase the hex digits of its percent-encodings, so `a%2f@h` prints `a%2F@h` ([ADR 0011](../adr/0011-bounded-url-forms.md), [ADR 0020](../adr/0020-case-folded-at-parse.md)).

A parse error keeps the host's detail from `urlHost`, under the name of the function called, as `endpoint` keeps its member's: `authority.parse "127.1:80"` reports `libnet.authority.parse: must have 4 octets, got 2: "127.1"`, and `authority.parse ":80"` reports `libnet.authority.parse: empty host`. `url` and `proxyUrl` keep the same detail.

Suites: parsing, comparison (by host, port with `null` first, then userinfo with `null` first; `eq` includes userinfo).

| Function                   | Signature                                             | Notes                                                                                                                                       |
| -------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `make`                     | `{ host; userinfo ? null; port ? null; } → Authority` | `host` is a `UrlHost`; `userinfo` a `String` matching the userinfo grammar, or `null`; `port` a `Port` or `null`. Rejects other attributes. |
| `userinfo`, `host`, `port` |                                                       | Accessors.                                                                                                                                  |

## `libnet.url`

Value: `{ _type = "url"; scheme; authority = Authority; path; query; fragment; }`. `path` is `""` or starts with `/`; `query` and `fragment` are strings or `null`. `toString` round-trips, printing a port only when the input had one.

Each component must match its RFC 3986 grammar, in ASCII with every `%` followed by two hex digits: the path is `/`-separated segments of `pchar` (unreserved, percent-encoded, sub-delimiters, `:` and `@`), and the query and fragment are `pchar`, `/` and `?`. A space, `"`, `<`, `>`, a control character such as a newline, a non-ASCII byte, `%zz` or a second `#` is rejected. Components keep their case and are never percent-decoded; `parse` and `make` only uppercase the hex digits of percent-encodings, so `%2f` and `%2F` are one value ([ADR 0011](../adr/0011-bounded-url-forms.md)). An unknown scheme is reported with the list of every scheme in `url.schemes`.

`url.schemes` maps each scheme to `{ defaultPort; transport; secure; }`, with default ports from `registry.ports`: `amqp`, `amqps`, `coap`, `coaps`, `ftp`, `ftps`, `git`, `http`, `https`, `irc`, `ircs`, `ldap`, `ldaps`, `mongodb`, `mqtt`, `mqtts`, `mysql`, `postgres`, `rdp`, `redis`, `rsync`, `sftp`, `ssh`, `svn`, `telnet`, `tftp`, `vnc`, `ws`, `wss`, `xmpp`.

Suites: parsing, comparison. `eq` compares the scheme, the authority with its effective port, then path, query and fragment, so `https://h` equals `https://h:443` and `https://alice@h` differs from `https://bob@h`. Both `eq` and `compare` read an empty path as `/` (RFC 3986 §6.2.3), so `http://h` equals `http://h/`, while `toString` prints the path as given. `compare` orders by scheme, host, effective port, userinfo (`null` first), path, query, then fragment (`null` first).

| Function                                           | Signature                                                                | Notes                                                                                              |
| -------------------------------------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| `make`                                             | `{ scheme; authority; path ? ""; query ? null; fragment ? null; } → Url` | Validates like `parse`, so `/a#b` is not a path. A `null` authority port means the scheme default. |
| `scheme`, `authority`, `path`, `query`, `fragment` |                                                                          | Accessors.                                                                                         |
| `host`, `port`, `userinfo`                         |                                                                          | Forwarded from the authority; `port` is the explicit port or `null`.                               |
| `defaultPort`                                      | `Url → Port`                                                             | From the scheme.                                                                                   |
| `effectivePort`                                    | `Url → Port`                                                             | Explicit port, else the default.                                                                   |
| `transport`                                        | `Url → Transport`                                                        | From the scheme.                                                                                   |
| `isSecure`                                         | `Url → Bool`                                                             | From the scheme.                                                                                   |
| `toEndpoint`                                       | `Url → IpEndpoint or DnsEndpoint`                                        | Host and effective port. Throws for a registered name that is not a DNS name.                      |

`port.eq (url.effectivePort u) (url.defaultPort u)` tests whether a URL uses its scheme's default port.

## `libnet.proxyUrl`

Value: `{ _type = "proxyUrl"; scheme = String; authority = Authority; }`. The port is required: `socks5://127.0.0.1:1080`, `http://user:pass@proxy.corp:8080`. `parse` accepts a path of exactly `/` after the authority, which `toString` drops, so `http://proxy:3128/` prints `http://proxy:3128` ([ADR 0013](../adr/0013-strict-input-canonical-output.md)). Anything else after the authority, such as `/pac`, `?q`, `#f` or `//`, is rejected with `libnet.proxyUrl.parse: nothing may follow the authority: "<input>"`.

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
