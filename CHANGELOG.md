# Changelog

All notable changes to libnet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial specification (`SPEC.md`) covering IPv4, IPv6, MAC, CIDR, Port, PortRange, Endpoint, Listener, Range, Interface types with a pure-Nix, zero-nixpkgs-dependency API.
- Pure-Nix test harness (`tests/harness.nix`) with no external dependencies.
- Full v1 implementation of all 11 type namespaces:
  - `lib/ipv4.nix`, `lib/ipv6.nix`, `lib/ip.nix`, `lib/mac.nix`, `lib/cidr.nix`
  - `lib/port.nix` (with 31 well-known service constants), `lib/port-range.nix`
  - `lib/endpoint.nix`, `lib/listener.nix`, `lib/range.nix`, `lib/interface.nix`
- Internal primitives: `lib/internal/{bits,carry,parse,format,types}.nix`
- Opt-in NixOS module types via `libnet.withLib pkgs.lib` (see `lib/types.nix`).
- `default.nix` + `flake.nix` entry points.
- README with quick start, namespace index, withLib example, test instructions.
- 832 core tests (dep-free) + 53 module-type tests (opt-in with nixpkgs.lib).
- MIT license.

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
