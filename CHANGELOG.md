# Changelog

All notable changes to libnet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A `tests` flake output with the nix-unit suites, as `tests.systems.<system>.unit` and `unit-core`, and the `nix-unit` flake input that runs them. The input's own inputs follow libnet's `nixpkgs` or are empty, so a consumer's lock file gains one `nix-unit` entry and no second nixpkgs. Consumers can drop it with `inputs.nix-libnet.inputs.nix-unit.follows = "";` ([ADR 0018](docs/adr/0018-nix-unit-flake-module.md)).
- The `treefmt-nix` flake input, which builds `nix fmt` and the `treefmt` check. Its `nixpkgs` follows libnet's, so a consumer's lock file gains one `treefmt-nix` entry and no second nixpkgs. Consumers can drop it with `inputs.nix-libnet.inputs.treefmt-nix.follows = "";` ([ADR 0019](docs/adr/0019-treefmt-nix.md)).
- A `lint` check that runs `statix check`.

### Changed

- **Breaking:** `cidr.parse` and `cidr.make` reject host bits, so `10.0.0.5/24` is no longer a CIDR; parse it with `interfaceAddress` and take its `network`. `types.cidr`, `types.ipv4Cidr` and `types.ipv6Cidr` reject it too. The stored field is now `network`, not `address`, and `cidr.eq` no longer equates a block with host bits to its network ([ADR 0010](docs/adr/0010-interface-address-is-not-cidr.md)).
- **Breaking:** `make` takes a tagged value for every tagged field ([ADR 0004](docs/adr/0004-tagged-values.md)). `portRange.make` takes two `port` values instead of integers: write `portRange.make (port.fromInt 80) (port.fromInt 90)`. `authority.make` and `url.make` take `host` as a `urlHost` value and `port` as a `port` value or `null`: write `host = urlHost.parse "example.com"; port = port.fromInt 8443;`.
- **Breaking:** rename `cidr.hostAt` to `cidr.addressAt` and `cidr.subnet` to `cidr.subnets`. `hostAt` indexed every address from the network address, not the usable hosts that `cidr.hosts` lists, so it now shares `ipRange.addressAt`'s name. `subnets` returns a list, so its name is plural like `hosts`.
- **Breaking (development interface):** run the unit suites through nix-unit's flake-parts module. Replace `checks.<system>.core` and `checks.<system>.full` with `checks.<system>.nix-unit`, which runs them as `unit-core`, without nixpkgs, and `unit`. Replace `nix-unit tests/unit.nix` with `nix-unit --flake .#tests.systems.<system>.unit[.<suite>]`, adding `--attr <test>` for one test. The suites move from `tests/` to `tests/unit/`, whose entry point takes `nixpkgs` instead of `lib`, and their attributes take their file names, such as `bind-url` and `internal.dns-label`.
- **Breaking:** rename `dnsEndpoint.address` to `dnsEndpoint.name`, along with the stored field, because a DNS endpoint holds an unresolved name, not an address. `dnsEndpoint.make` is positional and does not change.
- **Breaking:** rename `host.isName` to `host.isDnsName`, so each union's predicates name its direct members.
- **Breaking:** replace `interfaceName.ifnamsiz` (`16`, the kernel buffer size) with `interfaceName.maxLength` (`15`, the longest valid name).
- Format through treefmt-nix: `nix fmt` runs nixfmt, deadnix, actionlint, and prettier instead of only nixfmt, and `checks.<system>.treefmt` replaces `checks.<system>.formatting`.

### Removed

- **Breaking:** `cidr.address`, `cidr.canonical` and `cidr.isCanonical`; use `cidr.network`, which every CIDR now stores.
- **Breaking:** `interfaceAddress.toCidr`, which built a CIDR with host bits; use `interfaceAddress.network`.
- **Breaking:** the function aliases `ipv4.fromOctets` and `ipv4.toOctets` (use `fromBytes` and `toBytes`, whose errors now name `fromBytes`), `ipv6.toStringCompressed` (use `toString`), `port.isEphemeral` (use `isDynamic`) and `ipBindpoint.isAnyAddress` (use `isWildcard`). The library keeps one name per operation.
- **Breaking:** `host.isHostname` and `host.isDomain`, which tested leaf kinds below `host`'s direct members; use `hostname.is` and `domain.is`, or `dnsName.isHostname` and `dnsName.isDomain`.
- **Breaking:** `interfaceName.value`; use `interfaceName.toString`, as for every other scalar kind.
- **Breaking:** `domain.labelCount`; use `builtins.length (domain.labels d)`.
- **Breaking:** the constants `urlHost.regNamePattern`, the parser's internal grammar, and `unixSocket.sunPathMax`, which gave one limit for two: a pathname socket allows 107 bytes and an abstract name 108.

## [0.1.0] - 2026-10-13

First release. The [API reference](docs/reference/README.md) documents every namespace below.

### Added

- Tagged values (`{ _type = "ipv4"; value = 167772165; }`) with shared suites for parsing (`parse`, `tryParse`, `toString`, `isValid`, `is`), comparison and arithmetic. `eq` returns `false`, without throwing, for values of different kinds and for operands that are not tagged values.
- Addresses:
  - `ipv4`: dotted-quad addresses with integer and octet conversion, reverse-DNS names, and special-purpose block predicates such as `isPrivate` and `isSharedAddressSpace`.
  - `ipv6`: addresses with RFC 5952 canonical text, which prints IPv4-mapped addresses in mixed form (`::ffff:1.2.3.4`); word, group and byte conversion; EUI-64 and IPv4-mapped conversion; and block predicates. `isGlobal` excludes the IPv4-mapped, IPv4-compatible and 6to4 transition forms.
  - `ip`: union of `ipv4` and `ipv6` that dispatches on family.
  - `mac`: MAC addresses in colon, hyphen, Cisco and bare forms, with OUI and NIC parts, unicast/multicast and universal/local bits, and modified EUI-64.
- Networks:
  - `cidr`: blocks of either family with derived addresses, host enumeration, containment and overlap, subnetting, supernetting, summarization, exclusion and intersection. `firstHost`, `lastHost`, `numHosts` and `hosts` exclude the IPv4 network and broadcast addresses and the IPv6 Subnet-Router anycast address, except in IPv4 `/31` (RFC 3021), IPv6 `/127` (RFC 6164) and single-address blocks.
  - `ipRange`: address ranges with CIDR conversion, containment, adjacency and merging.
  - `interfaceAddress`: an address on a subnet, such as `10.0.0.5/24`, that keeps its host bits, with network, mask and range helpers.
- Ports and transports:
  - `port`: ports `0`–`65535` with RFC 6335 class predicates and the integer constants `lowestValue`, `highestValue`, `wellKnownMax` and `registeredMax`.
  - `portRange`: ranges in `from-to` and iptables `from:to` forms, stored as tagged `port` values, with containment, adjacency, merging and enumeration.
  - `transport`: the `tcp`, `udp` and `sctp` enum, parsed case-sensitively.
- Names:
  - `hostname`: single RFC 1123 labels of at most 63 characters, compared case-insensitively.
  - `domain`: names of two or more labels and at most 253 characters, with label access, `parent` and `isSubdomainOf`.
  - `dnsName`: union of `hostname` and `domain` that rejects IP literals.
  - `host`: union of `ip` and `dnsName`.
  - `interfaceName`: Linux interface names, validated like the kernel's `dev_valid_name`.
- Targets:
  - Connect-side `ipEndpoint`, `dnsEndpoint` and `unixSocket` (pathname and abstract sockets), and their union `endpoint`.
  - Bind-side `ipBindpoint`, which accepts wildcard addresses and port ranges such as `:8080` and `[::]:5000-6000`, and the union `bindpoint` of `ipBindpoint` and `unixSocket`.
- URL forms over closed scheme sets, which match schemes case-insensitively and print them lowercase:
  - `socketUrl` (`tcp://1.2.3.4:80`, `unix:///run/foo.sock`) and `bindUrl` (`tcp://:8080`, `udp://0.0.0.0:53`).
  - `secureSocketUrl` for `tls`, `dtls` and `quic`, with `ssl` as an alias of `tls`.
  - `url` for 30 application schemes with default ports, and its parts `urlHost` and `authority`.
  - `proxyUrl` for HTTP, HTTPS and SOCKS proxies.
- Bounded integers `vlanId` (`[1, 4094]`), `mtu` (`[68, 65535]`) and `icmpType` (`[0, 255]`).
- `registry`: bogon blocks, common TCP and UDP service ports, and ICMP and ICMPv6 message types as plain literals.
- NixOS option types through `libnet.withLib lib` for every namespace except `registry`. String types keep the string and merge with `mergeEqualOption`; `port`, `vlanId`, `mtu` and `icmpType` merge to integers.
- A core that uses only Nix 2.18 builtins, imported through `default.nix` or the flake's `lib` output.
- Flake checks, development shell and formatter for `x86_64-linux` and `aarch64-linux`.
- MIT license.

[Unreleased]: https://github.com/petohorvath/nix-libnet/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/petohorvath/nix-libnet/releases/tag/v0.1.0
