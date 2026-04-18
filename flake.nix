{
  description = "libnet — pure-Nix IP, MAC, and network-address library (zero nixpkgs dependency in the core)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      lib = import ./.;

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          runEval =
            name: args:
            pkgs.runCommand name {
              passed = (import ./tests/default.nix args).passed;
            } "touch $out";
        in
        {
          core = runEval "libnet-core-tests" { lib = null; };
          full = runEval "libnet-full-tests" { lib = pkgs.lib; };
        }
      );
    };
}
