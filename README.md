# nix-libnet

nix-libnet provides `libnet`, a pure-Nix library that parses, validates, formats and computes on network values: IPv4, IPv6 and MAC addresses, CIDR blocks and ranges, ports, DNS names, connect and bind targets, and bounded URL forms. It serves Nix code that handles network configuration, such as NixOS modules, flakes and CI tooling, where nixpkgs offers no IP arithmetic. The core uses only Nix builtins, so it also works without nixpkgs; NixOS option types are opt-in.

## Overview

`parse` turns text into a value, an attribute set tagged with its kind, such as `{ _type = "ipv4"; value = 167772165; }`. `toString` returns the canonical text. The tag lets `is` check a value's kind and lets union namespaces such as `ip` and `endpoint` dispatch on it.

Namespaces share standard function suites: parsing (`parse`, `tryParse`, `toString`, `isValid`, `is`), comparison (`eq`, `lt`, `le`, `gt`, `ge`, `compare`, `min`, `max`), and, for scalar kinds such as addresses and ports, arithmetic (`add`, `sub`, `diff`, `next`, `prev`). Each [API reference](docs/reference/README.md) page lists the suites its namespaces provide. Functions take their parameter first and the value last, so `map (libnet.ipv4.add 1) addresses` works.

`parse` throws on invalid input, and `tryParse` returns `{ success; value; error; }` for input that may be invalid. Other failures, such as arithmetic overflow, throw a message that starts with `libnet` and names the function.

[GLOSSARY.md](GLOSSARY.md) defines the vocabulary, and [docs/adr/](docs/adr/) records the design decisions.

## Requirements

- Nix 2.18 or later.
- `nixpkgs.lib`, only for the NixOS option types.

The library evaluates on any system. The flake's checks and development shell cover `x86_64-linux` and `aarch64-linux`.

## Install

With flakes, add the repository as an input and take the library from its `lib` output:

```nix
{
  inputs.nix-libnet.url = "github:petohorvath/nix-libnet";

  outputs =
    { nix-libnet, ... }:
    let
      libnet = nix-libnet.lib;
    in
    {
      # Use libnet here.
    };
}
```

Without flakes, import the repository root:

```nix
libnet = import (builtins.fetchTarball "https://github.com/petohorvath/nix-libnet/archive/main.tar.gz");
```

## Usage

Compute the broadcast address of a CIDR block:

```sh
nix eval github:petohorvath/nix-libnet#lib --apply 'libnet: libnet.ipv4.toString (libnet.cidr.broadcast (libnet.cidr.parse "10.0.0.0/24"))'
```

```text
"10.0.0.255"
```

With `libnet` bound as in [Install](#install), this expression evaluates to the values in its comments:

```nix
let
  block = libnet.cidr.parse "10.0.0.0/24";
in
{
  # true
  inBlock = libnet.cidr.contains block (libnet.ipv4.parse "10.0.0.5");

  # "2001:db8::a8bb:ccff:fedd:eeff"
  slaac = libnet.ipv6.toString (
    libnet.ipv6.fromEui64 (libnet.cidr.parse "2001:db8::/64") (libnet.mac.parse "aa:bb:cc:dd:ee:ff")
  );

  # true
  isLocal = libnet.ipEndpoint.isLoopback (libnet.ipEndpoint.parse "[::1]:443");

  # true
  isWildcard = libnet.ipBindpoint.isAnyAddress (libnet.ipBindpoint.parse ":8080-8082");

  # [ "10.0.0.0/24" ]
  merged = map libnet.cidr.toString (
    libnet.cidr.summarize [
      (libnet.cidr.parse "10.0.0.0/25")
      (libnet.cidr.parse "10.0.0.128/25")
    ]
  );
}
```

The [API reference](docs/reference/README.md) documents every namespace and function.

## NixOS option types

`libnet.withLib lib` returns the library plus `types`, a set of NixOS option types that validate with the core `isValid`. String option values stay strings after merge, so code that needs structure calls `parse`. `types.port`, `types.vlanId`, `types.mtu` and `types.icmpType` merge to integers.

In a NixOS module that has `libnet` in scope:

```nix
{ lib, ... }:
let
  inherit (libnet.withLib lib) types;
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

[Module types](docs/reference/module-types.md) lists every type and its merge behavior.

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
| [Registry](docs/reference/registry.md) | `registry`: bogon blocks, service ports and ICMP types |
| [Module types](docs/reference/module-types.md) | `withLib`, `types` |

## Limitations

- libnet works on syntax and arithmetic only: it performs no DNS resolution and carries no GeoIP, WHOIS or Public Suffix List data ([ADR 0003](docs/adr/0003-syntax-not-resolution.md)).
- Internationalized domain names and IPv6 zone identifiers such as `fe80::1%eth0` are rejected.
- The URL forms accept fixed shapes over closed scheme sets, not general URLs, and store components without percent-decoding ([ADR 0011](docs/adr/0011-bounded-url-forms.md)).
- IPv6 sizes and differences of 2⁶³ or more throw, such as `cidr.size` on prefixes shorter than `/65` ([ADR 0005](docs/adr/0005-integer-representations.md)).

## Contributing

Report bugs and ask questions in [GitHub Issues](https://github.com/petohorvath/nix-libnet/issues). [AGENTS.md](AGENTS.md) lists the contribution rules and required checks, and [docs/testing.md](docs/testing.md) the test conventions. Format and check a change before submitting it:

```sh
nix fmt
nix flake check --print-build-logs
```

[CHANGELOG.md](CHANGELOG.md) records the changes.

## License

[MIT](LICENSE)
