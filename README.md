# libnet

Pure-Nix library for network values: IPv4, IPv6 and MAC addresses, CIDR blocks and ranges, ports, DNS names, connect and bind targets, and bounded URL forms. Every value is parsed, validated and tagged, with RFC-conformant formatting, arithmetic, predicates and set algebra. The core has no nixpkgs dependency; NixOS option types are opt-in.

## Quick start

```nix
let
  libnet = import ./nix-libnet;

  block = libnet.cidr.parse "10.0.0.0/24";
  inBlock = libnet.cidr.contains block (libnet.ipv4.parse "10.0.0.5"); # true
  broadcast = libnet.ipv4.toString (libnet.cidr.broadcast block); # "10.0.0.255"

  slaac = libnet.ipv6.fromEui64 (libnet.cidr.parse "2001:db8::/64") (
    libnet.mac.parse "aa:bb:cc:dd:ee:ff"
  ); # 2001:db8::a8bb:ccff:fedd:eeff

  endpoint = libnet.ipEndpoint.parse "[::1]:443";
  isLocal = libnet.ipEndpoint.isLoopback endpoint; # true

  listen = libnet.ipBindpoint.parse ":8080-8082";
  isWildcard = libnet.ipBindpoint.isAnyAddress listen; # true

  merged = libnet.cidr.summarize [
    (libnet.cidr.parse "10.0.0.0/25")
    (libnet.cidr.parse "10.0.0.128/25")
  ]; # [ 10.0.0.0/24 ]
in
broadcast
```

## NixOS module types

`libnet.withLib lib` adds `types`, NixOS option types that validate with the core parsers. Option values stay strings after merge, as in other NixOS options; call `parse` when structure is needed. Ports and the bounded integers (`vlanId`, `mtu`, `icmpType`) merge to integers.

```nix
{ lib, ... }:
let
  libnet = (import ./nix-libnet).withLib lib;
  inherit (libnet) types;
in
{
  options.services.example = {
    bind = lib.mkOption {
      type = types.ipv4;
      default = "0.0.0.0";
    };
    allowed = lib.mkOption {
      type = types.ipv4Cidr;
      default = "10.0.0.0/8";
    };
    listen = lib.mkOption {
      type = types.bindpoint;
      default = ":8080";
    };
  };
}
```

## Namespaces

| Area | Namespaces |
| --- | --- |
| [Addresses](docs/reference/addresses.md) | `ipv4`, `ipv6`, `ip` (either family), `mac` |
| [Networks](docs/reference/networks.md) | `cidr`, `ipRange`, `interfaceAddress` |
| [Ports and transports](docs/reference/ports.md) | `port`, `portRange`, `transport` |
| [Names](docs/reference/names.md) | `hostname`, `domain`, `dnsName`, `host`, `interfaceName` |
| [Targets](docs/reference/targets.md) | `ipEndpoint`, `dnsEndpoint`, `unixSocket`, `endpoint`, `ipBindpoint`, `bindpoint` |
| [URL forms](docs/reference/urls.md) | `socketUrl`, `bindUrl`, `secureSocketUrl`, `urlHost`, `authority`, `url`, `proxyUrl` |
| [Bounded integers](docs/reference/bounded-integers.md) | `vlanId`, `mtu`, `icmpType` |
| [Registry](docs/reference/registry.md) | Bogon blocks, service ports, ICMP types |
| [Module types](docs/reference/module-types.md) | `withLib`, `types` |

## Design

- **Tagged values**: every value is an attribute set with a `_type`, so unions dispatch safely and `is` checks kinds.
- **Uniform API**: namespaces share `parse`, `tryParse`, `toString`, `isValid`, `is`, the comparison suite `eq` through `max`, and, where meaningful, `add`, `sub`, `diff`, `next` and `prev`.
- **Curry-friendly**: the parameter comes first, so `map (libnet.ipv4.add 1) addresses` works.
- **Two parse surfaces**: `parse` throws; `tryParse` returns `{ success; value; error; }` for user-supplied input.

[`CONTEXT.md`](CONTEXT.md) defines the vocabulary, [`docs/adr/`](docs/adr/) records the design decisions, and [`docs/roadmap.md`](docs/roadmap.md) lists candidate features.

## Tests

```sh
nix flake check                                # every check on every system
nix build .#checks.x86_64-linux.core           # core suites, evaluated without nixpkgs
nix build .#checks.x86_64-linux.full           # core plus module-type suites
nix build .#checks.x86_64-linux.formatting     # fails on unformatted files; fix with nix fmt
nix develop --command nix-unit tests/default.nix
```

Each check runs nix-unit in the build sandbox, and a failing case fails the build with its expected and actual values. `core` proves the library needs no nixpkgs; `full` proves the `withLib` integration. See [`docs/testing.md`](docs/testing.md).

## Requirements

Nix 2.18 or later.

## License

MIT; see [LICENSE](LICENSE).
