# Changelog

All notable changes to libnet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `libnet.domain` — tagged multi-label DNS-name type. Requires ≥ 2
  labels; each label follows the same RFC 1123 syntax as
  `libnet.hostname`; total length capped at 253 chars per RFC 1035
  §3.1. API: parse / tryParse / toString / fromLabels / isValid / is,
  accessors (`labels`, `labelCount`), zone arithmetic (`parent`
  returns `Domain | null`, `isSubdomainOf` is reflexive and
  case-insensitive, `toHostname` extracts the leftmost label),
  `normalize` (lowercase), and the full case-insensitive comparison
  suite (`eq` / `lt` / `le` / `gt` / `ge` / `compare` / `min` /
  `max`). No `tld` accessor — RFC 1034's rightmost-label definition
  is misleading without a Public Suffix List. Opt-in module type
  `libnet.types.domain` validates the same shape.
- `lib/internal/dns-label.nix` — internal helper shared by
  `hostname` and `domain` exposing the RFC 1123 single-label
  pattern + `isValidLabel` predicate. Single source of truth for the
  per-label syntax; `hostname` was refactored to consume it.
- `libnet.hostname` — tagged single-label hostname type. RFC 1123
  syntax capped at Linux's `HOST_NAME_MAX - 1` (= 63 effective chars,
  ASCII `[A-Za-z0-9-]`, no leading/trailing hyphen, no underscores,
  no dots). Matches the shape Linux uses for kernel hostnames and
  what `networking.hostName` accepts, minus the latter's undocumented
  underscore allowance. API: parse / tryParse / toString / isValid /
  is / normalize, plus the full comparison suite (eq / lt / le / gt /
  ge / compare / min / max) which is **case-insensitive** per DNS
  semantics — `toString` still preserves the verbatim input case.
  Opt-in module type `libnet.types.hostname` validates the same
  pattern. Multi-label / FQDN names are out of scope here; they
  belong to `libnet.domain` (not yet implemented).
- `libnet.transport` — tagged transport-layer-protocol enum (`tcp`,
  `udp`, `sctp`). Parallels `libnet.port`: tagged value, parse /
  tryParse / toString, `isTcp` / `isUdp` / `isSctp` predicates, `eq`,
  and `tcp` / `udp` / `sctp` constants plus a `values` list of the raw
  strings. Ordering (`lt` / `compare` / `min` / `max`) is intentionally
  omitted — transport protocols have no canonical order. Opt-in module
  type `libnet.types.transport` validates the same value set; merged
  value stays a string. The namespace is `transport` rather than
  `proto` to keep the layer explicit and leave room for separate
  network-layer / application-layer enums in the future.
- Initial specification (`SPEC.md`) covering IPv4, IPv6, MAC, CIDR, Port, PortRange, Endpoint, Listener, Range, Interface types with a pure-Nix, zero-nixpkgs-dependency API.
- Pure-Nix test harness (`tests/harness.nix`) with no external dependencies.
- Full v1 implementation of all 11 type namespaces:
  - `lib/ipv4.nix`, `lib/ipv6.nix`, `lib/ip.nix`, `lib/mac.nix`, `lib/cidr.nix`
  - `lib/port.nix` (with 31 well-known service constants), `lib/port-range.nix`
  - `lib/endpoint.nix`, `lib/listener.nix`, `lib/ip-range.nix`, `lib/interface.nix`
- Internal primitives: `lib/internal/{bits,carry,parse,format,types}.nix`
- Opt-in NixOS module types via `libnet.withLib pkgs.lib` (see `lib/types.nix`).
- `default.nix` + `flake.nix` entry points.
- README with quick start, namespace index, withLib example, test instructions.
- 832 core tests (dep-free) + 53 module-type tests (opt-in with nixpkgs.lib).
- MIT license.

### Changed
- **Breaking**: `libnet.portRange` now stores `from` and `to` as tagged
  `Port` values rather than raw ints. The accessors `portRange.from` /
  `portRange.to` return `Port`; unwrap via `port.toInt` for a bare int.
  Aligns `portRange` with the library-wide tagging convention so any
  first-class sub-value (Port, Ipv4, Ipv6) travels in the same shape
  whether it stands alone or sits inside a composite. `portRange.make`
  still accepts bare ints for ergonomics; `portRange.fromPort`,
  `portRange.size`, `portRange.toString`, and friends are unchanged at
  the call site.
- `libnet.interface` now carries an optional Linux ifname alongside the existing
  address-on-subnet binding. A parsed interface is
  `{ _type; name; address; prefix }` where each of `name`, `address`, `prefix`
  may be null; at least one of `name`/`address` is non-null and `address`↔`prefix`
  are paired. Three valid shapes: addr-only (legacy), name-only, and named+addr.
- New functions: `parseName`, `tryParseName`, `makeNamed`,
  `withName`, `withAddress`, `isValidName`, `name`, `hasName`, `hasAddress`.
- `isValidName` is byte-for-byte kernel `dev_valid_name` parity: non-empty,
  length < `IFNAMSIZ` (16), not `.` / `..`, no `/`, no `:`, no `isspace(3)`
  whitespace.
- `toString` of a named+addr value emits only `<addr>/<prefix>`. The name is
  metadata; access via `interface.name iface`. Linux tooling keeps name and
  address structurally separate and has no widely-adopted single-string
  composite (RFC 4007 `%<zone>` is scoped to IPv6 link-local only and remains
  deferred per SPEC.md Non-Goals).
- `isIpv4` / `isIpv6` / `version` are null-safe on name-only values (return
  false / null; no throw). `network`, `netmask`, `hostmask`, `broadcast`,
  `toCidr`, `toRange` throw with `libnet.interface.<fn>: name-only interface
  has no <thing>`.
- `eq` and `compare` are null-safe across all three shapes. `compare` gives a
  strict total order: addr-present values sort before name-only values; legacy
  ordering between two addr-only values is preserved.
- `parse` / `tryParse` / `isValid` remain strict on the CIDR form — bare names
  still throw / return false (use `parseName` / `isValidName`). The NixOS
  option types `types.interface` / `types.ipv4Interface` / `types.ipv6Interface`
  are unchanged in their accept set.
- **Soft attr-shape change**: parsed interface values now have a `name` key
  (value null for legacy inputs). Consumers that enumerate `builtins.attrNames`
  of an interface value must accept the extra key; all accessor-based consumers
  are unaffected.

### Fixed (during first-pass review)
- `ipv6.isGlobal` previously shortcut to `!isBogon` (a 6-predicate check). The
  spec defines `isGlobal` as "none of the above special categories" which for
  IPv6 also includes `isIpv4Mapped`, `isIpv4Compatible`, and `is6to4`. These
  transition/compat forms are now correctly excluded from `isGlobal`. Regression
  tests added: `global-neg-v4mapped`, `global-neg-v4compat`, `global-neg-6to4`,
  `bogon-excludes-6to4`.

### Cleanup
- Removed unused internal exports: `hexLower`, `joinStrings`, `repeat` from
  `lib/internal/format.nix`; `isDigit`, `isHex`, `digitValues`, `hexValues`
  exports from `lib/internal/parse.nix`. No public API impact.

### Deviations from the approved spec
- **`libnet.port` dropped `min`/`max` constants** (they collided with the `min`/`max`
  comparison functions). Replaced with `lowestValue` (=0) and `highestValue` (=65535)
  as raw ints; `wellKnownMax` and `registeredMax` kept as raw ints.
- **IPv6 `/127` firstHost** returns the network address (both endpoints usable per
  RFC 6164 point-to-point). The spec narrative said `network+1` for /127 which
  contradicted the "analogous to IPv4 /31" intent in the coverage matrix — the
  implementation follows RFC 6164.
- **IPv6 `toString` for IPv4-mapped addresses** emits the mixed form
  (`::ffff:1.2.3.4`) per RFC 5952 § 5 recommendation, instead of pure hex form.
