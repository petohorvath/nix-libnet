# Changelog

All notable changes to libnet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-10-29

This release makes the API consistent and breaks it wherever consistency required. Every entry marked **Breaking** says how to migrate from 0.1.0.

### Added

- `domain.isSuperdomainOf`, the converse of `isSubdomainOf`, so either side of the relation can be partially applied.
- `vlanId.parse`, `mtu.parse` and `icmpType.parse`, with `tryParse`, over decimal text, so every bounded integer has the parsing suite that `port` has. `types.vlanId`, `types.mtu` and `types.icmpType` accept a decimal string as well as an integer and merge to an integer, like `types.port`.
- `regName`, the RFC 3986 registered name, as `{ _type = "regName"; value = String; }` with the parsing and comparison suites, and `types.regName`.
- `transport.compare`, `lt`, `le`, `gt`, `ge`, `min` and `max`, ordering transports by name (`sctp < tcp < udp`) for determinism only.
- `scheme`, `transport` and `isSecure` on every URL form: `socketUrl` and `bindUrl` gain `scheme` and `isSecure` (always `false`), and `proxyUrl` gains `transport` (always `tcp`).
- `proxyUrl.host`, `proxyUrl.port`, `proxyUrl.userinfo` and `proxyUrl.toEndpoint`, which `url` has too, and `url.authority`.
- A `tests` flake output with the nix-unit suites, as `tests.systems.<system>.unit` and `unit-core`, and the `nix-unit` flake input that runs them. The input's own inputs follow libnet's `nixpkgs` or are empty, so a consumer's lock file gains one `nix-unit` entry and no second nixpkgs. Consumers can drop it with `inputs.nix-libnet.inputs.nix-unit.follows = "";` ([ADR 0018](docs/adr/0018-nix-unit-flake-module.md)).
- The `treefmt-nix` flake input, which builds `nix fmt` and the `treefmt` check. Its `nixpkgs` follows libnet's, so a consumer's lock file gains one `treefmt-nix` entry and no second nixpkgs. Consumers can drop it with `inputs.nix-libnet.inputs.treefmt-nix.follows = "";` ([ADR 0019](docs/adr/0019-treefmt-nix.md)).
- A `lint` check that runs `statix check`.

### Changed

- **Breaking:** every function checks the kind of each argument, a tagged value's `_type` or a raw value's builtin type, and throws `libnet.<ns>.<fn>: expected <kind>, got <kind>` on a mismatch, `make` included, instead of returning a malformed value, a quiet `false` or a raw Nix error. Only `is`, the union `is<Member>` predicates such as `ip.isIpv4`, `eq`, `isValid` and `tryParse` accept any value, and they never throw ([ADR 0007](docs/adr/0007-cross-type-comparison.md)). Build arguments with `parse`, `make`, `fromInt` or `fromAddress`, and test untrusted values with `is` first. Notably:
  - `add`, `sub`, `next` and `prev` reject a non-integer offset, so `ipv4.add 1.5 a` and `port.add 1.5 p` no longer store a float. `cidr.addressAt`, `ipRange.addressAt`, `portRange.portAt` and `ipBindpoint.endpointAt` reject a non-integer index, and `cidr.subnets` and `cidr.supernet` a non-integer count.
  - `fromInt`, `fromBytes`, `fromWords`, `fromGroups` and `mac.fromOuiNic` reject a non-integer or a non-list, including a set, so `port.fromInt "80"` no longer reports "out of range".
  - `toString`, the comparison functions and the predicates reject a value of another kind, so `port.toString 80` and `transport.isTcp "tcp"` throw a libnet error.
  - `portRange.contains r 85` and `ipRange.contains r block` throw instead of returning `false`, and `cidr.contains` throws for anything but an address, a CIDR included; test a block with `cidr.isSupernetOf`. Relations still return `false` for an address or block of the other family.
  - `make`, `fromAddress`, `fromCidr`, `fromPort` and the other builders check their arguments when called, so `ipEndpoint.is (ipEndpoint.make a 80)` throws rather than returning `true` for a value whose `port` field throws when read.
  - `cidr.summarize` rejects a non-list or an element that is not a CIDR, and `domain.fromLabels` a non-string label.
- **Breaking:** `ipv4` and `ipv6` ordering, `compare`, `lt`, `le`, `gt`, `ge`, `min` and `max`, throws for an address of the other family instead of ordering IPv4 first. `ip`, `cidr`, `ipRange` and `interfaceAddress` still order IPv4 before IPv6, so sort mixed-family lists with `ip.lt` or `ip.compare`.
- **Breaking:** every error reads `libnet.<ns>.<fn>: <detail>` and names, once, the function the caller called ([ADR 0006](docs/adr/0006-parse-throws-tryparse-recovers.md)). Update anything that matches error text:
  - Shared code no longer names itself. `port.prev`, `port.sub` and `port.next` report themselves instead of `port.add`; `lt`, `min` and the other comparison functions instead of `compare`; `domain.isSuperdomainOf` instead of `isSubdomainOf`; `domain.fromLabels` instead of `domain.parse`; and `ipBindpoint.endpointsUnbounded` instead of `endpoints`. `ip.add`, `ip.next` and the other `ip` arithmetic report themselves rather than the family function.
  - A union or composite reports a member's failure under its own name with the member's detail, without a second prefix: `ip.parse "300.1.1.1"` reads `libnet.ip.parse: invalid octet in "300.1.1.1"`, `endpoint.parse "@"` reads `libnet.endpoint.parse: invalid socket "@" …`, `bindpoint.parse "x"` reads `libnet.bindpoint.parse: missing ':port' in "x"`, and `url.parse "http://"` reads `libnet.url.parse: invalid host ""`. A union that tries several members keeps the detail of the member whose shape the text has, so `endpoint.parse "1.2.3.4:99999"` reads `libnet.endpoint.parse: invalid port in "1.2.3.4:99999"`, `host.parse "010.0.0.1"` reads `libnet.host.parse: invalid octet in "010.0.0.1"` and `dnsName.parse "host_name"` reads `libnet.dnsName.parse: invalid hostname "host_name" …`, instead of a generic "is not a valid …". `dnsEndpoint.parse` no longer doubles its prefix. `socketUrl`, `bindUrl`, `secureSocketUrl` and `proxyUrl` keep the detail of an invalid endpoint, bindpoint or authority instead of a generic "invalid address", such as `libnet.bindUrl.parse: invalid port field "99999"`.
  - `socketUrl.parse` and `bindUrl.parse` report an unknown scheme before an invalid address, so `socketUrl.parse "foo://garbage"` reads `libnet.socketUrl.parse: unknown scheme "foo" …`.
  - A size limit reports the function that hit it, such as `libnet.cidr.hosts` or `libnet.ipRange.addresses`, instead of `cidr.size` or `ipv6.diff`.
  - Out-of-range arithmetic shows the operation, such as `libnet.ipv4.next: out of range: 255.255.255.255 + 1` and `libnet.port.prev: out of range [0, 65535]: 0 - 1`. An offset that would overflow a Nix integer throws the same error, checked before any arithmetic. Index, prefix and `make` errors give the offending value, such as `libnet.cidr.addressAt: index out of range [0, 16): 16`, and `url.make` reads `invalid path "noslash"` for a path without a leading `/`.
  - A non-string `parse` input fails with `libnet.<ns>.parse: expected string, got <type>`, and `tryParse` returns the same message as its `error`.
  - A module type's `mk` describes a wrong argument as every other function does, so `types.portRange.mk (portRange.parse "80-90")` reads `libnet.types.portRange.mk: expected string, got portRange value` instead of `got set`.
- **Breaking:** `hostname`, `domain`, `dnsName`, `host`, `regName` and `urlHost` fold case at parse, so `toString` prints canonical text: `hostname.parse "MyHost"` prints `myhost`, and `regName` also uppercases the hex digits of percent-encodings, so `My_Host%2f` prints `my_host%2F` (RFC 3986 §6.2.2.1). The hosts of `authority`, `url`, `proxyUrl`, `dnsEndpoint`, `endpoint`, `socketUrl` and `secureSocketUrl` print lowercase too. `eq` and `compare` on names compare the stored text, and `domain.isSubdomainOf` the stored labels ([ADR 0020](docs/adr/0020-case-folded-at-parse.md)). Userinfo, path, query, fragment, interface names, Unix socket paths and `transport` keep their case, and the module types still merge to the string as written ([ADR 0016](docs/adr/0016-module-types-keep-strings.md)). Compare parsed values with `eq` instead of comparing `toString` output against a mixed-case string.
- **Breaking:** text that a resolver reads as an IPv4 address is never a name ([ADR 0021](docs/adr/0021-no-numeric-dns-names.md)). `domain.parse`, `domain.fromLabels` and `regName.parse` reject a rightmost label that is all digits or `0x` followed by hex digits, so `192.0.2.1`, `127.1` and `127.1.0x1` are not domains, and `dnsName.parse` also rejects a numeric hostname such as `2130706433` or `0x7f`, which `hostname.parse` still accepts. `host.parse "010.0.0.1"`, `host.parse "127.1"`, `endpoint.parse "010.0.0.1:80"`, `url.parse "http://127.1/"` and `url.parse "http://0x7f.0.0.1/"` throw instead of returning a name, and `dnsEndpoint.make` throws for a hostname value such as `1234`. `types.domain`, `types.dnsName`, `types.host`, `types.dnsEndpoint`, `types.endpoint`, `types.urlHost` and `types.url` reject such strings too. Write the address in its canonical form, such as `127.0.0.1`, and parse it as an `ip`.
- **Breaking:** every decimal number in parsed text rejects leading zeros, as IPv4 octets already did: bounded integers, port ranges, bindpoint, endpoint and URL ports, and `cidr` and `interfaceAddress` prefix lengths. `port.parse "0080"`, `portRange.parse "0080-0090"` and `cidr.parse "10.0.0.0/08"` throw, and the matching module types reject such strings, so `toString (parse s)` gives back `s` ([ADR 0013](docs/adr/0013-strict-input-canonical-output.md)). Drop the leading zeros.
- **Breaking:** `interfaceName.parse` and `types.interfaceName` reject byte 160, which the kernel's `isspace` treats as space, so a name containing the UTF-8 sequence `C3 A0`, such as `wlà0`, is rejected as the kernel's `dev_valid_name` rejects it. Such a name never worked as an interface name.
- **Breaking:** `cidr.parse` and `cidr.make` reject host bits, so `10.0.0.5/24` is no longer a CIDR, and `types.cidr`, `types.ipv4Cidr` and `types.ipv6Cidr` reject it too. Parse such text with `interfaceAddress` and take its `cidr`. The stored field is `networkAddress`, not `address`, and `cidr.eq` no longer equates a block with host bits to its network ([ADR 0010](docs/adr/0010-interface-address-is-not-cidr.md)).
- **Breaking:** `cidr.broadcast` and `interfaceAddress.broadcast` throw for `/31` and `/32`, as `firstHost` and `lastHost` already treat them: both addresses of a `/31` are hosts (RFC 3021), so `cidr.broadcast (cidr.parse "10.0.0.0/31")` no longer returns the usable host `10.0.0.1`. `/30` and shorter blocks are unchanged. Use `cidr.topAddress` for the highest address of any block.
- **Breaking:** `cidr.exclude` takes the removed block first, as `cidr.exclude child parent`, so `concatMap (cidr.exclude reserved) pools` works, following the parameter-first convention. Swap the arguments: write `cidr.exclude child parent` for `cidr.exclude parent child`.
- **Breaking:** `make` takes a tagged value for every tagged field ([ADR 0004](docs/adr/0004-tagged-values.md)). `portRange.make` takes two `port` values instead of integers: write `portRange.make (port.fromInt 80) (port.fromInt 90)`. `authority.make` and `url.make` take `host` as a `urlHost` value and `port` as a `port` value or `null`: write `host = urlHost.parse "example.com"; port = port.fromInt 8443;`.
- **Breaking:** renamed functions, fields and constants. Arguments and results are unchanged unless noted, and the old names are gone:
  - `cidr.hostAt` is `cidr.addressAt`. It indexes every address from the network address, not the usable hosts that `cidr.hosts` lists, so it shares `ipRange.addressAt`'s name.
  - `cidr.subnet` is `cidr.subnets`, plural like `hosts` because it returns a list.
  - `cidr.numHosts` is `cidr.hostCount`, removing the library's only `num*` name.
  - `cidr.network` is `cidr.networkAddress`, which pairs with `topAddress`, and `interfaceAddress.network` is `interfaceAddress.cidr`, so "network" no longer names both an address and a block.
  - `interfaceAddress.fromAddressAndNetwork` is `interfaceAddress.fromCidrAndAddress` and takes the CIDR first, so `map (interfaceAddress.fromCidrAndAddress block) addresses` works.
  - `ipv6.fromIpv4Mapped` is `ipv6.fromIpv4`, `ipv6.toIpv4Mapped` is `ipv6.toIpv4` and `ipv6.fromEui64` is `ipv6.fromMac`, following the `from<Input>`/`to<Output>` pattern.
  - `dnsEndpoint.address` is `dnsEndpoint.name`, along with the stored field, because a DNS endpoint holds an unresolved name, not an address. `dnsEndpoint.make` is positional and does not change.
  - `host.isName` is `host.isDnsName`, so each union's predicates name its direct members.
  - `interfaceName.ifnamsiz` (`16`, the kernel buffer size) is `interfaceName.maxLength` (`15`, the longest valid name).
  - `lowestValue` and `highestValue` of `port`, `vlanId`, `mtu` and `icmpType` are `minValue` and `maxValue`, the `min`/`max` vocabulary of `interfaceName.maxLength`.
- **Breaking:** `mac.ouiToString` is `mac.toStringOui`, named like `toStringHyphen`, and takes a MAC instead of the integer OUI, like every other `toString*`: write `mac.toStringOui m` for `mac.ouiToString (mac.oui m)`.
- **Breaking:** `vlanId.isValid`, `mtu.isValid` and `icmpType.isValid` take decimal text, like every other `isValid`, so `vlanId.isValid 100` is `false`. Integer callers use `fromInt` or the module types.
- **Breaking:** `unixSocket` stores its path as `value`, as `{ _type = "unixSocket"; value = String; }`, like every other scalar kind. Read it with `unixSocket.toString` rather than the `path` field.
- **Breaking:** `urlHost` is a pass-through union over `ip` and `regName`: `urlHost.parse "[::1]"` returns an `ipv6` value and `urlHost.parse "my_host"` a `regName` value, instead of a `urlHost` value with `kind`, `ip` and `name` fields. Test the result with `urlHost.isIp` and `urlHost.isRegName` instead of reading `kind`, and use it directly instead of its `ip` and `name` fields. `authority.make` and `url.make` accept an `ipv4` or `ipv6` value as the host.
- **Breaking:** `url` stores its authority nested, as `{ _type = "url"; scheme; authority; path; query; fragment; }`, like `proxyUrl`. `url.make` takes `{ scheme; authority; path ? ""; query ? null; fragment ? null; }`: write `authority = authority.make { host = urlHost.parse "example.com"; port = port.fromInt 8443; };`. Read the host, port and userinfo with `url.host`, `url.port` and `url.userinfo` rather than fields.
- **Breaking:** `url` and `authority` validate their components against RFC 3986 and still store them verbatim ([ADR 0011](docs/adr/0011-bounded-url-forms.md)). Userinfo must match `unreserved / pct-encoded / sub-delims / ":"`, path segments `pchar`, and the query and fragment `pchar / "/" / "?"`, in ASCII with well-formed percent-encoding, so `parse` rejects a space, a newline, `<`, `%zz`, a non-ASCII byte or a second `#`. `types.url`, `types.authority` and `types.proxyUrl` reject such strings too. Percent-encode the offending characters, such as `%20` for a space.
- **Breaking:** `authority.make` and `url.make` run the same checks as `parse`, so `parse (toString (make x))` gives back `x`. They reject userinfo `a/b`, path `/a#b`, query `a#b`, a non-string scheme, userinfo, path, query or fragment, a non-set argument, and a missing or unexpected attribute. Percent-encode components as for `parse`.
- **Breaking:** `url.eq` counts userinfo, so `https://alice@h` no longer equals `https://bob@h`, and `url.compare` orders by userinfo after the effective port, `null` first. Compare `url.host` and `url.effectivePort` to ignore userinfo.
- **Breaking:** `url.eq` and `url.compare` read an empty path as `/` (RFC 3986 §6.2.3), so `http://h` equals `http://h/`. `url.toString` still prints the path as given; compare `url.path` to tell the two apart.
- **Breaking:** `url.defaultPort` returns a port value instead of an integer, so `port.eq (url.effectivePort u) (url.defaultPort u)` works directly. Wrap it in `port.toInt` for the integer.
- **Breaking:** `socketUrl` and `bindUrl` store their canonical scheme, as `{ _type = "socketUrl"; scheme; endpoint; }` and `{ _type = "bindUrl"; scheme; bindpoint; }`, instead of a transport that was `null` for `unix`, so every URL form stores its scheme. `socketUrl.make` and `bindUrl.make` take the scheme string first and match it case-insensitively, like `secureSocketUrl.make` and `proxyUrl.make`: write `socketUrl.make "tcp" e` for `socketUrl.make (transport.parse "tcp") e`, and `socketUrl.make "unix" s` for `socketUrl.make null s`. `make` still requires a Unix socket for `unix` and rejects one for every other scheme, and `transport` derives from the scheme, `null` only for `unix` ([ADR 0011](docs/adr/0011-bounded-url-forms.md)).
- **Breaking:** every URL form sorts schemes by name: `socketUrl` and `bindUrl` as `sctp < tcp < udp < unix`, and `secureSocketUrl` as `dtls < quic < tls`. The order is for determinism only, so sort explicitly where code relied on the old one.
- **Breaking:** every URL form's `schemes` is an attribute set from scheme name to `{ transport; secure; }`, with `url` adding `defaultPort`. `socketUrl.schemes`, `bindUrl.schemes` and `proxyUrl.schemes` were lists of names; use `builtins.attrNames`.
- **Breaking:** `transport.values` holds the tagged transports in sorted order, `[ sctp tcp udp ]`, instead of the name strings `[ "tcp" "udp" "sctp" ]`. Use `map transport.toString transport.values` for the names.
- `isSecure` on every URL form means the scheme's protocol encrypts the connection, which is why `ssh` and `sftp` are secure without TLS. The scheme tables and results are unchanged.
- **Breaking (development interface):** run the unit suites through nix-unit's flake-parts module. Replace `checks.<system>.core` and `checks.<system>.full` with `checks.<system>.nix-unit`, which runs them as `unit-core`, without nixpkgs, and `unit`. Replace `nix-unit tests/unit.nix` with `nix-unit --flake .#tests.systems.<system>.unit[.<suite>]`, adding `--attr <test>` for one test. The suites move from `tests/` to `tests/unit/`, whose entry point takes `nixpkgs` instead of `lib`, and their attributes take their file names, such as `bind-url` and `internal.dns-label`.
- Format through treefmt-nix: `nix fmt` runs nixfmt, deadnix, actionlint, and prettier instead of only nixfmt, and `checks.<system>.treefmt` replaces `checks.<system>.formatting`.

### Removed

- **Breaking:** the function aliases `ipv4.fromOctets` and `ipv4.toOctets` (use `fromBytes` and `toBytes`, whose errors name `fromBytes`), `ipv6.toStringCompressed` (use `toString`), `port.isEphemeral` (use `isDynamic`) and `ipBindpoint.isAnyAddress` (use `isWildcard`). The library keeps one name per operation.
- **Breaking:** `hostname.normalize`, `domain.normalize` and `dnsName.normalize`, since `parse` already lowercases; drop the call ([ADR 0020](docs/adr/0020-case-folded-at-parse.md)).
- **Breaking:** `cidr.address`, `cidr.canonical` and `cidr.isCanonical`; use `cidr.networkAddress`, which every CIDR now stores.
- **Breaking:** `cidr.containsAddress` and `cidr.containsCidr`; use `cidr.contains` and `cidr.isSupernetOf`.
- **Breaking:** `interfaceAddress.toCidr`, which built a CIDR with host bits; use `interfaceAddress.cidr`.
- **Breaking:** `interfaceAddress.toRange`; write `ipRange.fromCidr (interfaceAddress.cidr ia)`.
- **Breaking:** `port.wellKnownMax` and `port.registeredMax`; classify a port with `port.isWellKnown`, `port.isRegistered` and `port.isDynamic`.
- **Breaking:** `host.isHostname` and `host.isDomain`, which tested leaf kinds below `host`'s direct members; use `hostname.is` and `domain.is`, or `dnsName.isHostname` and `dnsName.isDomain`.
- **Breaking:** `domain.labelCount`; use `builtins.length (domain.labels d)`.
- **Breaking:** `interfaceName.value`; use `interfaceName.toString`, as for every other scalar kind.
- **Breaking:** `unixSocket.path`, which duplicated `toString`; use `unixSocket.toString`.
- **Breaking:** `ipBindpoint.isRange`, since a single port is also a port range; use `portRange.isSingleton (ipBindpoint.portRange b)`.
- **Breaking:** the constants `urlHost.regNamePattern`, the parser's internal grammar, and `unixSocket.sunPathMax`, which gave one limit for two: a pathname socket allows 107 bytes and an abstract name 108.
- **Breaking:** `secureSocketUrl.aliases`; `ssl` remains an input spelling of `tls` that `parse` and `make` accept.

### Fixed

- `eq` returns `false` for two values of another kind, as 0.1.0 promised, instead of `true` or a raw `attribute missing` error: `ipv4.eq p p` for a port `p` and `authority.eq { _type = 1; } { _type = 1; }` are `false`.
- `ipv6.diff` and `ip.diff` return −2⁶³ when the difference is exactly that, which fits in a Nix integer, instead of throwing.
- `ipRange.size`, `ipRange.addressAt` and `ipRange.addresses` on an IPv6 range of exactly 2⁶³ addresses, such as `::-::7fff:ffff:ffff:ffff`, throw `libnet.ipRange.<fn>: range too large for a Nix integer` instead of failing with a raw integer overflow, or returning a negative size on Nix versions that wrap overflow silently.
- `cidr.addressAt` and `ipRange.addressAt` index blocks and ranges of 2⁶³ addresses or more, so `cidr.addressAt 1 (cidr.parse "2001:db8::/64")` returns the gateway `2001:db8::1` instead of throwing "too large for a Nix integer". Every `Int` index lands inside such a block, and a negative one counts back from the top address ([ADR 0015](docs/adr/0015-enumeration-size-guards.md)). On such blocks, `cidr.hosts` and `ipRange.addresses` throw their 2¹⁶ guard, which points to `addressAt`, and `ipRange.addresses` suggests `addressAt` beside `addressesUnbounded`.
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

[Unreleased]: https://github.com/petohorvath/nix-libnet/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/petohorvath/nix-libnet/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/petohorvath/nix-libnet/releases/tag/v0.1.0
