{
  description = "libnet — pure-Nix IP, MAC, and network-address library (zero nixpkgs dependency in the core)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
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
          testsPath = "${./.}/tests/default.nix";
          # nix-unit evaluates inside the build sandbox, so it needs a
          # writable eval store; `extraArgs` passes Nix function arguments.
          runUnitTests =
            name: extraArgs:
            pkgs.runCommand name { nativeBuildInputs = [ pkgs.nix-unit ]; } ''
              export HOME="$TMPDIR"
              nix-unit --quiet --eval-store "$HOME" ${extraArgs} ${testsPath}
              touch "$out"
            '';
        in
        {
          core = runUnitTests "libnet-core-tests" "";
          full = runUnitTests "libnet-full-tests" "--arg lib 'import ${nixpkgs}/lib'";
          # The policy runs `nix flake check` but not `nix fmt`, so the
          # formatting gate lives here as a check.
          formatting = pkgs.runCommand "libnet-formatting" { nativeBuildInputs = [ pkgs.nixfmt-tree ]; } ''
            cp -R ${./.} source
            chmod -R u+w source
            cd source
            treefmt --ci --tree-root .
            touch "$out"
          '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            /*
              Tools a contributor reaches for on this repo: nix to
              pin the flake CLI itself (so checks/builds run a known
              version rather than the ambient one), nix-unit to run
              the test suites directly, nixfmt-tree for formatting
              (matches `nix fmt`), and statix + deadnix for ad-hoc
              linting of anti-patterns and dead code.
            */
            packages = [
              pkgs.nix
              pkgs.nix-unit
              pkgs.nixfmt-tree
              pkgs.statix
              pkgs.deadnix
            ];
          };
        }
      );
    };
}
