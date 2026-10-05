# Pure-Nix core with opt-in module types

nixpkgs ships no reusable `lib` functions for IP arithmetic ([NixOS/nixpkgs#36299](https://github.com/NixOS/nixpkgs/issues/36299)), and community libraries each cover only part of the space: duairc/lib-net, djacu/nix-ip (IPv4 only), oddlama/nixos-extra-modules (string-based), and the unmerged GSoC 2024 IPv6 PRs. libnet fills the gap as a standalone library whose core uses only Nix builtins, so tooling, CI scripts and flakes that avoid nixpkgs can use it.

NixOS module types need `nixpkgs.lib`, so they are reached only through `libnet.withLib lib`, which returns the core plus `types`. The flake's `core` check evaluates every core suite with `lib = null` to prove the core never reaches for nixpkgs; the `full` check adds the module-type suite against real `nixpkgs.lib`.
