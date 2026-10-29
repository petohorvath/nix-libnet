# Names

## `libnet.hostname`

Value: `{ _type = "hostname"; value = String; }`, one RFC 1123 label: 1–63 characters of `[A-Za-z0-9-]`, starting and ending alphanumeric. The 63-character cap is Linux's `HOST_NAME_MAX` less the terminator. Underscores are rejected ([ADR 0013](../adr/0013-strict-input-canonical-output.md)). `parse` lowercases the name, so text is the name in lowercase: `hostname.parse "MyHost"` prints `myhost` ([ADR 0020](../adr/0020-case-folded-at-parse.md)).

Suites: parsing, comparison (byte-wise on the lowercase text).

## `libnet.domain`

Value: `{ _type = "domain"; value = String; }`, two or more hostname-valid labels joined by `.`, at most 253 characters, with no leading, trailing or doubled dot. All-numeric forms such as `192.0.2.1` are valid domains; `dnsName` and `host` reject or reclassify them. `parse` and `fromLabels` lowercase the name, so text is the name in lowercase ([ADR 0020](../adr/0020-case-folded-at-parse.md)).

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

Pass-through union over `hostname` and `domain` that rejects IP literals. `parse` picks by label count.

Suites: parsing, comparison (hostnames before domains, then by the lowercase text).

| Function                 | Signature    | Notes |
| ------------------------ | ------------ | ----- |
| `isHostname`, `isDomain` | `Any → Bool` |       |

## `libnet.host`

Pass-through union over `ip` and `dnsName`. `parse` tries an IP first, so a dotted quad is an `ipv4` value, not a domain.

Suites: parsing, comparison (IPv4, IPv6, hostname, then domain; within a kind, that kind's order).

| Function    | Signature    | Notes                           |
| ----------- | ------------ | ------------------------------- |
| `isIp`      | `Any → Bool` | An `ipv4` or `ipv6` value.      |
| `isDnsName` | `Any → Bool` | A `hostname` or `domain` value. |

## `libnet.interfaceName`

Value: `{ _type = "interfaceName"; value = String; }`, valid under the kernel's `dev_valid_name`: non-empty, at most 15 bytes, not `.` or `..`, with no `/`, `:` or byte that the kernel's `isspace` treats as space, which is 9 to 13, 32 and 160. Byte 160 rules out UTF-8 text such as `à` (`C3 A0`). Interface names are case-sensitive, so text is the name verbatim.

Suites: parsing, comparison (byte-wise, case-sensitive).

Constant: `maxLength` (`15`), the longest valid name in bytes.
