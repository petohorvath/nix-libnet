# Names

## `libnet.hostname`

Value: `{ _type = "hostname"; value = String; }`, one RFC 1123 label: 1–63 characters of `[A-Za-z0-9-]`, starting and ending alphanumeric. The 63-character cap is Linux's `HOST_NAME_MAX` less the terminator. Underscores are rejected ([ADR 0013](../adr/0013-strict-input-canonical-output.md)).

Suites: parsing, comparison (case-insensitive). `toString` preserves the input's case.

| Function | Signature | Notes |
| --- | --- | --- |
| `normalize` | `Hostname → Hostname` | Lowercases. |

## `libnet.domain`

Value: `{ _type = "domain"; value = String; }`, two or more hostname-valid labels joined by `.`, at most 253 characters, with no leading, trailing or doubled dot. All-numeric forms such as `192.0.2.1` are valid domains; `dnsName` and `host` reject or reclassify them.

Suites: parsing, comparison (case-insensitive). `toString` preserves the input's case.

| Function | Signature | Notes |
| --- | --- | --- |
| `fromLabels` | `[String] → Domain` | Joins and validates. |
| `labels` | `Domain → [String]` | Leftmost first. |
| `labelCount` | `Domain → Int` | At least 2. |
| `parent` | `Domain → Domain or null` | Drops the leftmost label; `null` when fewer than two would remain. |
| `isSubdomainOf` | `Domain → Domain → Bool` | `isSubdomainOf a b` is true when `a` is `b` or below it. Case-insensitive. |
| `toHostname` | `Domain → Hostname` | The leftmost label. |
| `normalize` | `Domain → Domain` | Lowercases. |

There is no `tld` accessor ([ADR 0003](../adr/0003-syntax-not-resolution.md)); the last element of `labels` is the rightmost label.

## `libnet.dnsName`

Pass-through union over `hostname` and `domain` that rejects IP literals. `parse` picks by label count.

Suites: parsing, comparison (hostnames before domains, then case-insensitive).

| Function | Signature | Notes |
| --- | --- | --- |
| `isHostname`, `isDomain` | `Any → Bool` | |
| `normalize` | `DnsName → DnsName` | Lowercases. |

## `libnet.host`

Pass-through union over `ip` and `dnsName`. `parse` tries an IP first, so a dotted quad is an `ipv4` value, not a domain.

Suites: parsing, comparison (IPv4, IPv6, hostname, then domain; within a kind, that kind's order).

| Function | Signature | Notes |
| --- | --- | --- |
| `isIp`, `isHostname`, `isDomain` | `Any → Bool` | |
| `isName` | `Any → Bool` | Hostname or domain. |

## `libnet.interfaceName`

Value: `{ _type = "interfaceName"; value = String; }`, valid under the kernel's `dev_valid_name`: non-empty, at most 15 bytes, not `.` or `..`, with no `/`, `:` or `isspace(3)` character. Text is the name verbatim.

Suites: parsing, comparison (byte-wise, case-sensitive).

| Function | Signature | Notes |
| --- | --- | --- |
| `value` | `InterfaceName → String` | |

Constant: `ifnamsiz` (`16`).
