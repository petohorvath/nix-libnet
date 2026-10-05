# URL forms

Every URL form is bounded: a closed scheme registry, components stored verbatim, and no relative or opaque URIs ([ADR 0011](../adr/0011-bounded-url-forms.md)). `secureSocketUrl`, `url` and `proxyUrl` match schemes case-insensitively and print them lowercase; `socketUrl` and `bindUrl` require lowercase, like `transport`.

| Form | Text | Schemes | Holds |
| --- | --- | --- | --- |
| `socketUrl` | `<scheme>://<endpoint>` | `tcp`, `udp`, `sctp`, `unix` | transport and endpoint |
| `bindUrl` | `<scheme>://<bindpoint>` | `tcp`, `udp`, `sctp`, `unix` | transport and bindpoint |
| `secureSocketUrl` | `<scheme>://<endpoint>` | `tls` (alias `ssl`), `dtls`, `quic` | scheme and endpoint |
| `url` | `<scheme>://[userinfo@]host[:port][/path][?query][#fragment]` | 30 application schemes | scheme, authority parts, path, query, fragment |
| `proxyUrl` | `<scheme>://[userinfo@]host:port` | `http`, `https`, `socks4`, `socks4a`, `socks5`, `socks5h` | scheme and authority |

## `libnet.socketUrl`

Value: `{ _type = "socketUrl"; transport = Transport or null; endpoint = Endpoint; }`. `transport` is `null` exactly when the endpoint is a Unix socket (`unix:///run/foo.sock`); otherwise the endpoint is an IP or DNS endpoint (`tcp://1.2.3.4:80`, `udp://[::1]:53`).

Suites: parsing, comparison (by scheme rank `tcp < udp < sctp < unix`, then endpoint).

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `Transport or null → Endpoint → SocketUrl` | Enforces the transport/Unix coupling. |
| `transport`, `endpoint` | | Accessors. |
| `isUnix` | `SocketUrl → Bool` | |

Constant: `schemes`, the list of scheme names.

## `libnet.bindUrl`

Value: `{ _type = "bindUrl"; transport = Transport or null; bindpoint = Bindpoint; }`, coupled like `socketUrl`. It keeps the wildcard address and port range: `tcp://:8080`, `udp://0.0.0.0:53`, `tcp://[::]:8000-8100`.

Suites: parsing, comparison (scheme rank as in `socketUrl`, then bindpoint).

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `Transport or null → Bindpoint → BindUrl` | Enforces the transport/Unix coupling. |
| `transport`, `bindpoint` | | Accessors. |
| `isUnix` | `BindUrl → Bool` | |

Constant: `schemes`.

## `libnet.secureSocketUrl`

Value: `{ _type = "secureSocketUrl"; scheme = "tls" | "dtls" | "quic"; endpoint = IpEndpoint or DnsEndpoint; }`. `ssl` parses as `tls`. The port is always explicit, and there is no Unix scheme.

Suites: parsing, comparison (by scheme rank `tls < dtls < quic`, then endpoint; `dtls` never equals `quic`).

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `String → Endpoint → SecureSocketUrl` | Resolves aliases; rejects a Unix socket. |
| `scheme`, `endpoint` | | Accessors. |
| `transport` | `SecureSocketUrl → Transport` | `tcp` for `tls`, `udp` otherwise. |
| `isSecure` | `SecureSocketUrl → Bool` | Always `true`. |

Constants: `schemes` (`{ tls = { transport = "tcp"; }; … }`), `aliases` (`{ ssl = "tls"; }`).

## `libnet.urlHost`

Value: `{ _type = "urlHost"; kind = "ip" | "regName"; ip = Ip or null; name = String or null; }`. A URL host is an IPv4 address, a bracketed IPv6 literal, or an RFC 3986 registered name, which admits `_`, `~`, sub-delimiters and percent-encoding with no label structure.

| | `host` | `urlHost` |
| --- | --- | --- |
| Grammar | IP, hostname or domain (RFC 1123) | IP literal, IPv4 or registered name (RFC 3986) |
| IPv6 text | `::1` | `[::1]` |
| Used by | targets, interface addresses | `url`, `authority` |

Suites: parsing (`toString` re-brackets IPv6), comparison (IP literals before registered names; names case-insensitive).

| Function | Signature | Notes |
| --- | --- | --- |
| `isIp`, `isRegName` | `UrlHost → Bool` | |
| `toHost` | `UrlHost → Host or null` | `null` for a registered name that is not a DNS name. |

Constant: `regNamePattern`.

## `libnet.authority`

Value: `{ _type = "authority"; userinfo = String or null; host = UrlHost; port = Port or null; }`. Text is `[userinfo@]host[:port]`: `example.com`, `host:8443`, `user@[::1]:443`. `userinfo` is opaque and may carry credentials; a missing port stays `null`, because an authority has no scheme default.

Suites: parsing, comparison (by host, port with `null` first, then userinfo; `eq` includes userinfo and ignores host case).

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `{ host; userinfo ? null; port ? null; } → Authority` | `host` is a string; `port` an integer or `null`. |
| `userinfo`, `host`, `port` | | Accessors. |

## `libnet.url`

Value: `{ _type = "url"; scheme; userinfo; host = UrlHost; port = Port or null; path; query; fragment; }`. `path` is `""` or starts with `/`; `query` and `fragment` are strings or `null`. The authority is parsed by `authority` and stored flat. `toString` round-trips, printing a port only when the input had one.

`url.schemes` maps each scheme to `{ defaultPort; transport; secure; }`, with default ports from `registry.ports`: `amqp`, `amqps`, `coap`, `coaps`, `ftp`, `ftps`, `git`, `http`, `https`, `irc`, `ircs`, `ldap`, `ldaps`, `mongodb`, `mqtt`, `mqtts`, `mysql`, `postgres`, `rdp`, `redis`, `rsync`, `sftp`, `ssh`, `svn`, `telnet`, `tftp`, `vnc`, `ws`, `wss`, `xmpp`.

Suites: parsing, comparison (by scheme, host, effective port, path, query, then fragment; `eq` ignores userinfo and host case, so `https://h` equals `https://h:443`).

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `{ scheme; host; port ? null; userinfo ? null; path ? ""; query ? null; fragment ? null; } → Url` | `host` is a string; `port` an integer or `null`. |
| `scheme`, `userinfo`, `host`, `port`, `path`, `query`, `fragment` | | Accessors; `port` is the explicit port or `null`. |
| `defaultPort` | `Url → Int` | From the scheme. |
| `effectivePort` | `Url → Port` | Explicit port, else the default. |
| `transport` | `Url → Transport` | From the scheme. |
| `isSecure` | `Url → Bool` | From the scheme. |
| `toEndpoint` | `Url → IpEndpoint or DnsEndpoint` | Host and effective port. Throws for a registered name that is not a DNS name. |

## `libnet.proxyUrl`

Value: `{ _type = "proxyUrl"; scheme = String; authority = Authority; }`. The port is required, and nothing may follow the authority: `socks5://127.0.0.1:1080`, `http://user:pass@proxy.corp:8080`.

Suites: parsing, comparison (by scheme rank in `schemes` order, then authority; `socks5` never equals `socks5h`).

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `String → Authority → ProxyUrl` | Requires a port. |
| `scheme`, `authority` | | Accessors. |
| `isSecure` | `ProxyUrl → Bool` | `true` only for `https`; every other scheme reaches the proxy in plaintext. |

Constant: `schemes`.
