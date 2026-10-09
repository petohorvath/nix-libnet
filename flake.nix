{
  description = "libnet — pure-Nix IP, MAC, and network-address library (zero nixpkgs dependency in the core)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [ flake-parts.flakeModules.partitions ];

      # The library needs no nixpkgs; only the development outputs load it.
      partitions.dev.module = ./dev;
      partitionedAttrs = {
        checks = "dev";
        devShells = "dev";
        formatter = "dev";
      };

      flake.lib = import ./.;
    };
}
