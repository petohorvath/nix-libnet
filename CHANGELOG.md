# Changelog

All notable changes to libnet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A `tests` flake output with the nix-unit suites, as `tests.systems.<system>.unit` and `unit-core`, and the `nix-unit` flake input that runs them. The input's own inputs follow libnet's `nixpkgs` or are empty, so a consumer's lock file gains one `nix-unit` entry and no second nixpkgs. Consumers can drop it with `inputs.nix-libnet.inputs.nix-unit.follows = "";` ([ADR 0018](docs/adr/0018-nix-unit-flake-module.md)).
- The `treefmt-nix` flake input, which builds `nix fmt` and the `treefmt` check. Its `nixpkgs` follows libnet's, so a consumer's lock file gains one `treefmt-nix` entry and no second nixpkgs. Consumers can drop it with `inputs.nix-libnet.inputs.treefmt-nix.follows = "";` ([ADR 0019](docs/adr/0019-treefmt-nix.md)).
- A `lint` check that runs `statix check`.
- `domain.isSuperdomainOf`, the converse of `isSubdomainOf`, so either side of the relation can be partially applied.
- `vlanId.parse`, `mtu.parse` and `icmpType.parse`, with `tryParse`, over decimal text, so every bounded integer has the parsing suite that `port` has.
- `types.vlanId`, `types.mtu` and `types.icmpType` accept a decimal string as well as an integer and merge to an integer, like `types.port`.
- `regName`, the RFC 3986 registered name, as `{ _type = "regName"; value = String; }` with the parsing suite and case-insensitive comparison, and `types.regName`. It rejects text that is a valid IPv4 address, which RFC 3986 reads as an IP literal.
- `transport.compare`, `lt`, `le`, `gt`, `ge`, `min` and `max`, ordering transports by name (`sctp < tcp < udp`) for determinism only.
- Every URL form has `scheme`, `transport` and `isSecure`: `socketUrl` and `bindUrl` gain `scheme` and `isSecure` (always `false`), and `proxyUrl` gains `transport` (always `tcp`).
- `proxyUrl.host`, `proxyUrl.port`, `proxyUrl.userinfo` and `proxyUrl.toEndpoint`, which `url` has too, and `url.authority`.

### Changed

- **Breaking:** `cidr.parse` and `cidr.make` reject host bits, so `10.0.0.5/24` is no longer a CIDR; parse it with `interfaceAddress` and take its `cidr`. `types.cidr`, `types.ipv4Cidr` and `types.ipv6Cidr` reject it too. The stored field is now `networkAddress`, not `address`, and `cidr.eq` no longer equates a block with host bits to its network ([ADR 0010](docs/adr/0010-interface-address-is-not-cidr.md)).
- **Breaking:** `make` takes a tagged value for every tagged field ([ADR 0004](docs/adr/0004-tagged-values.md)). `portRange.make` takes two `port` values instead of integers: write `portRange.make (port.fromInt 80) (port.fromInt 90)`. `authority.make` and `url.make` take `host` as a `urlHost` value and `port` as a `port` value or `null`: write `host = urlHost.parse "example.com"; port = port.fromInt 8443;`.
- **Breaking:** rename `cidr.hostAt` to `cidr.addressAt` and `cidr.subnet` to `cidr.subnets`. `hostAt` indexed every address from the network address, not the usable hosts that `cidr.hosts` lists, so it now shares `ipRange.addressAt`'s name. `subnets` returns a list, so its name is plural like `hosts`.
- **Breaking (development interface):** run the unit suites through nix-unit's flake-parts module. Replace `checks.<system>.core` and `checks.<system>.full` with `checks.<system>.nix-unit`, which runs them as `unit-core`, without nixpkgs, and `unit`. Replace `nix-unit tests/unit.nix` with `nix-unit --flake .#tests.systems.<system>.unit[.<suite>]`, adding `--attr <test>` for one test. The suites move from `tests/` to `tests/unit/`, whose entry point takes `nixpkgs` instead of `lib`, and their attributes take their file names, such as `bind-url` and `internal.dns-label`.
- **Breaking:** rename `cidr.network` to `cidr.networkAddress`, which pairs with `topAddress`, and `interfaceAddress.network` to `interfaceAddress.cidr`, so "network" no longer names both an address and a block.
- **Breaking:** rename `ipv6.fromIpv4Mapped` to `ipv6.fromIpv4`, `ipv6.toIpv4Mapped` to `ipv6.toIpv4` and `ipv6.fromEui64` to `ipv6.fromMac`, following the `from<Input>`/`to<Output>` pattern. Arguments and results are unchanged.
- **Breaking:** `cidr.contains` takes only an address and throws for a CIDR; test a block with `cidr.isSupernetOf`.
- **Breaking:** rename `interfaceAddress.fromAddressAndNetwork` to `interfaceAddress.fromCidrAndAddress` and take the CIDR first, so `map (interfaceAddress.fromCidrAndAddress block) addresses` works.
- **Breaking:** `mac.ouiToString` takes a MAC instead of the integer OUI, like every other `toString*`: write `mac.ouiToString m` for `mac.ouiToString (mac.oui m)`.
- **Breaking:** rename `dnsEndpoint.address` to `dnsEndpoint.name`, along with the stored field, because a DNS endpoint holds an unresolved name, not an address. `dnsEndpoint.make` is positional and does not change.
- **Breaking:** rename `host.isName` to `host.isDnsName`, so each union's predicates name its direct members.
- **Breaking:** replace `interfaceName.ifnamsiz` (`16`, the kernel buffer size) with `interfaceName.maxLength` (`15`, the longest valid name).
- **Breaking:** `vlanId.isValid`, `mtu.isValid` and `icmpType.isValid` take decimal text, like every other `isValid`, so `vlanId.isValid 100` is now `false`. Integer callers use `fromInt` or the module types.
- **Breaking:** `urlHost` is a pass-through union over `ip` and `regName`: `urlHost.parse "[::1]"` returns an `ipv6` value and `urlHost.parse "my_host"` a `regName` value, instead of a `urlHost` value with `kind`, `ip` and `name` fields. `authority.make` and `url.make` accept an `ipv4` or `ipv6` value as the host.
- **Breaking:** `url` stores its authority nested, as `{ _type = "url"; scheme; authority; path; query; fragment; }`, like `proxyUrl`. `url.make` takes `{ scheme; authority; path ? ""; query ? null; fragment ? null; }`: write `authority = authority.make { host = urlHost.parse "example.com"; port = port.fromInt 8443; };`. Read the host, port and userinfo with `url.host`, `url.port` and `url.userinfo` rather than fields.
- **Breaking:** `url.eq` counts userinfo, so `https://alice@h` no longer equals `https://bob@h`, and `url.compare` orders by userinfo after the effective port, `null` first.
- **Breaking:** `url.defaultPort` returns a port value instead of an integer, so `port.eq (url.effectivePort u) (url.defaultPort u)` works directly. Wrap it in `port.toInt` for the integer.
- **Breaking:** every URL form sorts schemes by name: `socketUrl` and `bindUrl` as `sctp < tcp < udp < unix`, and `secureSocketUrl` as `dtls < quic < tls`.
- **Breaking:** every URL form's `schemes` is an attribute set from scheme name to `{ transport; secure; }`, with `url` adding `defaultPort`. `socketUrl.schemes`, `bindUrl.schemes` and `proxyUrl.schemes` were lists of names; use `builtins.attrNames`.
- **Breaking:** `transport.values` holds the tagged transports in sorted order, `[ sctp tcp udp ]`, instead of the name strings `[ "tcp" "udp" "sctp" ]`.
- **Breaking:** every decimal number in parsed text rejects leading zeros, as IPv4 octets already did: bounded integers, port ranges, bindpoint, endpoint and URL ports, and `cidr` and `interfaceAddress` prefix lengths. `port.parse "0080"`, `portRange.parse "0080-0090"` and `cidr.parse "10.0.0.0/08"` now throw, and the matching module types reject such strings, so `toString (parse s)` gives back `s` ([ADR 0013](docs/adr/0013-strict-input-canonical-output.md)).
- Format through treefmt-nix: `nix fmt` runs nixfmt, deadnix, actionlint, and prettier instead of only nixfmt, and `checks.<system>.treefmt` replaces `checks.<system>.formatting`.
- **Breaking:** `port`, `vlanId`, `mtu` and `icmpType` check the kind of every argument and throw `libnet.<ns>.<fn>: expected <kind>, got <kind>` on a mismatch, instead of returning a malformed value or failing with a raw Nix error. `fromInt` rejects a non-integer, so `port.fromInt "80"` no longer reports "out of range"; `add`, `sub`, `next` and `prev` reject a non-integer offset, so `port.add 1.5 p` no longer stores a float; and `toString`, `toInt`, the comparison functions, `diff` and the port class predicates reject anything but a value of their kind. Only `is`, `eq`, `isValid` and `tryParse` accept any value ([ADR 0007](docs/adr/0007-cross-type-comparison.md)). Build arguments with `parse` or `fromInt`, and test untrusted values with `is` first.
- **Breaking:** bounded-integer errors name the function the caller called: `port.prev`, `port.sub` and `port.next` report themselves instead of `port.add`, and out-of-range arithmetic reads `libnet.port.prev: out of range [0, 65535]: 0 - 1`. An offset that would overflow a Nix integer throws the same range error, checked before any arithmetic. A non-string `tryParse` input fails with `libnet.<ns>.parse: expected string, got <type>` ([ADR 0006](docs/adr/0006-parse-throws-tryparse-recovers.md)). Update anything that matches error text.
- **Breaking:** rename the bound constants `lowestValue` and `highestValue` of `port`, `vlanId`, `mtu` and `icmpType` to `minValue` and `maxValue`, the `min`/`max` vocabulary of `interfaceName.maxLength`.

### Removed

- **Breaking:** `cidr.address`, `cidr.canonical` and `cidr.isCanonical`; use `cidr.networkAddress`, which every CIDR now stores.
- **Breaking:** `interfaceAddress.toCidr`, which built a CIDR with host bits; use `interfaceAddress.cidr`.
- **Breaking:** the function aliases `ipv4.fromOctets` and `ipv4.toOctets` (use `fromBytes` and `toBytes`, whose errors now name `fromBytes`), `ipv6.toStringCompressed` (use `toString`), `port.isEphemeral` (use `isDynamic`) and `ipBindpoint.isAnyAddress` (use `isWildcard`). The library keeps one name per operation.
- **Breaking:** `host.isHostname` and `host.isDomain`, which tested leaf kinds below `host`'s direct members; use `hostname.is` and `domain.is`, or `dnsName.isHostname` and `dnsName.isDomain`.
- **Breaking:** `interfaceName.value`; use `interfaceName.toString`, as for every other scalar kind.
- **Breaking:** `domain.labelCount`; use `builtins.length (domain.labels d)`.
- **Breaking:** `cidr.containsAddress` and `cidr.containsCidr`; use `cidr.contains` and `cidr.isSupernetOf`.
- **Breaking:** `ipBindpoint.isRange`, since a single port is also a port range; use `portRange.isSingleton (ipBindpoint.portRange b)`.
- **Breaking:** the constants `urlHost.regNamePattern`, the parser's internal grammar, and `unixSocket.sunPathMax`, which gave one limit for two: a pathname socket allows 107 bytes and an abstract name 108.
- **Breaking:** `secureSocketUrl.aliases`; `ssl` remains an input spelling of `tls` that `parse` and `make` accept.
- **Breaking:** `port.wellKnownMax` and `port.registeredMax`; classify a port with `port.isWellKnown`, `port.isRegistered` and `port.isDynamic`.

### Fixed

- `tryParse` and `isValid` fail on a decimal number too long for a 64-bit integer, such as `port.tryParse "99999999999999999999"`, instead of throwing an integer overflow error. On Nix versions that wrap overflow silently, such text no longer parses as a small value.

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
