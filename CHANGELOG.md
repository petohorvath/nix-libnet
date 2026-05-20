# Changelog

All notable changes to libnet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `libnet.proxyUrl` — the address of a proxy server in URL form,
  `<scheme>://[userinfo@]host:port` (`socks5://127.0.0.1:1080`,
  `http://user:pass@proxy.corp:8080`). A bounded composition of a proxy
  scheme and a `libnet.authority`. Stored as `{ _type = "proxyUrl";
  scheme = <scheme>; authority = <authority value>; }`. Closed scheme
  set: `http`, `https`, `socks4`, `socks4a`, `socks5`, `socks5h`
  (case-insensitive in, lowercase out; the `a`/`h` variants resolve DNS
  at the proxy). The port is required — proxy default ports are not
  standardized. API: parse / tryParse / toString / make / isValid / is
  / scheme / authority + comparison (fixed scheme rank, then authority)
  + `schemes` constant. Opt-in module type `libnet.types.proxyUrl`.
- `libnet.authority` — the URL authority component (RFC 3986 §3.2),
  `[userinfo@]host[:port]`, extracted from `libnet.url` as a first-class
  public type. Stored as `{ _type = "authority"; userinfo = <string |
  null>; host = <urlHost value>; port = <port value | null>; }`. `url`
  now parses its authority through this module (no behaviour change — the
  authority parser and `splitHostPort` moved out of `url.nix`), and the
  type is usable standalone. API: parse / tryParse / toString / make /
  isValid / is / userinfo / host / port + comparison. Comparison is
  structural and **includes** userinfo (an authority is exactly its
  text), with ports compared as-stored — unlike `url`, which ignores
  userinfo and folds scheme-default ports. Opt-in module type
  `libnet.types.authority`.
- `libnet.secureSocketUrl` — a TLS-secured socket address in URL form,
  `<scheme>://<endpoint>` (`tls://1.2.3.4:443`, `dtls://[::1]:5684`,
  `quic://example.com:443`). The secured peer of `socketUrl`: same
  `scheme://host:port` shape, but every scheme implies TLS. Stored as
  `{ _type = "secureSocketUrl"; scheme = <"tls" | "dtls" | "quic">;
  endpoint = <ipEndpoint | dnsEndpoint>; }` — the scheme is the stored
  identity (with `transport` derived) because `dtls` and `quic` are both
  UDP+TLS and a transport-plus-flag form could not tell them apart.
  Closed scheme registry `tls`/`dtls`/`quic`; `ssl` is accepted on parse
  as an alias of `tls` and canonicalized; there is no `unix` scheme and
  no scheme-default port (the endpoint carries an explicit port). API:
  parse / tryParse / toString / make / isValid / is / isSecure (always
  true) / scheme / endpoint / transport + comparison (`tls < dtls <
  quic`, then endpoint) + `schemes` / `aliases` constants. Opt-in module
  type `libnet.types.secureSocketUrl`. The "no general URL parsing"
  non-goal now carves out three bounded forms (`socketUrl`,
  `secureSocketUrl`, `url`).
- `libnet.socketUrl` — a socket address in URL form,
  `<scheme>://<endpoint>` (`tcp://1.2.3.4:80`, `udp://[::1]:53`,
  `unix:///run/foo.sock`). Stored as the underlying `transport` +
  `endpoint` pair (`{ _type = "socketUrl"; transport = <transport |
  null>; endpoint = <endpoint>; }`); `transport` is null iff the
  endpoint is a `unixSocket`. API: parse / tryParse / toString / make
  / isValid / is / isUnix / transport / endpoint + comparison +
  `schemes` constant. Opt-in module type `libnet.types.socketUrl`.
  This is the **only** URL form libnet parses — a bounded composition
  over a fixed scheme set (`tcp`/`udp`/`sctp`/`unix`), explicitly not
  a general URL parser. The "no URL/URI parsing" non-goal was reworded
  to "no *general* URL parsing" to carve out this bounded form; a full
  `url` type remains out of scope.
- `libnet.listener` is now a pass-through union `ipListener |
  unixSocket`, so a service can bind an IP socket **or** a Unix socket
  path. Today's IP listener was renamed to `libnet.ipListener` (tag
  `ipListener`); it keeps the full bind API (wildcards, forwarded
  predicates, `endpoints` materialization). The new `listener` union
  carries no `_type` of its own and exposes parse / toString /
  predicates (`isIpListener` / `isUnixSocket`) / comparison — branch
  to reach a member's API. `types.ipListener` is the strict IP form;
  `types.listener` accepts either. This completes the Unix socket as a
  genuine third address family (it now appears in both the `endpoint`
  and `listener` unions).
- `libnet.endpoint` now also accepts `unixSocket` — the union is
  `ipEndpoint | dnsEndpoint | unixSocket`, dispatching on shape (a
  leading `/` or `@` → unix socket). Because the members are now
  heterogeneous (`unixSocket` has `path`, not `address`/`port`), the
  union dropped its uniform `address`/`port` accessors — branch on
  `isIpEndpoint` / `isDnsEndpoint` / `isUnixSocket` and use the member
  module's accessors. `types.endpoint` accepts socket paths too.
- `libnet.unixSocket` — Unix domain socket address as a tagged value
  (`{ _type = "unixSocket"; path = <string>; }`): a complete connection
  target with no port. Accepts pathname sockets (`/run/foo.sock`, ≤ 107
  bytes — Linux `sun_path` is 108 incl. NUL) and abstract-namespace
  sockets (`@foo`, ≤ 108 bytes displayed). API: parse / tryParse /
  toString / isValid / is / isPathname / isAbstract / path + byte-wise
  case-sensitive comparison + `sunPathMax` constant. Symmetric (binds
  or dials). Opt-in module type `libnet.types.unixSocket`. (First of
  three steps making the Unix socket a genuine address family; the
  `endpoint` and `listener` unions both gained it.)
- `libnet.dnsEndpoint` + `libnet.endpoint` — complete the endpoint
  trio alongside `ipEndpoint`. `dnsEndpoint` is `dnsName:port` (a
  named destination like `pool.ntp.org:123`); it rejects IP literals
  and has no IP-classification predicates (a name is unresolved). New
  `_type` tag `dnsEndpoint`. `endpoint` is the pass-through union
  `ipEndpoint | dnsEndpoint` (no tag): `parse` tries an IP endpoint
  first, so literal addresses come back as full `ipEndpoint` values
  (with predicates) and only genuine names become `dnsEndpoint`.
  Mirrors the `ip`/`dnsName`/`host` address hierarchy:
  `endpoint = ipEndpoint | dnsEndpoint`. Opt-in module types
  `libnet.types.dnsEndpoint` and `libnet.types.endpoint`.
- `libnet.dnsName` — pass-through union over `Hostname` and `Domain`:
  a DNS name that is not an IP literal. Dispatches by label count
  (single → hostname, multiple → domain) and rejects IP literals
  (the one behavioural difference from a bare `domain`, which accepts
  all-numeric dotted forms). No new `_type` tag; returns the
  underlying hostname/domain value. This is the "name" half of
  `host`, which is now composed internally as `ip | dnsName`. Opt-in
  module type `libnet.types.dnsName`.
- `libnet.mtu` — IP MTU as a tagged int in `[68, 65535]`: 68 is RFC
  791's minimum forwarding MTU (and the floor Linux's `ip link set
  mtu` accepts), 65535 is the IPv4 / IPv6 wire-format maximum.
  Syntactic floor only, not a semantic recommendation — real-world
  MTUs typically live in `[1280, 9000]`. Tagged like `libnet.port`
  (`{ _type = "mtu"; value = <int>; }`): `fromInt` / `toInt` /
  `toString` / `isValid` / `is` plus the numeric comparison suite and
  `lowestValue` / `highestValue` constants. No string `parse` (MTUs
  are written as ints). Opt-in module type `libnet.types.mtu` enforces
  the range and coerces to a bare int (like `types.port`).
- `libnet.vlanId` — IEEE 802.1Q VLAN ID as a tagged int in
  `[1, 4094]`; rejects 0 (priority-tagged sentinel) and 4095
  (reserved). Tagged like `libnet.port`: `fromInt` / `toInt` /
  `toString` / `isValid` / `is` plus the numeric comparison suite and
  `lowestValue` / `highestValue` constants. No string `parse`. Opt-in
  module type `libnet.types.vlanId` enforces the range and coerces to
  a bare int (like `types.port`).
- `libnet.host` — pass-through union over `Ipv4`, `Ipv6`, `Hostname`,
  and `Domain`. No new `_type` tag: `parse` returns the underlying
  typed value and consumers branch on `._type`. Dispatch order is
  IP → Hostname → Domain (dotted-quad strings classify as IPs).
  API: parse / tryParse / toString / isValid / is / isIp /
  isHostname / isDomain / isName plus the full cross-family
  comparison suite (`Ipv4 < Ipv6 < Hostname < Domain`; within a
  family, dispatches to that family's own comparator). Opt-in
  module type `libnet.types.host` validates any of the four shapes.
  Same pattern as `libnet.ip` already uses for its v4/v6 split.
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
- Initial specification (`SPEC.md`) covering IPv4, IPv6, MAC, CIDR, Port, PortRange, IpEndpoint, Listener, Range, Interface types with a pure-Nix, zero-nixpkgs-dependency API.
- Pure-Nix test harness (`tests/harness.nix`) with no external dependencies.
- Full v1 implementation of all 11 type namespaces:
  - `lib/ipv4.nix`, `lib/ipv6.nix`, `lib/ip.nix`, `lib/mac.nix`, `lib/cidr.nix`
  - `lib/port.nix` (with 31 well-known service constants), `lib/port-range.nix`
  - `lib/ip-endpoint.nix`, `lib/listener.nix`, `lib/ip-range.nix`, `lib/interface.nix`
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
