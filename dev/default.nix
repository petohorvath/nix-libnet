{ inputs, self, ... }:
{
  imports = [
    inputs.nix-unit.modules.flake.default
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    { config, pkgs, ... }:
    {
      treefmt.imports = [ ./treefmt.nix ];
      devShells.default = pkgs.callPackage ./shell.nix {
        treefmtShell = config.treefmt.build.devShell;
      };
      checks = import ./checks.nix { inherit pkgs; };
      nix-unit = {
        package = pkgs.nix-unit;
        inputs = removeAttrs inputs [ "self" ];
        enableSystemAgnostic = false;
        tests = {
          unit = import ../tests/unit {
            inherit (inputs) nixpkgs;
            flakeLib = self.lib;
          };
          # The core needs no nixpkgs, so run the same suites without it;
          # the module-type, `withLib` and flake `lib` suites then have no
          # tests. The flake's `lib` carries nixpkgs, so it stays out too.
          unit-core = import ../tests/unit {
            nixpkgs = null;
            flakeLib = null;
          };
        };
      };
    };
}
