# nix-libnet

nix-libnet provides `libnet`, a pure-Nix library that parses, validates, formats and computes on network values: IPv4, IPv6 and MAC addresses, CIDR blocks and ranges, ports, DNS names, connect and bind targets, and bounded URL forms. It serves Nix code that handles network configuration, such as NixOS modules, flakes and CI tooling, where nixpkgs offers no IP arithmetic. The core uses only Nix builtins, so it also works without nixpkgs; NixOS option types are opt-in.

## Overview

`parse` turns text into a value, an attribute set tagged with its kind, such as `{ _type = "ipv4"; value = 167772165; }`. `toString` returns the canonical text. The tag lets `is` check a value's kind and lets pass-through unions such as `ip` and `endpoint` dispatch on it.

Namespaces share standard suites for parsing, comparison and, where a kind supports it, arithmetic; the [API reference](docs/reference/README.md) documents each namespace and the suites it provides. Functions take their parameter first and the operand last, so `map (libnet.ipv4.add 1) addresses` works.

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

To pin a version, replace `main` with a commit hash and pass `fetchTarball` the archive's `sha256`.

## Usage

With the `nix-command` and `flakes` experimental features enabled, compute the broadcast address of a CIDR block:

```sh
nix eval github:petohorvath/nix-libnet#lib --apply 'libnet: libnet.ipv4.toString (libnet.cidr.broadcast (libnet.cidr.parse "10.0.0.0/24"))'
```

```text
"10.0.0.255"
```

The [API reference](docs/reference/README.md) documents every namespace and function.

## NixOS option types

`libnet.withLib lib` returns the library plus `types`, a set of NixOS option types that validate with the core parsers. String option values stay strings after merge, so code that needs structure calls `parse`. `types.port`, `types.vlanId`, `types.mtu` and `types.icmpType` merge to integers.

In a NixOS module that receives `libnet` as an argument, for example through `specialArgs`:

```nix
{ lib, libnet, ... }:
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

## Limitations

- libnet works on syntax and arithmetic only: it performs no DNS resolution and carries no GeoIP, WHOIS or Public Suffix List data ([ADR 0003](docs/adr/0003-syntax-not-resolution.md)).
- Internationalized domain names and IPv6 zone identifiers such as `fe80::1%eth0` are rejected.
- The URL forms accept fixed shapes over closed scheme sets, not general URLs, and store components without percent-decoding ([ADR 0011](docs/adr/0011-bounded-url-forms.md)).
- IPv6 sizes and differences of 2⁶³ or more throw, such as `cidr.size` on `/65` and shorter prefixes ([ADR 0005](docs/adr/0005-integer-representations.md)).

## Contributing

Report bugs and ask questions in [GitHub Issues](https://github.com/petohorvath/nix-libnet/issues). [AGENTS.md](AGENTS.md) lists the contribution rules and required checks, and [docs/testing.md](docs/testing.md) the test conventions.

## License

[MIT](LICENSE)
