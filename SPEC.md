# libnet — Pure-Nix IP & MAC Address Library — v1 Specification

## Context

nixpkgs today provides no reusable `lib` functions for IP address computation. The long-standing issue [NixOS/nixpkgs#36299](https://github.com/NixOS/nixpkgs/issues/36299) (open since 2018) confirms the gap: no CIDR parsing, no network/broadcast computation, no prefix↔netmask conversion, no containment checks, no iteration. The NixOS module system has structured option types in `nixos/modules/tasks/network-interfaces.nix`, but they are module-level and not callable outside module evaluation.

Community libraries have filled the gap with different tradeoffs:
- **duairc/lib-net** — mature, tuple-based IPv6, consistent arithmetic API, good namespacing.
- **djacu/nix-ip** — IPv4-only, dual string/list representation, no MAC support.
- **oddlama/nixos-extra-modules** — string-based, unified dispatch, production-grade but no structured types.
- **nixpkgs GSoC 2024 PRs #318712, #322004** — IPv6 parser + basic operations using 8 × u16 groups; **not merged**, no IPv4 work, no MAC.

This specification defines **libnet**, a pure-Nix library with zero nixpkgs dependency, covering IPv4, IPv6, MAC, CIDR, port numbers, port ranges, endpoints (`ADDR:PORT`), listeners (`[ADDR]:PORT[-END]`), non-CIDR address ranges (`1.2.3.4-1.2.3.10`), interface descriptors (address + network), reverse-DNS formatting (`*.in-addr.arpa`, IPv6 nibble), CIDR set algebra (summarize / exclude / intersect), EUI-64 derivation (RFC 4291), well-known port constants, and a bogon predicate. This document is the specification only — no code is written in this phase.

**Standards referenced**:
- RFC 791 (IPv4), RFC 4291 (IPv6 addressing architecture), RFC 5952 (IPv6 canonical text form)
- RFC 1918 (IPv4 private space), RFC 4193 (IPv6 unique local)
- RFC 3986 § 3.2 (URI authority — `host:port`, `[IPv6]:port` bracket form)
- RFC 6335 (IANA port number registry)
- RFC 7042 (IEEE 802 EUI-48 / EUI-64 address formats) for MAC

## Goals

1. **Zero dependencies** — pure Nix builtins only. No `nixpkgs.lib`. Even the test harness is hand-rolled.
2. **Clean, orthogonal API** — parallel function names across families (`ipv4.parse`, `ipv6.parse`, `mac.parse`); consistent arithmetic (`add`/`sub`/`diff`/`next`/`prev`); consistent comparison (`eq`/`lt`/`compare`).
3. **Tagged structured values** — every parsed value carries a `_type` discriminator (one of `"ipv4"`, `"ipv6"`, `"mac"`, `"cidr"`, `"port"`, `"portRange"`, `"endpoint"`, `"listener"`, `"ipRange"`, `"interface"`) so runtime dispatch is safe and cheap. No raw strings as the canonical form.
4. **Both throwing and recoverable parsing** — `parse` throws on bad input; `tryParse` returns a tagged result.
5. **Completeness over minimalism (v1)** — parse/format, validation, predicates, arithmetic, conversions, CIDR math, iteration, comparison. One spec, one implementation pass. Partial APIs cause churn.
6. **RFC-conformant I/O** — canonical IPv6 per RFC 5952 on output; accept all valid inputs (compression, IPv4-mapped, mixed case) on input.
7. **Testable** — every function has a pure expected-value test case. Hand-rolled runner emits diff on failure.

## Non-Goals (v1)

- No DNS resolution, hostname-to-IP lookups, or live DNS queries of any kind. (Reverse-DNS *name formatting* via `toArpa` IS provided — it's pure string construction with no lookups.)
- No URL/URI parsing (but `toUri` formatter may emit bracketed IPv6 for URL consumers).
- No zone identifiers (`fe80::1%eth0`). Rare in Nix configs; defer to v2 if demanded.
- No IPX, AppleTalk, or historical address families.
- No performance benchmarking commitments. Correctness first.
- Core library never imports `nixpkgs.lib`. NixOS `lib.types.*`-compatible option types ARE provided, but only through the opt-in `libnet.withLib lib` entry point so the core stays dep-free.

## Confirmed Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Spec scope | Comprehensive: IPv4, IPv6, MAC, CIDR, Port, PortRange, Endpoint, Listener, IpRange, Interface — plus reverse-DNS (`toArpa`), EUI-64 derivation, CIDR set algebra (`summarize`/`exclude`/`intersect`), well-known port constants, bogon predicate | User answers across multiple iterations. One coherent API rather than iterative expansion. |
| IPv6 internal representation | 4 × u32 words | User answer 2. Simpler carry math than 8 × u16; u32 comfortably fits Nix's signed 64-bit ints (max 2⁶³−1 ≈ 9.2 × 10¹⁸). |
| Namespace | Flat per-family + unified `ip.*` | User answer 3. `libnet.ipv4.*`, `libnet.ipv6.*`, `libnet.mac.*`, `libnet.cidr.*`, `libnet.ip.*`. |
| IPv4 internal representation | single u32 int | 32 bits fits natively. Simplest possible arithmetic. |
| MAC internal representation | single u48 int | 48 bits fits natively. Fast comparison, OUI extraction via div. |
| CIDR internal representation | tagged attrset `{ _type = "cidr"; address; prefix; }` where `address` is itself a tagged ipv4 or ipv6 value | Family carried by the contained address — no separate `cidrv4`/`cidrv6` namespaces. |
| Error handling | `parse` throws; `tryParse` returns `{ success; value; error; }` | Matches Nix conventions (`builtins.tryEval`). |
| Minimum Nix version | 2.18 | All required builtins (`bitAnd`, `bitOr`, `bitXor`, `split`, `match`, `substring`, `foldl'`, `genList`) are available. Shift operations are emulated via `* 2^n` and `div`. |
| Canonical output | RFC 5952 for IPv6 (lowercase, `::` for longest zero run); lowercase colon-separated for MAC; dotted-quad for IPv4 | Standards compliance. |
| Strict parsing | Reject IPv4 octets with leading zeros (avoid octal confusion, RFC 6943 §3.1.1). Reject MAC/IPv6 groups exceeding width. | Safety. |
| Library attribute name | `libnet` | Matches repo directory `nix-libnet`; short; unambiguous. |
| Type exposure | Pure-Nix structural predicates (`*.is`) always available; NixOS `lib.types.*`-compatible module types opt-in via `libnet.withLib lib` | User answer 4. Core stays dep-free; module integration unlocked only when caller injects `nixpkgs.lib`. |
| Port internal representation | single int in `[0, 65535]` | 16 bits fits natively; simplest math. |
| PortRange internal representation | `{ _type; from; to; }` with `from <= to` | Contiguous range is the only shape we support (no disjoint sets in v1). |
| Endpoint internal representation | `{ _type; address; port; }` with both required | Fully-specified destination; mirrors RFC 3986 authority. |
| Listener internal representation | `{ _type; address; portRange; }` with `address` nullable | Relaxed form for listen/bind; port is always a range (possibly size 1). |
| IpRange internal representation | `{ _type; from; to; }` — both same-family tagged addresses, `to >= from` | Non-CIDR contiguous range. Parallels portRange for addresses. |
| Interface internal representation | `{ _type; name; address; prefix; }` where `name`, `address`, `prefix` are each nullable (at least one of `name`/`address` is non-null; `address` and `prefix` are paired). | Combines Python's `IPv4Interface` / `IPv6Interface` (address-on-a-subnet) with a Linux ifname carrier. A value may be addr-only (classic CIDR-style), name-only (bare ifname), or both. Distinct from cidr by type tag: cidr is "here is network Y"; interface is "host X / device N is on network Y". `interface.network` derives the canonical cidr from an addr-carrying value. |
| Endpoint IPv6 format | brackets mandatory on parse and output (`[::1]:80`) | RFC 3986 § 3.2.2. Unbracketed IPv6 ambiguous vs port separator. |
| PortRange canonical separator | `-` (hyphen) | Dominant modern convention (nftables, Docker, k8s, pf). `:` accepted on parse for iptables interop. |
| Listener wildcard input forms | `*`, `any`, `0.0.0.0`, `[::]`, or missing address | Accept all common conventions; canonical output omits address entirely (`:8080`). |
| IpRange canonical separator | `-` (hyphen) | Parallels portRange separator. |
| EUI-64 form | Modified EUI-64 per RFC 4291 (u/l bit flipped) | This is the form used for IPv6 interface identifiers. Raw EUI-64 not exposed in v1. |

## Data Model

All parsed values are tagged attrsets. The `_type` tag enables safe dispatch and guards against accidental misuse (e.g., passing a raw int where a parsed address is expected).

### IPv4 value
```nix
{
  _type = "ipv4";
  value = <int>;   # 0 .. 4294967295
}
```
Invariant: `value` is in `[0, 2^32 - 1]`.

### IPv6 value
```nix
{
  _type = "ipv6";
  words = [ <u32> <u32> <u32> <u32> ];   # high-to-low, big-endian
}
```
Invariants:
- `words` has exactly 4 elements.
- Each element is in `[0, 2^32 - 1]`.
- `words[0]` is the most significant 32 bits (e.g., `2001:0db8::1` → `[ 0x20010db8, 0, 0, 1 ]`).

### MAC value
```nix
{
  _type = "mac";
  value = <int>;   # 0 .. 281474976710655  (2^48 - 1)
}
```
Invariant: `value` is in `[0, 2^48 - 1]`.

### CIDR value
```nix
{
  _type = "cidr";
  address = <ipv4 value | ipv6 value>;    # tagged, as above
  prefix  = <int>;                         # 0..32 if ipv4, 0..128 if ipv6
}
```
Invariants:
- `address._type` is `"ipv4"` or `"ipv6"`.
- `prefix` is in `[0, 32]` for ipv4, `[0, 128]` for ipv6.
- `address` is **not** required to be the network address (non-canonical CIDRs are allowed). `cidr.canonical` zeros host bits; `cidr.isCanonical` tests canonicality.

### Port value
```nix
{
  _type = "port";
  value = <int>;   # 0 .. 65535
}
```
Invariant: `value` is in `[0, 65535]` (RFC 6335).

### PortRange value
```nix
{
  _type = "portRange";
  from = <int>;   # 0 .. 65535
  to   = <int>;   # from .. 65535
}
```
Invariants:
- Both `from` and `to` are in `[0, 65535]`.
- `from <= to` (a single-port range is `from == to`).

### tryParse result
```nix
{
  success = <bool>;
  value   = <parsed value | null>;
  error   = <string | null>;    # human-readable, only set when success = false
}
```

### Comparison semantics across types

A single rule applies everywhere, so cross-type behavior is predictable:

- **Equality (`eq`)**: always `false` when the two values are of different `_type` or different address family inside a composite. Never throws.
- **Ordering (`lt`/`le`/`gt`/`ge`/`compare`/`min`/`max`)**: lenient — cross-family values order by family (IPv4 before IPv6), so sorts on heterogeneous lists are stable and do not throw. Cross-*type* ordering (e.g., `Port` vs `Ipv4`) is undefined; callers who construct such mixed lists are responsible for the partitioning.
- **Containment (`contains`, `isSubnetOf`, `isSupernetOf`, `overlaps`, `isSubrangeOf`, `isSuperrangeOf`)**: always `false` when the two arguments are of different address family. Never throws.
- **Arithmetic (`add`/`sub`/`diff`/`next`/`prev`)**: throws on overflow/underflow past the type's range; `diff` on cross-family Ipv4/Ipv6 via `libnet.ip.diff` throws.

### Endpoint vs Listener — conceptual split

Endpoint and Listener solve different problems:

- **Endpoint** = *"connect to where?"* A fully-resolved outbound destination. Both address and port are required. No wildcards. Directly dialable. Think: outbound HTTP target, upstream proxy, database URL.
- **Listener** = *"listen how?"* A server-side listen/accept configuration. Address may be `null` (wildcard — accept on any interface); port is always a range (may be size 1). Think: `systemd ListenStream=`, `nginx listen`, firewall allow-rule.

Keeping them as distinct types gives outbound code a type-level guarantee that it will never receive a wildcard or a range where a concrete target is required, which is the class of bug the split prevents. Conversion is asymmetric: `listener.toEndpoints` materializes a listener into concrete endpoints (throws if the address is null); wrapping an endpoint as a listener is a one-liner and does not warrant a dedicated helper.

### Endpoint value
```nix
{
  _type = "endpoint";
  address = <ipv4 value | ipv6 value>;   # required, never null
  port    = <port value>;                 # required
}
```
Fully-specified destination for "connect". Canonical text form follows RFC 3986: `1.2.3.4:80` for IPv4, `[2001:db8::1]:80` for IPv6.

### Listener value
```nix
{
  _type = "listener";
  address   = <ipv4 value | ipv6 value | null>;   # null = wildcard / any
  portRange = <portRange value>;                  # always a range, may be size 1
}
```
Listen/bind target with relaxed semantics: address may be absent (means "any interface"), and the port portion may be a range. Canonical text form: `[address]:from[-to]` where the address bracket rule matches endpoint, and `-to` is omitted when `from == to`. Empty address renders as `:8080`. Input accepts `*`, `any`, `0.0.0.0`, `[::]`, or missing address as equivalent wildcards.

### IpRange value
```nix
{
  _type = "ipRange";
  from = <ipv4 value | ipv6 value>;
  to   = <ipv4 value | ipv6 value>;   # same family as `from`; ipToInt to >= ipToInt from
}
```
Invariants:
- `from._type == to._type` (same family).
- `to` is numerically >= `from` (using the family's natural int ordering; IPv6 compared lexicographically on `words`).

Contiguous non-CIDR range. Canonical text form: `from-to` (e.g. `10.0.0.1-10.0.0.50`). IPv6 ranges write addresses unbracketed since no port disambiguation is needed: `2001:db8::1-2001:db8::ff`.

### Interface value
```nix
{
  _type   = "interface";
  name    = <string | null>;              # Linux ifname (kernel dev_valid_name)
  address = <ipv4 value | ipv6 value | null>;
  prefix  = <int | null>;                 # 0..32 for ipv4, 0..128 for ipv6
}
```
Invariants:
- At least one of `name` and `address` is non-null.
- `address` and `prefix` are either both null or both set.
- If `address` is non-null: `prefix` is in `[0, 32]` if ipv4, `[0, 128]` if ipv6.
- If `name` is non-null: it passes `interface.isValidName` (kernel-parity `dev_valid_name`: non-empty, length < IFNAMSIZ=16, not `.` / `..`, no `/`, no `:`, no whitespace per `isspace(3)`).

Three valid shapes:
- **Addr-only**: `{ name = null; address = <ip>; prefix = <int>; }` — Python's `IPv4Interface` equivalent.
- **Name-only**: `{ name = <str>; address = null; prefix = null; }` — a standalone Linux interface identifier.
- **Named+addr**: both set — an addressed assignment on a named device.

Canonical text forms:
- Addr-only → `<address>/<prefix>` (same shape as a CIDR string; distinction is in the type tag).
- Name-only → `<name>` (bare ifname).
- Named+addr → `<address>/<prefix>` — the name is metadata, not part of the canonical text form. Linux tooling (`ip addr`, netlink, NixOS modules) keeps the two fields structurally separate; no widely-adopted single-string composite form exists. Name is accessed via `interface.name iface`. RFC 4007 `%<zone>` is defined only for IPv6 link-local scope (see Non-Goals); libnet does not overload it as a general composite separator.

Distinct from `cidr` by `_type` tag: a cidr is "here is network Y" (address is usually canonical); an interface is "host X / device N is on network Y". `interface.network :: Interface → Cidr` derives the canonical network on demand (throws on name-only values).

### Tagging convention

Rule: a field is a tagged attrset when the value is independently useful as a first-class type with its own algebra. A field is a raw int or raw list when it's a boundary/index value that only has meaning within its enclosing composite.

| Composite | Tagged fields | Raw fields |
|---|---|---|
| `cidr` | `address` (Ipv4/Ipv6) | `prefix` (int) |
| `ipv6` | — | `words` (list of int) |
| `portRange` | — | `from`, `to` (int, int) |
| `endpoint` | `address` (Ipv4/Ipv6), `port` (Port) | — |
| `listener` | `address` (Ipv4/Ipv6/null), `portRange` (PortRange) | — |
| `ipRange` | `from`, `to` (Ipv4/Ipv6) | — |
| `interface` | `address` (Ipv4/Ipv6/null) | `prefix` (int/null), `name` (string/null) |

Rationale for the asymmetry in PortRange vs Endpoint: a Port standing alone has semantic meaning and predicates (`isWellKnown`, etc.), so Endpoint carries it tagged. A port-range boundary only exists within a range and never travels alone, so from/to stay as ints (parallel to how `cidr.prefix` is an int).

Users who want Port values from a range call `port.fromInt (portRange.from pr)`.

## API Surface

Every function is documented with:
- Haskell-ish type signature (reading aid — Nix is dynamically typed)
- One-line semantics
- Throws-or-not
- Example (where non-obvious)

Curry order throughout: **operators come first, operand last**, so `add 1` is a partially applied "add one" function useful in `map`/`foldl'`. This applies to `add`, `sub`, `diff`, `host`, `endpoint` (on Listener), `subnet`, `supernet`, `contains` (where applicable), and predicates that take a parameter.

**`isValid` vs `is`**: every family has both. `isValid :: String → Bool` tests "does this string parse successfully" (string-level validation). `is :: Any → Bool` tests "is this value a parsed X value" (structural check on the `_type` tag). They are not interchangeable: `ipv4.isValid "10.0.0.1"` is `true`, but `ipv4.is "10.0.0.1"` is `false` (a raw string is not a parsed ipv4 value).

### `libnet.ipv4`

**Parsing & formatting**
| Function | Signature | Notes |
|---|---|---|
| `parse` | `String → Ipv4` | Throws on invalid. Rejects leading zeros, >255 octets, non-4 octets. |
| `tryParse` | `String → TryResult Ipv4` | Never throws. |
| `toString` | `Ipv4 → String` | Canonical dotted-quad. |
| `fromInt` | `Int → Ipv4` | Throws if out of range. |
| `toInt` | `Ipv4 → Int` | Total. |
| `fromOctets` | `[Int] → Ipv4` | List of 4 ints, MSB first. Throws on length/range. |
| `toOctets` | `Ipv4 → [Int]` | 4 ints, MSB first. |
| `toArpa` | `Ipv4 → String` | Reverse-DNS form: `1.2.3.4 → "4.3.2.1.in-addr.arpa"`. |

**Predicates**
| Function | Signature | Notes |
|---|---|---|
| `isValid` | `String → Bool` | Sugar for `(tryParse x).success`. |
| `is` | `Any → Bool` | Structural: value is a `{_type="ipv4";…}`. |
| `isLoopback` | `Ipv4 → Bool` | `127.0.0.0/8`. |
| `isPrivate` | `Ipv4 → Bool` | RFC 1918: `10/8`, `172.16/12`, `192.168/16`. |
| `isLinkLocal` | `Ipv4 → Bool` | `169.254.0.0/16`. |
| `isMulticast` | `Ipv4 → Bool` | `224.0.0.0/4`. |
| `isBroadcast` | `Ipv4 → Bool` | `255.255.255.255`. |
| `isUnspecified` | `Ipv4 → Bool` | `0.0.0.0`. |
| `isReserved` | `Ipv4 → Bool` | `240.0.0.0/4` (excluding broadcast). |
| `isDocumentation` | `Ipv4 → Bool` | `192.0.2/24`, `198.51.100/24`, `203.0.113/24`. |
| `isGlobal` | `Ipv4 → Bool` | Exactly `!isBogon`. IPv4 has no transition/interop forms to exclude, so this is strictly the complement of `isBogon` (unlike the IPv6 counterpart — see below). |
| `isBogon` | `Ipv4 → Bool` | Not globally routable: any of `isLoopback`, `isPrivate`, `isLinkLocal`, `isMulticast`, `isReserved`, `isDocumentation`, `isUnspecified`, `isBroadcast`. |

**Arithmetic**
| Function | Signature | Notes |
|---|---|---|
| `add` | `Int → Ipv4 → Ipv4` | Throws on overflow/underflow. |
| `sub` | `Int → Ipv4 → Ipv4` | Throws on overflow/underflow. |
| `diff` | `Ipv4 → Ipv4 → Int` | `diff a b = toInt b - toInt a`. |
| `next` | `Ipv4 → Ipv4` | Throws at `255.255.255.255`. |
| `prev` | `Ipv4 → Ipv4` | Throws at `0.0.0.0`. |

**Comparison**
| `eq` | `Ipv4 → Ipv4 → Bool` |
| `lt` | `Ipv4 → Ipv4 → Bool` |
| `le` | `Ipv4 → Ipv4 → Bool` |
| `gt` | `Ipv4 → Ipv4 → Bool` |
| `ge` | `Ipv4 → Ipv4 → Bool` |
| `compare` | `Ipv4 → Ipv4 → Int` — returns −1, 0, or 1 |
| `min` / `max` | `Ipv4 → Ipv4 → Ipv4` |

**Constants**
| `unspecified` | `0.0.0.0` — matches the `isUnspecified` predicate. |
| `broadcast` | `255.255.255.255` |
| `loopback` | `127.0.0.1` |

### `libnet.ipv6`

Mirrors `libnet.ipv4` one-for-one with these additions/adjustments:

**Parsing & formatting** adds:
| Function | Signature | Notes |
|---|---|---|
| `toStringExpanded` | `Ipv6 → String` | Full uncompressed form `2001:0db8:0000:0000:0000:0000:0000:0001`. |
| `toStringCompressed` | `Ipv6 → String` | Alias for `toString` — RFC 5952 canonical. |
| `toStringBracketed` | `Ipv6 → String` | `[2001:db8::1]` for URL contexts. |
| `fromWords` | `[Int] → Ipv6` | 4 × u32, MSB first. |
| `toWords` | `Ipv6 → [Int]` | 4 × u32. |
| `fromGroups` | `[Int] → Ipv6` | 8 × u16, MSB first (matches hex notation). |
| `toGroups` | `Ipv6 → [Int]` | 8 × u16. |
| `fromBytes` | `[Int] → Ipv6` | 16 × u8. |
| `toBytes` | `Ipv6 → [Int]` | 16 × u8. |
| `toArpa` | `Ipv6 → String` | Reverse-DNS nibble form: `2001:db8::1 → "1.0.0.0.…0.0.8.b.d.0.1.0.0.2.ip6.arpa"`. 32 nibbles reversed. |
| `fromEui64` | `Cidr → Mac → Ipv6` | Combine network prefix (upper 64 bits) with modified EUI-64 derivation of MAC (lower 64 bits). Throws if the CIDR prefix > 64. |

No `toInt`/`fromInt` — doesn't fit. (Consider `toBigIntParts → {hi, lo}` only if a user asks.)

**Predicates** (differences from IPv4):
| `isLoopback` | `::1` |
| `isUnspecified` | `::` |
| `isLinkLocal` | `fe80::/10` |
| `isUniqueLocal` | `fc00::/7` (replaces `isPrivate`) |
| `isMulticast` | `ff00::/8` |
| `isDocumentation` | `2001:db8::/32`, `3fff::/20` |
| `isIpv4Mapped` | `::ffff:0:0/96` |
| `isIpv4Compatible` | `::0.0.0.0/96` — deprecated form, still testable |
| `is6to4` | `2002::/16` |
| `isGlobal` | Stricter than `!isBogon`: additionally excludes `isIpv4Mapped`, `isIpv4Compatible`, and `is6to4`. Those transition/interop forms are technically routable but do not represent native IPv6 global unicast, so `isGlobal` rules them out. Intentionally asymmetric with `ipv4.isGlobal`, which has no such transition forms to consider. |
| `isBogon` | `Ipv6 → Bool` — not globally routable: any of `isLoopback`, `isUnspecified`, `isLinkLocal`, `isUniqueLocal`, `isMulticast`, `isDocumentation`. Does **not** include the IPv4 transition/interop forms (`isIpv4Mapped`, `isIpv4Compatible`, `is6to4`) — those are excluded by `isGlobal` but are not classified as bogons. |

**IPv4 interop**:
| `fromIpv4Mapped` | `Ipv4 → Ipv6` | `1.2.3.4 → ::ffff:1.2.3.4` |
| `toIpv4Mapped` | `Ipv6 → Ipv4` | Throws if not in `::ffff:0:0/96`. |

**Arithmetic**: `add`, `sub`, `diff`, `next`, `prev` — same signatures as IPv4; `add`/`sub` propagate carry/borrow across the four u32 words and throw on wrap past `::` or `ffff:...:ffff`. `diff a b` returns `ipv6.toInt`-equivalent difference — throws if the difference would overflow a signed 63-bit int (fall back to a per-word manual compare in that case).

**Comparison**: `eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max` — lexicographic on the word list (MSB-first), so `compare` matches the natural numeric ordering.

**Constants**
| `unspecified` | `::` — matches the `isUnspecified` predicate. |
| `loopback` | `::1` |

(No `broadcast` constant — IPv6 has no broadcast concept.)

### `libnet.mac`

**Parsing & formatting**
| `parse` | `String → Mac` | Accepts any of: `aa:bb:cc:dd:ee:ff`, `aa-bb-cc-dd-ee-ff`, `aabb.ccdd.eeff`, `aabbccddeeff`. Case-insensitive. |
| `tryParse` | `String → TryResult Mac` |
| `toString` | `Mac → String` | Canonical: `aa:bb:cc:dd:ee:ff` (colon, lowercase). |
| `toStringHyphen` | `Mac → String` | `aa-bb-cc-dd-ee-ff`. |
| `toStringCisco` | `Mac → String` | `aabb.ccdd.eeff`. |
| `toStringBare` | `Mac → String` | `aabbccddeeff`. |
| `fromInt` / `toInt` | `Int ↔ Mac` | 48-bit value. |
| `fromBytes` / `toBytes` | `[Int] ↔ Mac` | 6 bytes, MSB first. |

**Predicates & bit manipulation**
| `isValid` | `String → Bool` |
| `is` | `Any → Bool` |
| `isUnicast` | `Mac → Bool` | Bit 0 of first octet is 0. |
| `isMulticast` | `Mac → Bool` | Bit 0 of first octet is 1. |
| `isUniversal` | `Mac → Bool` | Bit 1 of first octet is 0. |
| `isLocal` | `Mac → Bool` | Bit 1 of first octet is 1 (locally administered). |
| `isBroadcast` | `Mac → Bool` | `ff:ff:ff:ff:ff:ff`. |
| `isUnspecified` | `Mac → Bool` | `00:00:00:00:00:00`. |
| `setLocal` | `Mac → Mac` | Set bit 1 of first octet. |
| `setUniversal` | `Mac → Mac` | Clear bit 1 of first octet. |
| `setMulticast` | `Mac → Mac` | Set bit 0 of first octet. |
| `setUnicast` | `Mac → Mac` | Clear bit 0 of first octet. |

**OUI / NIC split**
| `oui` | `Mac → Int` | Upper 24 bits (as u24 int). |
| `nic` | `Mac → Int` | Lower 24 bits. |
| `fromOuiNic` | `Int → Int → Mac` | Reconstruct. |
| `ouiToString` | `Int → String` | `aa:bb:cc` formatted OUI. |

**EUI-64**
| `toEui64` | `Mac → [Int]` | 8-byte modified EUI-64 identifier per RFC 4291 § 2.5.1: insert `0xFF, 0xFE` between OUI and NIC, flip the u/l bit of the first octet. Output suitable as lower 64 bits of an IPv6 address. |

**Arithmetic & comparison**: `add`, `sub`, `diff`, `next`, `prev`, `eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max` — parallel to IPv4.

**Constants**
| `unspecified` | `00:00:00:00:00:00` — matches the `isUnspecified` predicate. |
| `broadcast` | `ff:ff:ff:ff:ff:ff` |

### `libnet.cidr`

**Parsing & construction**
| `parse` | `String → Cidr` | `"10.0.0.0/24"` or `"2001:db8::/32"`. Throws on invalid. |
| `tryParse` | `String → TryResult Cidr` |
| `toString` | `Cidr → String` | Canonical form uses the stored address as-is (may be non-canonical). |
| `make` | `(Ipv4 | Ipv6) → Int → Cidr` | `make address prefix`. Validates prefix range for the family. |
| `fromAddress` | `(Ipv4 | Ipv6) → Cidr` | Uses `/32` or `/128`. |

**Predicates**
| `isValid` | `String → Bool` | Does the string parse as a CIDR. |
| `is` | `Any → Bool` | Structural: value is a `{_type="cidr";…}`. |
| `isIpv4` | `Cidr → Bool` |
| `isIpv6` | `Cidr → Bool` |

**Accessors**
| `address` | `Cidr → Ipv4 | Ipv6` | The stored base address. |
| `prefix` | `Cidr → Int` | Prefix length. |
| `version` | `Cidr → Int` | `4` or `6`. |

**Derived values**
| `network` | `Cidr → Ipv4 | Ipv6` | Base address with host bits zeroed. |
| `broadcast` | `Cidr → Ipv4` | IPv4 only; throws for IPv6. |
| `netmask` | `Cidr → Ipv4 | Ipv6` | E.g. `/24` → `255.255.255.0`. |
| `hostmask` | `Cidr → Ipv4 | Ipv6` | Inverse of netmask. |
| `firstHost` | `Cidr → Ipv4 | Ipv6` | First usable. For IPv4 `/31`,`/32` returns network; for `/30` and wider returns network+1. For IPv6: returns network+1 unless `/128`. |
| `lastHost` | `Cidr → Ipv4 | Ipv6` | Last usable. IPv4 `/31`/`/32`: returns top; `/30` and wider: broadcast-1. IPv6: returns top unless `/128`. |
| `size` | `Cidr → Int` | Total addresses. Throws for any block with ≥ 2⁶³ addresses (which is IPv4 not possible; IPv6 prefixes ≤ 65). For wider IPv6 blocks, callers can infer `size = 2^(128 - prefix)` externally or convert to a Range and use its size logic. |
| `numHosts` | `Cidr → Int` | Usable host count. Same overflow rules. |

**Enumeration**
| `host` | `Int → Cidr → Ipv4 | Ipv6` | n-th host offset. Throws if n exceeds range. Negative n counts from the end. |
| `hosts` | `Cidr → [Ipv4 | Ipv6]` | List of all usable hosts. Throws if `size` > 2¹⁶ to prevent accidental memory blow-ups; users can override via `hostsUnbounded`. |
| `hostsUnbounded` | `Cidr → [Ipv4 | Ipv6]` | No size guard. Caller's responsibility. |

**Containment & relationships**
| `contains` | `Cidr → (Ipv4 | Ipv6 | Cidr) → Bool` | Overloaded on second arg. Mixed-family returns false rather than throwing. |
| `containsAddress` | `Cidr → (Ipv4 | Ipv6) → Bool` | Strict version. |
| `containsCidr` | `Cidr → Cidr → Bool` | Strict version. |
| `isSubnetOf` | `Cidr → Cidr → Bool` | `isSubnetOf a b` is true iff `a ⊆ b`. Subject first, container second — matches Python's `IPv4Network.subnet_of`. |
| `isSupernetOf` | `Cidr → Cidr → Bool` | `isSupernetOf a b` is true iff `b ⊆ a`. Inverse of `isSubnetOf`. |
| `overlaps` | `Cidr → Cidr → Bool` | Symmetric. |

**Normalization & restructuring**
| `canonical` | `Cidr → Cidr` | Zeroes host bits. |
| `isCanonical` | `Cidr → Bool` |
| `subnet` | `Int → Cidr → [Cidr]` | Split into equal-sized subnets with the given additional prefix bits. E.g. `subnet 2 (parse "10/8")` → four `/10` blocks. Throws on size explosion like `hosts`. |
| `supernet` | `Int → Cidr → Cidr` | Expand by n bits. `supernet 8 (parse "10.1.0.0/24")` → `10.0.0.0/16`. |

**Set algebra**
| `summarize` | `[Cidr] → [Cidr]` | Coalesce a list of CIDRs into the minimal equivalent set: merges adjacent same-size pairs into supernets, drops duplicates and fully-covered entries, sorts output. Mixed families partitioned, each family collapsed separately. Python's `ipaddress.collapse_addresses` equivalent. |
| `exclude` | `Cidr → Cidr → [Cidr]` | `exclude parent child`: return the minimal list of CIDRs covering `parent \ child`. Throws if `child` is not contained in `parent`. Returns `[]` if `child == parent`. |
| `intersect` | `Cidr → Cidr → (Cidr | null)` | The largest CIDR contained in both (always the smaller of the two if one contains the other, else `null`). |

**Comparison**: `eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max` — lexicographic on `(family, network, prefix)`. `eq` additionally requires canonical-equivalent networks (so `10.0.0.0/24` and `10.0.0.5/24` compare equal because their canonical forms match). Cross-family comparison follows the lenient v4-before-v6 rule.

### `libnet.ip` (unified dispatch)

Auto-detects address family from input. All functions accept either IPv4 or IPv6.

**Parsing & formatting**
| `parse` | `String → (Ipv4 | Ipv6)` | Detects by presence of `:`. Throws on invalid. |
| `tryParse` | `String → TryResult (Ipv4 | Ipv6)` |
| `toString` | `(Ipv4 | Ipv6) → String` |
| `version` | `(Ipv4 | Ipv6) → Int` | `4` or `6`. |
| `is` | `Any → Bool` | Structural check for either. |
| `isIpv4` | `Any → Bool` |
| `isIpv6` | `Any → Bool` |

**Dispatched operations**
| `eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max` | — | Mixed family: cross-family values compare by version (v4 < v6), so lists sort stably. `eq` across families is always `false`. |
| `add`, `sub`, `diff`, `next`, `prev` | — | Dispatches to the family-specific implementation. `diff` across families throws. |

**Forwarded predicates & formatters** (same name in both families):
| `isLoopback` | `(Ipv4 | Ipv6) → Bool` |
| `isUnspecified` | `(Ipv4 | Ipv6) → Bool` |
| `isLinkLocal` | `(Ipv4 | Ipv6) → Bool` |
| `isMulticast` | `(Ipv4 | Ipv6) → Bool` |
| `isDocumentation` | `(Ipv4 | Ipv6) → Bool` |
| `isGlobal` | `(Ipv4 | Ipv6) → Bool` — family-aware. For IPv4 equals `!isBogon`; for IPv6 it additionally excludes `isIpv4Mapped`, `isIpv4Compatible`, and `is6to4`. See each family's entry for the rationale. |
| `isBogon` | `(Ipv4 | Ipv6) → Bool` — family-aware "not globally routable". |
| `toArpa` | `(Ipv4 | Ipv6) → String` — reverse-DNS formatting. |

Family-specific predicates (ipv4 `isPrivate`/`isBroadcast`/`isReserved`, ipv6 `isUniqueLocal`/`isIpv4Mapped`/`is6to4`) are NOT unified; call them on the family namespace directly.

### `libnet.port`

**Parsing & formatting**
| `parse` | `String → Port` | Accepts decimal digits only. Rejects leading +/−, whitespace, hex. Throws on out-of-range. |
| `tryParse` | `String → TryResult Port` |
| `toString` | `Port → String` | Decimal. |
| `fromInt` / `toInt` | `Int ↔ Port` | Throws on out-of-range. |

**Predicates** (per RFC 6335)
| `isValid` | `String → Bool` |
| `is` | `Any → Bool` |
| `isWellKnown` | `Port → Bool` | `0..1023`. |
| `isRegistered` | `Port → Bool` | `1024..49151`. |
| `isDynamic` | `Port → Bool` | `49152..65535` (alias: `isEphemeral`). |
| `isReserved` | `Port → Bool` | `0`. |

**Arithmetic**: `add`, `sub`, `diff`, `next`, `prev` — parallel to ipv4/mac. `add`/`sub` throw on overflow beyond `[0, 65535]`. `diff a b = toInt b - toInt a`.

**Comparison**: `eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max` — parallel to ipv4/mac.

**Constants** (raw ints, not Port values — `min`/`max` are taken by the comparison helpers)
| `lowestValue` | `0` |
| `highestValue` | `65535` |
| `wellKnownMax` | `1023` |
| `registeredMax` | `49151` |

**Well-known service ports** live in [`libnet.registry.wellKnownPorts`](./lib/registry.nix) as a protocol-grouped `{ tcp = { name = int; ... }; udp = { ... }; }` map (raw integers, not Port values — lift via `port.fromInt` on demand). Names appearing on both protocols (e.g. `dns`, `rdp`, `memcached`) share the same port number under each key. Port `853` appears on both protocols under different names — `tcp.dnsTls` (DNS-over-TLS, RFC 7858) and `udp.dnsQuic` (DNS-over-QUIC, RFC 9250) — since IANA assigns the two distinct services to the same port.

### `libnet.portRange`

**Parsing & formatting**
| `parse` | `String → PortRange` | Accepts `"8080"` (single), `"5500-6000"` (canonical), `"5500:6000"` (iptables form). Throws if `from > to` or out of range. |
| `tryParse` | `String → TryResult PortRange` |
| `toString` | `PortRange → String` | Canonical `from-to` (hyphen). Single-port range emits `"8080"` (no hyphen). |
| `toStringColon` | `PortRange → String` | iptables-style `from:to`. |
| `make` | `Int → Int → PortRange` | Throws if out of range or `from > to`. |
| `singleton` | `Port → PortRange` | Construct range containing one port. |

**Predicates**
| `isValid` | `String → Bool` |
| `is` | `Any → Bool` |
| `isSingleton` | `PortRange → Bool` |

**Accessors**
| `from` / `to` | `PortRange → Int` |
| `size` | `PortRange → Int` | `to - from + 1`. |

**Containment & relationships**
| `contains` | `PortRange → Port → Bool` |
| `overlaps` | `PortRange → PortRange → Bool` | Symmetric. |
| `isSubrangeOf` | `PortRange → PortRange → Bool` | `isSubrangeOf a b` true iff `a ⊆ b`. Same subject-first convention as `cidr.isSubnetOf`. |
| `isSuperrangeOf` | `PortRange → PortRange → Bool` | Inverse of `isSubrangeOf`. |
| `merge` | `PortRange → PortRange → (PortRange | null)` | Returns unified range if adjacent or overlapping; `null` otherwise. |

**Enumeration**
| `ports` | `PortRange → [Port]` | Enumerate all ports. Throws if `size > 2¹²` (4096); use `portsUnbounded` to bypass. |
| `portsUnbounded` | `PortRange → [Port]` | No size guard. Caller's responsibility. |

**Comparison**: `eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max` — lexicographic on `(from, to)`. Same pattern as ipv4/ipv6/mac.

### `libnet.endpoint`

**Parsing & formatting** (RFC 3986 § 3.2)
| `parse` | `String → Endpoint` | IPv4: `"1.2.3.4:80"`. IPv6: `"[::1]:80"` — brackets **required** to disambiguate. Throws on unbracketed IPv6, missing port, or invalid parts. |
| `tryParse` | `String → TryResult Endpoint` |
| `toString` | `Endpoint → String` | Canonical: IPv4 unbracketed, IPv6 bracketed. |
| `toUri` | `Endpoint → String` | Alias — always emits URI-authority form. |
| `make` | `(Ipv4 | Ipv6) → Port → Endpoint` | Combine pre-parsed address and port. |

**Predicates**
| `isValid` | `String → Bool` |
| `is` | `Any → Bool` |
| `isIpv4` / `isIpv6` | `Endpoint → Bool` |

**Accessors**
| `address` | `Endpoint → Ipv4 | Ipv6` |
| `port` | `Endpoint → Port` |
| `version` | `Endpoint → Int` | `4` or `6` (family of the address). |

**Forwarded predicates** (apply to the endpoint's address component):
| `isLoopback` | `Endpoint → Bool` |
| `isLinkLocal` | `Endpoint → Bool` |
| `isMulticast` | `Endpoint → Bool` |
| `isUnspecified` | `Endpoint → Bool` |
| `isDocumentation` | `Endpoint → Bool` |
| `isGlobal` | `Endpoint → Bool` |

Family-specific predicates (e.g. ipv4 `isPrivate`, ipv6 `isUniqueLocal`) are NOT forwarded; call them via `ipv4.isPrivate (endpoint.address e)` to stay explicit about family.

**Comparison**: `eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max` — compare by `(version, address, port)`. Mixed family uses the same lenient v4-before-v6 rule as `libnet.ip.compare`.

### `libnet.listener`

**Parsing & formatting**
| `parse` | `String → Listener` | Accepts: `:8080` (any+single), `:8080-8090` (any+range), `0.0.0.0:8080`, `[::]:8080`, `1.2.3.4:5000-6000`, `[::1]:5000-6000`, `*:8080`, `any:8080`. Both `*:PORT`/`any:PORT` normalize to `{address = null; ...}` (same shape as no-address input). `0.0.0.0:PORT` and `[::]:PORT` preserve the explicit family address (not normalized to null) so consumers can still tell them apart. Throws on malformed input. |
| `tryParse` | `String → TryResult Listener` |
| `toString` | `Listener → String` | Canonical: `:from[-to]` when address is null, `<ADDR>:<range>` otherwise; IPv6 bracketed. |
| `make` | `(Ipv4 | Ipv6 | null) → PortRange → Listener` | |

**Predicates**
| `isValid` | `String → Bool` |
| `is` | `Any → Bool` |
| `isAnyAddress` | `Listener → Bool` | `true` iff `address == null` or address is `0.0.0.0`/`::`. |
| `isWildcard` | `Listener → Bool` | Alias for `isAnyAddress`. |
| `isRange` | `Listener → Bool` | `true` iff underlying range has size > 1. |
| `isIpv4` | `Listener → Bool` | `false` when address is null. Parallels `cidr.isIpv4`, `endpoint.isIpv4`. |
| `isIpv6` | `Listener → Bool` | `false` when address is null. |

**Accessors**
| `address` | `Listener → Ipv4 | Ipv6 | null` |
| `portRange` | `Listener → PortRange` |
| `version` | `Listener → Int | null` | `4`, `6`, or `null` if address is null. |

**Expansion & interop**
| `toEndpoints` | `Listener → [Endpoint]` | Materialize each port into a concrete endpoint. Requires a non-null address; throws otherwise. Respects the `ports` size guard (4096); use `toEndpointsUnbounded` to bypass. |
| `toEndpointsUnbounded` | `Listener → [Endpoint]` | No size guard. Caller's responsibility. |
| `endpoint` | `Int → Listener → Endpoint` | Pick the n-th port from the range as a concrete endpoint. Operator-first curry order, parallels `cidr.host`. Throws on null address or out-of-range n. |

**Comparison**: `eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max` — compare by `(version, address, portRange)`. Null address sorts before any non-null address. Mixed family follows the lenient v4-before-v6 rule.

### `libnet.ipRange`

Non-CIDR contiguous address range (e.g., `10.0.0.1-10.0.0.50`). Parallels `cidr` as a network-block abstraction but without alignment constraints. Useful for firewall iprange rules and DHCP pools.

**Parsing & formatting**
| `parse` | `String → IpRange` | `"1.2.3.4-1.2.3.10"` or `"2001:db8::1-2001:db8::ff"`. Throws on malformed, wrong ordering (`to < from`), or mixed families. |
| `tryParse` | `String → TryResult IpRange` |
| `toString` | `IpRange → String` | Canonical `from-to`. |
| `make` | `(Ipv4 | Ipv6) → (Ipv4 | Ipv6) → IpRange` | Same family required; throws if `to < from`. |
| `singleton` | `(Ipv4 | Ipv6) → IpRange` | Range containing exactly one address. |

**Predicates**
| `isValid` | `String → Bool` |
| `is` | `Any → Bool` |
| `isIpv4` / `isIpv6` | `IpRange → Bool` |
| `isSingleton` | `IpRange → Bool` |

**Accessors**
| `from` / `to` | `IpRange → (Ipv4 | Ipv6)` |
| `size` | `IpRange → Int` | `ipToInt(to) - ipToInt(from) + 1`. Throws on IPv6 ranges wider than 2⁶³ addresses. |
| `version` | `IpRange → Int` |

**Containment & relationships**
| `contains` | `IpRange → (Ipv4 | Ipv6) → Bool` |
| `overlaps` | `IpRange → IpRange → Bool` | Symmetric. |
| `isSubrangeOf` | `IpRange → IpRange → Bool` |
| `isSuperrangeOf` | `IpRange → IpRange → Bool` |
| `merge` | `IpRange → IpRange → (IpRange | null)` | Unified range if adjacent or overlapping, else `null`. |

**Enumeration**
| `addresses` | `IpRange → [(Ipv4 | Ipv6)]` | Enumerate all addresses. Throws if `size > 2¹⁶`; use `addressesUnbounded` to bypass. |
| `addressesUnbounded` | `IpRange → [(Ipv4 | Ipv6)]` | No size guard. |

**CIDR interop**
| `toCidrs` | `IpRange → [Cidr]` | Minimal set of CIDRs exactly covering this range. Inverse of a naive CIDR-to-range. |
| `fromCidr` | `Cidr → IpRange` | Convert a CIDR block into a range (network..broadcast or network..last for IPv6). |

**Comparison**: `eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max` — lexicographic on `(family, from, to)`. Lenient cross-family rule.

### `libnet.interface`

Interface descriptor covering *address-on-a-subnet* (Python's `IPv4Interface` / `IPv6Interface`), *Linux interface name* (kernel `dev_valid_name`), or both combined. Distinct from CIDR (which says "here is network Y"). Typical use: per-NIC config, firewall rules that reference `eth0`, named address assignments.

**Parsing & formatting**
| `parse` | `String → Interface` | `"192.168.1.5/24"` — addr-only shape. Same text as a CIDR string, distinguished by type tag. Address preserved as the host (NOT zeroed to network). IPv6: `"2001:db8::5/64"`. Throws on malformed input, prefix out of range, or bare names (use `parseName`). Output has `name = null`. |
| `tryParse` | `String → TryResult Interface` |
| `parseName` | `String → Interface` | Bare ifname like `"eth0"`. Output has `address = null`, `prefix = null`. Throws on kernel-invalid names per `dev_valid_name`. |
| `tryParseName` | `String → TryResult Interface` |
| `toString` | `Interface → String` | Addr-only → `<address>/<prefix>`. Name-only → `<name>`. Named+addr → `<address>/<prefix>` (name is metadata; access via `name iface`). Always total. |
| `make` | `(Ipv4 | Ipv6) → Int → Interface` | Construct addr-only; validates prefix range for family. |
| `makeName` | `String → Interface` | Construct name-only; validates per `dev_valid_name`. |
| `makeNamed` | `(Ipv4 | Ipv6) → Int → String → Interface` | Construct named+addr; validates both the addr+prefix and the name. |
| `fromAddressAndNetwork` | `(Ipv4 | Ipv6) → Cidr → Interface` | Validates `address ∈ network`. Output has `name = null`. |

**Combinators**
| `withName` | `String → Interface → Interface` | Attach or replace the name. Validates. |
| `withAddress` | `(Ipv4 | Ipv6) → Int → Interface → Interface` | Attach or replace the addr+prefix. Validates. Preserves `name`. |

**Predicates**
| `isValid` | `String → Bool` | Accepts `<addr>/<prefix>` form only. Bare names return false (use `isValidName`). |
| `isValidName` | `String → Bool` | Pure kernel-parity check: non-empty, length < 16, not `.` / `..`, no `/`, `:`, or whitespace. |
| `is` | `Any → Bool` |
| `isIpv4` / `isIpv6` | `Interface → Bool` | Return false on name-only values (never throw). |
| `hasName` / `hasAddress` | `Interface → Bool` |

**Accessors**
| `name` | `Interface → String | null` |
| `address` | `Interface → Ipv4 | Ipv6 | null` | Null on name-only. |
| `prefix` | `Interface → Int | null` | Null on name-only. |
| `network` | `Interface → Cidr` | Canonical network containing the host. Throws on name-only. |
| `netmask` / `hostmask` | `Interface → Ipv4 | Ipv6` | Throws on name-only. |
| `version` | `Interface → Int | null` | Null on name-only; 4 or 6 otherwise. |
| `broadcast` | `Interface → Ipv4` | IPv4 only; throws on name-only or IPv6. |

**Conversions**
| `toCidr` | `Interface → Cidr` | Drops the host address, returns the network. Throws on name-only. |
| `toRange` | `Interface → IpRange` | Convert the network to a range. Throws on name-only. |

**Comparison**: `eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max`. `eq` is field-wise null-safe. `compare` is a strict total order: addr-present values sort before name-only values; within addr-present, `(family, address, prefix, null-name-first, name-lex)`; within name-only, name lex. Preserves every legacy ordering of two addr-only values.

### `libnet.withLib` (opt-in NixOS module types)

Calling `libnet.withLib lib` returns libnet augmented with a `types` attrset of NixOS-compatible option types. The caller supplies `nixpkgs.lib`; the core library never imports it. Downstream shape:

```nix
let
  libnet' = (import ./nix-libnet {}).withLib pkgs.lib;
  inherit (libnet') types;
in {
  options.mySvc.bind        = mkOption { type = types.ipv4;     default = "0.0.0.0"; };
  options.mySvc.bind6       = mkOption { type = types.ipv6;     default = "::"; };
  options.mySvc.macAddr     = mkOption { type = types.mac;      example = "aa:bb:cc:dd:ee:ff"; };
  options.mySvc.allowedCidr = mkOption { type = types.ipv4Cidr; default = "10.0.0.0/8"; };
  options.mySvc.listeners   = mkOption { type = lib.types.listOf types.ip; default = []; };

  # Downstream code parses when it needs structure:
  config.services.my-service.gatewayOctets =
    libnet.ipv4.toOctets (libnet.ipv4.parse config.mySvc.bind);
}
```

**Exported types**:
| Type | Accepts | Merged value shape |
|---|---|---|
| `types.ipv4` | String (dotted-quad). Validates parseable. | String (input preserved; IPv4 has a single canonical form). |
| `types.ipv6` | String (any canonical form). Validates parseable. | String (input preserved; multiple input forms accepted, not normalized on merge). |
| `types.ip` | String (v4 or v6). Validates parseable by either family. | String (input preserved). |
| `types.mac` | String (any of four formats). Validates parseable. | String (input preserved; not normalized to canonical colon form). |
| `types.cidr` | String (`<addr>/<n>`). Validates parseable. | String (input preserved). |
| `types.ipv4Cidr` | String. Validates parseable AND family is IPv4. | String. |
| `types.ipv6Cidr` | String. Validates parseable AND family is IPv6. | String. |
| `types.port` | Int (0..65535) or String (decimal digits). | Int — coerced from string if needed. Ports are the one case where int is the more natural representation. |
| `types.portRange` | String (`from-to` or single `port`). | String. |
| `types.endpoint` | String (RFC 3986 `host:port` or `[IPv6]:port`). | String. |
| `types.listener` | String (`[ADDR]:PORT[-END]`, wildcard accepted). | String. |
| `types.ipRange` | String (`from-to`). | String. |
| `types.interface` | String (`<addr>/<prefix>`, host bits preserved). | String. |
| `types.ipv4Interface` / `types.ipv6Interface` | As above, family-restricted. | String. |

**Behavior**:
- **Option values remain strings after merge**, matching existing NixOS idioms (`networking.*.address`, `networking.hostName`). No coercion to parsed attrsets during module eval. Downstream consumers call `libnet.ipv4.parse`, `libnet.cidr.parse`, etc. explicitly when structural access is needed.
- Each type's `check` function calls the core library's `isValid` predicate — one source of truth for validity, no drift between module eval and runtime parsing.
- Each type exposes a smart-constructor attribute `.mk str` that validates the input string and returns the same string unchanged (fails loudly on bad input). Useful for `default`/`example` fields where you want early validation without leaving raw strings unchecked.
- Each type carries a `description` and `descriptionClass` suitable for auto-generated option docs (RFC 42 option description format).
- `types.ipv4Cidr` and `types.ipv6Cidr` additionally validate that the parsed CIDR is the correct family; rejecting cross-family strings with a clear error.
- Default and merge behavior matches `types.str`: last-wins unless a `mergeEqualOption`-style type variant is requested later.

**Why opt-in rather than always-on**: libnet's core must be usable by projects that deliberately avoid `nixpkgs.lib` (e.g., tooling, CI scripts, small flakes that don't import nixpkgs). `withLib` is a single function call that returns a strict superset of the core library, so consumers that do use nixpkgs pay no ergonomic cost.

### Internal modules (not exposed)

`lib/internal/*.nix` is **not** reachable through the public `libnet` attrset. The top-level `default.nix` does not re-export them. Tests and sibling modules import them by relative path (`import ./internal/bits.nix`). This keeps the public API minimal and lets refactoring of internals happen without API churn.

Modules in scope:
- `internal/parse.nix` — `octet`, `hexGroup`, and other parser fragments.
- `internal/format.nix` — `hex2`, `hex4`, zero-run compression for IPv6.
- `internal/bits.nix` — `shl`, `shr`, `mask`, `pow2` (shift emulation using `* 2^n` and `div`).
- `internal/carry.nix` — `add32`, `sub32` add-with-carry primitives used by IPv6 arithmetic.
- `internal/types.nix` — `_type` tag constants, structural predicates, `tryResult` constructor.

External users who genuinely need these primitives can import by path; they are aware it's off-contract.

## Error Handling

Two patterns, used consistently:

**Throwing form** — `parse`, `fromInt`, `add` on overflow, `host` on out-of-range, `subnet` on size explosion, `toIpv4Mapped` on non-mapped addresses. Throws via `builtins.throw "libnet: <context>: <reason>"`. Error messages always prefixed with `"libnet:"` for grep-ability.

**Recoverable form** — only `tryParse` for each type. Returns `{ success; value; error; }`. All other recoverable paths are modeled as predicates (`isValid`, `isCanonical`, `contains`, ...).

Rationale: a proliferation of `tryAdd`, `tryNext`, `tryHost` would double the surface area for little gain. Callers who need safety on arithmetic should guard with `contains`/range checks first; parsing is the one place untrusted input enters, so that gets the full try-surface.

## Repository Layout

```
nix-libnet/
├── default.nix              # Top-level entry. Imports and composes submodules into `libnet.*`.
├── flake.nix                # Optional flake wrapper (lib.libnet). Library is usable without flakes.
├── lib/
│   ├── ipv4.nix
│   ├── ipv6.nix
│   ├── mac.nix
│   ├── cidr.nix
│   ├── ip.nix               # Unified dispatch namespace
│   ├── port.nix
│   ├── port-range.nix
│   ├── endpoint.nix
│   ├── listener.nix
│   ├── ip-range.nix
│   ├── interface.nix
│   ├── types.nix            # NixOS module types factory (consumes injected `lib`)
│   ├── with-lib.nix         # `withLib lib` entry point, composes types.nix
│   └── internal/
│       ├── bits.nix         # Shift emulation, mask helpers
│       ├── carry.nix        # u32 add/sub with carry propagation
│       ├── parse.nix        # Shared parse primitives (octet, hex group, etc.)
│       ├── format.nix       # Shared format primitives (hex padding, zero-run compression)
│       └── types.nix        # _type tags, predicates, tryResult constructor
├── tests/
│   ├── default.nix          # Imports every test file, runs the harness
│   ├── harness.nix          # Hand-rolled test runner (no nixpkgs dep)
│   ├── ipv4.nix
│   ├── ipv6.nix
│   ├── mac.nix
│   ├── cidr.nix
│   ├── ip.nix
│   ├── port.nix
│   ├── port-range.nix
│   ├── endpoint.nix
│   ├── listener.nix
│   ├── ip-range.nix
│   ├── interface.nix
│   └── types.nix            # Module-type tests; opt-in, require `lib` as arg
├── README.md                # Overview, quick start, API index (links to lib/ files)
├── CHANGELOG.md
└── LICENSE                  # Suggest MIT or 0BSD (user confirms at impl time)
```

## Testing Strategy

**Harness** (`tests/harness.nix`) reimplements the essentials of `lib.runTests` without a nixpkgs dependency. Shape:

```nix
# Input: attrset of { testName = { expr; expected; }; ... }
# Output: attrset of failures only, or {} on success.
# If any failure: builtins.throw with a readable diff.

runTests = tests: let
  results = builtins.mapAttrs (name: t:
    if t.expr == t.expected
    then null
    else { inherit name; expected = t.expected; actual = t.expr; }
  ) tests;
  failures = builtins.filter (v: v != null) (builtins.attrValues results);
in
  if failures == [] then { passed = builtins.length (builtins.attrNames tests); }
  else builtins.throw (formatFailures failures);
```

**Coverage targets**:
- IPv4 parse: valid forms, leading-zero rejection, >255 rejection, wrong-count rejection, empty, whitespace.
- IPv6 parse: compressed, uncompressed, IPv4-mapped, IPv4-compatible, `::`, `::1`, `1::`, triple-colon rejection, >8-group rejection, oversized group rejection, mixed case.
- MAC parse: all four format styles, mixed case, invalid lengths, non-hex.
- CIDR parse: IPv4 and IPv6 blocks, prefix out-of-range, non-canonical, `/0`.
- Arithmetic: overflow at `255.255.255.255 + 1`, underflow at `0.0.0.0 - 1`, carry propagation across IPv6 word boundaries (`::ffffffff + 1` → `:1::`), MAC overflow.
- Predicates: at least one positive and one negative case per predicate.
- CIDR: `network`/`broadcast`/`netmask`/`firstHost`/`lastHost`/`size` for `/0`, `/24`, `/30`, `/31`, `/32`, IPv6 `/0`, `/64`, `/127`, `/128`. `contains` with edge cases at network and broadcast. `subnet`/`supernet` round-trips.
- Round-trip: `toString ∘ parse = id` on canonical inputs; `parse ∘ toString = id` on parsed values.
- Port: parse rejects negative, >65535, empty, non-digit; predicates cover each RFC 6335 range.
- PortRange: parse of single port, `from-to`, `from:to`; `from > to` rejected; `contains`/`overlaps`/`merge` edge cases at adjacency boundaries; `ports` size guard triggers at 4097 (4097-wide range throws, 4096-wide passes); `portsUnbounded` bypasses.
- Endpoint: IPv4 and IPv6 parse both succeed; unbracketed IPv6 rejected with a clear error; missing port rejected; canonical round-trip for each family.
- Listener: `:8080`, `:5500-6000`, `*:80`, `any:80`, `0.0.0.0:80`, `[::]:80` all parse to the expected shape; `isAnyAddress` matches on all wildcard variants; `toEndpoints` respects size guard.
- IpRange: parse of IPv4/IPv6, rejects `to < from` and mixed families; `contains`/`overlaps`/`merge` edge cases; `toCidrs`/`fromCidr` round-trip for aligned ranges and a few unaligned cases; `addresses` size guard at 2¹⁶.
- Interface: parse preserves host address (does NOT zero host bits, unlike CIDR); `toCidr` extracts network; equality semantics distinguish `192.168.1.5/24` from `192.168.1.5/25` and from a bare CIDR value.
- Reverse DNS: `toArpa` for representative IPv4 and IPv6 addresses; round-trip through a DNS name parser not required (we only emit).
- EUI-64: `mac.toEui64` output matches RFC 4291 § 2.5.1 for known vectors; `ipv6.fromEui64` composes correctly with a `/64` prefix and throws for prefixes > 64.
- CIDR algebra: `summarize` collapses adjacent pairs and drops sub-ranges, preserves order, handles mixed families by partitioning; `exclude` produces minimal covering lists with hand-checked expected outputs; `intersect` returns `null` when no overlap.
- Registry well-known ports: every entry in `registry.wellKnownPorts.{tcp,udp}` lifts to a valid Port via `port.fromInt`; shared names across tcp/udp map to the same integer.
- Bogon: `ip.isBogon (ipv4.parse "127.0.0.1") == true`, `ip.isBogon (ipv4.parse "8.8.8.8") == false`, parallel IPv6 cases.
- Module types (via `withLib`): each `types.*` accepts valid strings unchanged, rejects malformed input with a useful error pointing at the offending option path, and merges last-wins. Mixed-family rejection for `types.ipv4Cidr`/`types.ipv6Cidr`. Smart constructor `types.*.mk` validates and fails loudly on bad input. These tests are exercised by the `full` flake check, which injects `nixpkgs.lib`; the `core` check runs with `lib = null` and skips them, proving the core stays dep-free.

**Invocation**: `nix flake check` must build both `checks.<system>.core` and `checks.<system>.full` successfully. A failing test aborts `.drv` instantiation via `builtins.throw` with the harness's formatted diff.

## Test Coverage Matrix (100% target)

The spec requires 100% coverage of the public API with explicit edge cases. Every row below is a must-have before a module ships.

### Universal rules

1. **Every public function** has at least one positive test.
2. **Every `throws` branch** has a dedicated negative test.
3. **Every predicate** has at least one positive and one negative case.
4. **Every parseable type** round-trips: `x == parse (toString x)` on canonical values, and `s == toString (parse s)` on canonical strings.
5. **Every error message** begins with `libnet:` (assertion on error prefix via `builtins.tryEval`).
6. **Every curry form** is exercised with partial application (`map (add 1) list`) at least once per type.

### Per-type edge cases

**IPv4**
- Parse: `0.0.0.0`, `255.255.255.255`, `1.2.3.4`, `127.0.0.1`.
- Reject: empty, `"1.2.3"`, `"1.2.3.4.5"`, `"1.2.3.256"`, `"01.2.3.4"` (leading zero), `"1.2.3.-1"`, `" 1.2.3.4"` (whitespace), `"a.b.c.d"`.
- Arithmetic: `255.255.255.255 + 1` throws, `0.0.0.0 - 1` throws, `1.2.3.4 + 0 == 1.2.3.4`.
- Predicates positive+negative for each: `isLoopback`, `isPrivate` (one from each RFC 1918 block), `isLinkLocal`, `isMulticast`, `isBroadcast`, `isUnspecified`, `isReserved`, `isDocumentation` (one from each block), `isGlobal`, `isBogon`.
- `toArpa`: known vector `1.2.3.4 → "4.3.2.1.in-addr.arpa"`.
- Round-trip: `toOctets ∘ fromOctets`, `toInt ∘ fromInt`, `toString ∘ parse`.

**IPv6**
- Parse: `::`, `::1`, `1::`, `1::2`, `1:2::3:4`, `::ffff:1.2.3.4` (mapped), `::1.2.3.4` (compatible), uppercase, lowercase, mixed case, all 8 groups explicit, compression at each position.
- Reject: `:::` (triple colon), `::1::` (two compressions), `1:2:3:4:5:6:7:8:9` (9 groups), `12345::` (oversize group), empty, trailing colon (except compressions).
- Carry: `::ffffffff + 1 == ::1:0:0` (word-boundary carry), `::1:0:0:0 - 1 == ::ffff:ffff:ffff` (borrow), all-ones + 1 throws.
- Each predicate positive+negative including `isIpv4Mapped`, `is6to4`, `isUniqueLocal`, `isBogon`.
- `toArpa`: known vector `2001:db8::1 → "1.0.0...0.8.b.d.0.1.0.0.2.ip6.arpa"` (verify 32 nibbles, reversed).
- `fromEui64`: MAC `aa:bb:cc:dd:ee:ff` with prefix `2001:db8::/64` yields `2001:db8::a8bb:ccff:fedd:eeff` (u/l bit flipped).
- `toStringExpanded` / `toStringCompressed` / `toStringBracketed` — each has a distinct expected output for the same parsed value.
- Round-trip through `fromWords`/`toWords`, `fromGroups`/`toGroups`, `fromBytes`/`toBytes`.

**MAC**
- Parse: all four formats (`aa:bb:cc:dd:ee:ff`, `aa-bb-cc-dd-ee-ff`, `aabb.ccdd.eeff`, `aabbccddeeff`), uppercase, lowercase, mixed case.
- Reject: 5-octet, 7-octet, non-hex (`gg:...`), wrong separator count, extra whitespace.
- Predicates: `isUnicast`/`isMulticast` on boundary MACs (`01:…`, `02:…`), `isUniversal`/`isLocal`, `isBroadcast`, `isZero`.
- Bit setters: `setLocal` on a universal MAC flips exactly bit 1 of octet 0; `setLocal` is idempotent on locals.
- OUI: `oui (parse "11:22:33:44:55:66") == 0x112233`, `nic == 0x445566`, `fromOuiNic 0x112233 0x445566` round-trips.
- `toEui64` for `aa:bb:cc:dd:ee:ff` gives `[0xa8, 0xbb, 0xcc, 0xff, 0xfe, 0xdd, 0xee, 0xff]` (u/l bit flip + FFFE insertion verified against RFC 4291 example).
- Arithmetic overflow at `ff:ff:ff:ff:ff:ff`.

**CIDR**
- Parse: `/0`, `/1`, `/24`, `/30`, `/31`, `/32` IPv4; `/0`, `/64`, `/127`, `/128` IPv6; reject `/33` IPv4, `/129` IPv6, `/-1`, `/a`.
- Non-canonical: `10.0.0.5/24` parses fine, `isCanonical` returns false, `canonical` zeros host bits.
- Derived values for each prefix size: `network`, `broadcast` (IPv4 only — `broadcast` throws for IPv6), `netmask`, `hostmask`, `firstHost`, `lastHost`, `size`, `numHosts`.
  - `/31` and `/32` IPv4: `firstHost == network`, `lastHost == broadcast-or-top`, `numHosts ∈ {1, 2}`.
  - `/127` and `/128` IPv6: analogous.
  - `/0` IPv4: `size == 2^32`, `/0` IPv6: `size` throws (too large).
- `host n`: positive `n`, negative `n` (from end), `n == 0`, out-of-range throws.
- `hosts`: returns list for `/24`; throws on `/15` (> 2¹⁶); `hostsUnbounded` works.
- `contains`: address at `network`, at `broadcast`, at `network-1`, at `broadcast+1`, with a sub-CIDR of the same family, cross-family (returns `false`).
- `isSubnetOf`/`isSupernetOf`: both directions, equal CIDRs (both true), disjoint (both false), cross-family (both false).
- `overlaps`: overlapping, disjoint, equal, adjacent.
- `subnet 2 (/24)` returns four `/26`s in order; `subnet 0` returns `[c]` (identity); `subnet n` that exceeds prefix max throws.
- `supernet 1 (/24)` returns `/23`; `supernet` from `/0` throws.
- `summarize`: `[10.0.0.0/25, 10.0.0.128/25]` coalesces to `[10.0.0.0/24]`; mixed families partitioned; duplicates removed; unrelated blocks preserved.
- `exclude 10.0.0.0/24 10.0.0.0/26` returns `[10.0.0.64/26, 10.0.0.128/25]`; excluding self returns `[]`; excluding non-child throws.
- `intersect`: overlapping returns smaller; disjoint returns `null`; equal returns identity.

**IP (unified)**
- `parse` detects family from `:` presence. IPv4 inputs return `_type="ipv4"`, IPv6 inputs return `_type="ipv6"`.
- `version` returns `4` / `6`.
- `compare` v4 vs v6: v4 always less. `eq` across families always false.
- `isBogon` dispatches correctly by family.
- `toArpa` dispatches correctly by family.

**Port**
- Parse `0`, `65535`, `1`, `80`. Reject `65536`, `-1`, `+80`, `0x50`, empty, `" 80"`.
- Predicates: `isWellKnown 22` true, `isWellKnown 1024` false, `isRegistered 1024` true, `isDynamic 49152` true, `isReserved 0` true.
- Arithmetic: `65535 + 1` throws, `0 - 1` throws.
- Registry well-known ports: spot checks for a handful of entries (e.g. `registry.wellKnownPorts.tcp.http == 80`) and fold-based validation that every integer is in range and `port.fromInt`-liftable.

**PortRange**
- Parse: `8080` (singleton), `5500-6000`, `5500:6000` (iptables), equal from/to.
- Reject: `6000-5500` (from > to), `-1-10`, `0-65536`, empty.
- `contains`, `overlaps` (touching vs disjoint), `isSubrangeOf`, `merge` (adjacent `5500-5600` + `5601-5700` → `5500-5700`, non-adjacent returns null).
- `size` boundaries: singleton = 1, full range `0-65535` = 65536.
- `ports` on 4096-wide range works; on 4097-wide range throws; `portsUnbounded` works.

**Endpoint**
- Parse: `1.2.3.4:80`, `[::1]:80`, `[2001:db8::1]:443`.
- Reject: `::1:80` (unbracketed IPv6), `1.2.3.4` (no port), `[1.2.3.4]:80` (bracketed IPv4), `:80` (no address), `1.2.3.4:70000` (port overflow), `1.2.3.4:` (empty port).
- Round-trip IPv4 and IPv6.
- `isLoopback` on `127.0.0.1:80` true, `isLoopback` on `[::1]:80` true, false elsewhere.
- `compare` orders by (version, address, port); mixed-family v4 first.

**Listener**
- Parse: `:8080`, `*:8080`, `any:8080`, `0.0.0.0:8080`, `[::]:8080`, `:5500-6000`, `1.2.3.4:5500-6000`, `[::1]:5000-5000` (singleton range).
- Reject: `::1:80` (unbracketed IPv6), invalid port, `5500-` (open range).
- `isAnyAddress` true for all four wildcard forms (null, `0.0.0.0`, `::`, `*`/`any` after parse).
- `isRange` true iff portRange size > 1.
- `toEndpoints` on non-wildcard listener with 10-port range yields 10 endpoints in ascending order; throws on null address; respects size guard.
- `endpoint n listener`: valid `n`, boundary `n`, out-of-range throws, null address throws.

**IpRange**
- Parse: `1.2.3.4-1.2.3.10` (IPv4), `2001:db8::1-2001:db8::ff` (IPv6), singleton `1.2.3.4-1.2.3.4`.
- Reject: mixed families `1.2.3.4-::1`, reversed `1.2.3.10-1.2.3.4`, missing dash, single address without range form.
- `contains`, `overlaps`, `merge` (adjacent yields combined, disjoint yields null).
- `toCidrs`: aligned range `10.0.0.0-10.0.0.255` → `[10.0.0.0/24]`; unaligned `10.0.0.1-10.0.0.6` → `[10.0.0.1/32, 10.0.0.2/31, 10.0.0.4/31, 10.0.0.6/32]`.
- `fromCidr (parse "10.0.0.0/24") == ipRange "10.0.0.0-10.0.0.255"`.
- `size` guard: 2¹⁶ addresses works; one larger throws.

**Interface**
- Parse: `192.168.1.5/24` preserves `192.168.1.5` as `address` (not zeroed).
- `network` derives `192.168.1.0/24` (canonical).
- `toCidr` extracts the network.
- Distinction from CIDR: `cidr.parse "192.168.1.5/24"` and `interface.parse "192.168.1.5/24"` produce values that are NOT `eq` (different `_type`).
- Reject: prefix out of range, empty prefix, missing `/`, bare name (use `parseName`).
- `isValidName` kernel-parity coverage: reject empty, 16-byte, `.`, `..`, strings containing `/`, `:`, or any `isspace(3)` byte (SP, HT, LF, VT, FF, CR); accept up to 15 bytes of anything else (dash, dot-in-middle, underscore).
- `parseName`: produces a name-only value with `address = null`, `prefix = null`.
- `withName`: attaches/replaces `name`; throws on invalid. `withAddress`: attaches/replaces addr+prefix; preserves name.
- Address-dependent accessors (`network`, `netmask`, `hostmask`, `broadcast`, `toCidr`, `toRange`) throw with `libnet.interface.<fn>: name-only interface has no <thing>` on name-only values. `isIpv4` / `isIpv6` / `version` return false / null respectively (no throw).
- `toString` on a named+addr value emits only `<addr>/<prefix>` (name is metadata; access via `name iface`).
- `compare` strict total order: addr-present < name-only; within addr-present, (family, address, prefix, null-name-first, name-lex); within name-only, name lex.

**Module types** (via `withLib`, opt-in)
- Each `types.*.check` returns true for valid strings, false for invalid.
- Each `types.*.mk` returns the input unchanged on valid, throws on invalid with a libnet-prefixed error.
- `types.ipv4Cidr.check "2001:db8::/32"` returns false (wrong family).
- `types.listener.check ":8080"` returns true.
- Merge of two equal option values: last wins.
- `description` field is non-empty for each type.

### Coverage verification

The test harness's `runTests` output includes `{ passed = N }`. The implementer is expected to match N against a golden count per module (e.g., `tests/ipv4.nix` must report ≥ 60 passing cases). Coverage omissions are caught by code review of the test files against this matrix.

## Implementation Phasing (post-spec)

Once the spec is approved, implementation proceeds in dependency order:

1. **`lib/internal/bits.nix`** + tests — shift emulation, mask generation. No dependencies.
2. **`lib/internal/types.nix`** — `_type` tags, `tryResult` constructor.
3. **`lib/internal/parse.nix`** + **`lib/internal/format.nix`** — reusable primitives.
4. **`lib/ipv4.nix`** + tests — simplest family, validates harness and primitives.
5. **`lib/mac.nix`** + tests — parallel to ipv4, exercises parse-format variants.
6. **`lib/internal/carry.nix`** + tests — needed for ipv6 arithmetic.
7. **`lib/ipv6.nix`** + tests — largest module; parsing is the hardest piece.
8. **`lib/cidr.nix`** + tests — composes on top of ipv4/ipv6.
9. **`lib/ip.nix`** + tests — thin dispatch layer, includes `isBogon` and `toArpa` dispatch.
10. **`lib/ip-range.nix`** + tests — depends on ipv4/ipv6/cidr.
11. **`lib/interface.nix`** + tests — depends on ipv4/ipv6/cidr.
12. **`lib/port.nix`** + tests — trivial type plus well-known-port constants; unblocks endpoint/listener.
13. **`lib/port-range.nix`** + tests — depends on `port`.
14. **`lib/endpoint.nix`** + tests — depends on `ipv4`, `ipv6`, `port`.
15. **`lib/listener.nix`** + tests — depends on `ipv4`, `ipv6`, `portRange`.
16. **`lib/types.nix` + `lib/with-lib.nix`** + tests — NixOS module type wrappers; tests require `lib` as arg and are skipped from the default suite.
17. **`default.nix`** — compose everything into a single attrset exposing core API + `withLib`.
18. **README.md** — usage, API index, `withLib` example.

Reverse-DNS (`toArpa`), bogon predicate, and EUI-64 land within the respective family modules (ipv4, ipv6, mac) rather than as their own phases — they're small additions.

Each phase is mergeable independently; tests gate each phase.

## Verification Criteria for the Spec

The spec is ready to implement when:

- [x] Every function in the API tables has a signature and a one-line description.
- [x] Every data type has its invariants written down.
- [x] Every throwing case is marked.
- [x] Every edge case (IPv4 `/31`/`/32`, IPv6 `::`, MAC broadcast) has a decided behavior.
- [x] Internal representation is fixed for each family.
- [x] Repo layout is fixed.
- [x] Minimum Nix version is fixed.
- [x] Test harness approach is fixed.
- [x] Non-goals are explicit.
- [x] Module-type integration path (`libnet.withLib`) is specified, including exported type set and coercion behavior.
- [x] Test coverage matrix is exhaustive: every public function, every `throws` branch, every predicate (positive and negative), every parse dialect, every arithmetic carry/borrow case, every CIDR prefix boundary (`/0`, `/31`, `/32`, `/127`, `/128`, out-of-range rejects), every enumeration size guard, every cross-family behavior.
- [x] Future Work roadmap is documented so contributors know what's deferred and what is an explicit non-goal.

All boxes are checked. Implementation can begin as soon as the user approves this spec.

## Future Work (Post-v1 Roadmap)

Items below are deliberately excluded from v1 but would be worth adding in subsequent versions. This section should be preserved in `README.md` once the library ships, so contributors and consumers know what's on the horizon.

### Deferred to v2 — high-value, moderate effort

| Feature | Sketch | Why deferred |
|---|---|---|
| **Deterministic address assignment** | `cidr.assignIps :: Cidr → [Ipv4] → [String] → { hostname: Ipv4 }` — hash-based stable distribution of addresses from a pool to a set of hostnames. `mac.assignMacs` analog. | Oddlama has this; very useful for NixOS multi-host configs. Requires a hashing primitive (SHA-256 over strings) — adds complexity we don't need for the core types. |
| **Random / locally-administered MAC** | `mac.randomLocal :: String → Mac` — derive a stable locally-administered unicast MAC from a seed string. | Useful for VMs and containers. Overlaps with `assignMacs`. |
| **Unix domain socket paths in Listener** | Extend `Listener` to accept `/run/svc.sock` as an alternative address form. | Systemd `ListenStream=` accepts these; expands the type materially. Worth a v2 because listener is already the "server side" type. |
| **IPv6 zone identifiers** | Support `fe80::1%eth0`, add `ipv6.zone` accessor. | Rare in static Nix configs. Adds a fifth field to the IPv6 data model or a wrapper type. |
| **Port service name reverse lookup** | `port.serviceName :: Port → (String | null)` — `80 → "http"`. | Inverse of well-known constants. Small addition once the constants table is stable. |
| **Solicited-node multicast derivation** | `ipv6.toSolicitedNode :: Ipv6 → Ipv6` per RFC 4291 § 2.7.1. | Genuinely useful for NDP configurations. Small. |
| **5-tuple flow type** | `{ srcAddr; srcPort; dstAddr; dstPort; protocol }` for netfilter-style rules. | Protocol label is its own question (TCP/UDP/SCTP enum); cleaner as a separate submodule. |
| **Route type** | `{ destination: Cidr; via: Ipv4 | Ipv6; metric: Int; }` with comparison and validation. | Parallels `networking.interfaces.*.ipv4.routes` in NixOS but pure-Nix. |
| **Address block registry** | `ip.blockInfo :: Ipv4 → { name; rfc; description }` — identify which RFC-reserved block an address belongs to. | Readable output for diagnostic tools; modest data table. |
| **Bigger-than-2⁶³ IPv6 range support** | Multi-word size computations, so `range.size (range.parse "::-::ffff:ffff:ffff:ffff")` returns without throwing. | Niche; the size guard is mostly about preventing accidental eval blow-ups. |

### Deferred to v2+ — specialized or uncertain demand

| Feature | Why uncertain |
|---|---|
| **Flow-state / connection-tracking abstraction** | Covers rate-limit and connlimit rule generation. Depends on the netfilter/nftables model chosen. |
| **DHCP lease representation** | `{ mac; ip; expiry; hostname }` tuple for config generation. Niche. |
| **ARP/NDP table representation** | Static ARP entries in firewall scripts. Niche. |
| **Advanced subnet partitioning** | "Split this /16 into 4 equal /18s, 8 equal /19s, and 16 /20s based on host counts" — constraint solver. Complex. |
| **IPv4-to-IPv6 migration tooling** | 6to4 tunnel endpoint derivation, Teredo extraction, NAT64 prefix expansion. Niche. |
| **Subnet set optimization** | Given a list of per-host addresses, propose an optimal subnet layout. Research territory. |

### Hard non-goals — will NOT land (matching Non-Goals section)

- DNS resolution, hostname ↔ IP lookups, live queries of any kind
- URL / URI parsing (beyond the `[addr]:port` authority fragment already covered by Endpoint)
- Full network interface configuration (user builds on top)
- GeoIP, WHOIS, ASN, or any feature requiring external data files
- TLS certificate handling, crypto keys, anything in the security domain
- Packet filtering DSLs, iptables rule construction — too application-specific
- Internationalized Domain Names (IDN) — different problem

### Contribution checklist for future features

A future feature lands in the library only if it:
1. Stays pure-Nix with no `nixpkgs.lib` in the core (module-type adapters in `withLib` are fine).
2. Fits the existing tagged-attrset + namespace convention (no new paradigms).
3. Has 100% test coverage per the matrix above, including edge cases.
4. Documents RFC or specification references where applicable.
5. Doesn't force changes to the v1 public API — additions only.

## Resolved Design Decisions (Formerly Open)

All originally-open questions are resolved:

1. **License:** MIT.
2. **Flake:** optional; `flake.nix` shipped, library also importable via `import ./default.nix {}` without flakes.
3. **Internal modules:** not exposed through the public `libnet` attrset at all. Tests and sibling modules import them by relative path. Internals can be refactored without API impact.
4. **Iteration guards:** `cidr.hosts` throws when the block exceeds 2¹⁶ addresses (IPv4 wider than `/16`, IPv6 wider than `/112`). `portRange.ports` throws above 2¹² (4096) entries. `listener.toEndpoints` follows the portRange guard. Each has a `*Unbounded` sibling that bypasses the check. Indexed access via `cidr.host n`, `listener.endpoint n`, and equivalent is the recommended way to reach entries in large ranges.
5. **Mixed-family comparison in `libnet.ip.compare`:** lenient — IPv4 sorts before IPv6 as a stable tiebreak. Enables `sort` on mixed lists without partitioning. `eq` across families is always false. No separate `compareStrict` variant; callers who need strictness check `ip.version` first.
6. **Module-type coercion:** option values stay strings, matching existing NixOS idioms. Types validate via the core `isValid` predicates but never transform the stored value. Downstream code calls `libnet.ipv4.parse` (or similar) explicitly when structure is needed.
7. **Module-type test dependency:** `tests/types.nix` takes `lib` as a function argument; `tests/default.nix` accepts optional `lib` and routes `types.nix` tests to it only when provided. The flake exposes two checks: `core` (invokes with `lib = null`, proves the dep-free guarantee) and `full` (invokes with `pkgs.lib`, adds module-type coverage). Users run either via `nix build .#checks.<system>.{core,full}` or both via `nix flake check`.

The spec has no remaining open questions. Implementation can begin immediately upon plan approval.
