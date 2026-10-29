# Names

## `libnet.hostname`

Value: `{ _type = "hostname"; value = String; }`, one RFC 1123 label: 1–63 characters of `[A-Za-z0-9-]`, starting and ending alphanumeric. The 63-character cap is Linux's `HOST_NAME_MAX` less the terminator. Underscores are rejected ([ADR 0013](../adr/0013-strict-input-canonical-output.md)). `parse` lowercases the name, so text is the name in lowercase: `hostname.parse "MyHost"` prints `myhost` ([ADR 0020](../adr/0020-case-folded-at-parse.md)). A numeric label such as `1234` or `0x7f` is a valid Linux kernel hostname but not a DNS name, so `dnsName` rejects it, as text and as a value ([ADR 0021](../adr/0021-no-numeric-dns-names.md)).

Suites: parsing, comparison (byte-wise on the lowercase text).

## `libnet.domain`

Value: `{ _type = "domain"; value = String; }`, two or more hostname-valid labels joined by `.`, at most 253 characters, with no leading, trailing or doubled dot. The rightmost label is not numeric, meaning neither all digits nor `0x` or `0X` followed by zero or more hex digits, because a resolver reads such text as an IPv4 address: `192.0.2.1`, `127.1` and `127.1.0x1` are rejected, while `192.0.2.example` is a domain ([ADR 0021](../adr/0021-no-numeric-dns-names.md)). A domain is therefore never an `ip`. `parse` and `fromLabels` lowercase the name, so text is the name in lowercase ([ADR 0020](../adr/0020-case-folded-at-parse.md)).

Suites: parsing, comparison (byte-wise on the lowercase text).

| Function          | Signature                 | Notes                                                              |
| ----------------- | ------------------------- | ------------------------------------------------------------------ |
| `fromLabels`      | `[String] → Domain`       | Joins and validates; throws for a non-string label.                |
| `labels`          | `Domain → [String]`       | Leftmost first.                                                    |
| `parent`          | `Domain → Domain or null` | Drops the leftmost label; `null` when fewer than two would remain. |
| `isSubdomainOf`   | `Domain → Domain → Bool`  | `isSubdomainOf a b` is true when `a` is `b` or below it.           |
| `isSuperdomainOf` | `Domain → Domain → Bool`  | `isSuperdomainOf a b` is `isSubdomainOf b a`.                      |
| `toHostname`      | `Domain → Hostname`       | The leftmost label.                                                |

There is no `tld` accessor ([ADR 0003](../adr/0003-syntax-not-resolution.md)); the last element of `labels` is the rightmost label.

## `libnet.dnsName`

Pass-through union over `hostname` and `domain` that rejects IP literals and any text a resolver reads as an IPv4 address, so a numeric hostname such as `2130706433` or `0x7f` is rejected along with `127.1` ([ADR 0021](../adr/0021-no-numeric-dns-names.md)). `parse` picks by label count. A numeric hostname value, such as `hostname.parse "1234"`, is the wrong kind: `is` and `isHostname` are `false` for it, `eq` returns `false`, and the functions that take a DNS name, here and in `host` and `dnsEndpoint`, throw `expected hostname or domain value, got numeric hostname "1234", which reads as an IPv4 address`. A parse error names `dnsName.parse` and keeps the domain's detail for text with a dot and the hostname's otherwise, such as `libnet.dnsName.parse: invalid hostname "host_name" …`.

Suites: parsing, comparison (hostnames before domains, then by the lowercase text).

| Function     | Signature    | Notes                                          |
| ------------ | ------------ | ---------------------------------------------- |
| `isHostname` | `Any → Bool` | A `hostname` value whose label is not numeric. |
| `isDomain`   | `Any → Bool` | A `domain` value.                              |

## `libnet.host`

Pass-through union over `ip` and `dnsName`. `parse` tries an IP first, so a dotted quad is an `ipv4` value, not a domain. Text that is not an `ip` but reads as IPv4, such as `010.0.0.1` or `127.1`, is not a DNS name either, so `parse` throws for it. A parse error names `host.parse` and keeps the IP's detail for text with a colon or only digits and dots, and the DNS name's otherwise: `host.parse "010.0.0.1"` reports `libnet.host.parse: invalid octet in "010.0.0.1"`, and `host.parse "::g"`, which has a colon, reports `libnet.host.parse: invalid group "g" in "::g"`. Bracketed text and a name followed by a port name the syntax they belong to, as `ip` does: `host.parse "example.com:80"` reports `libnet.host.parse: "example.com:80" reads as host:port, which is endpoint syntax`. A numeric hostname value is not a host, as it is not a DNS name.

Suites: parsing, comparison (IPv4, IPv6, hostname, then domain; within a kind, that kind's order).

| Function    | Signature    | Notes                                                               |
| ----------- | ------------ | ------------------------------------------------------------------- |
| `isIp`      | `Any → Bool` | An `ipv4` or `ipv6` value.                                          |
| `isDnsName` | `Any → Bool` | A `domain` value, or a `hostname` value whose label is not numeric. |

## `libnet.interfaceName`

Value: `{ _type = "interfaceName"; value = String; }`, valid under the kernel's `dev_valid_name`: non-empty, at most 15 bytes, not `.` or `..`, with no `/`, `:` or byte that the kernel's `isspace` treats as space, which is 9 to 13, 32 and 160. Byte 160 rules out UTF-8 text such as `à` (`C3 A0`). Interface names are case-sensitive, so text is the name verbatim.

Suites: parsing, comparison (byte-wise, case-sensitive).

Constant: `maxLength` (`15`), the longest valid name in bytes.
