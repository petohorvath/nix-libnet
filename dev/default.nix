{ inputs, ... }:
{
  imports = [ inputs.nix-unit.modules.flake.default ];
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      formatter = pkgs.callPackage ./formatter.nix { };
      devShells.default = pkgs.callPackage ./shell.nix {
        inherit (config) formatter;
      };
      checks = import ./checks.nix {
        inherit (config) formatter;
        inherit pkgs;
      };
      nix-unit = {
        package = pkgs.nix-unit;
        inputs = removeAttrs inputs [ "self" ];
        tests = {
          unit = import ../tests/unit {
            inherit (inputs) nixpkgs;
            inherit system;
          };
          # The core needs no nixpkgs, so run the same suites without it;
          # the module-type suite then has no tests.
          unit-core = import ../tests/unit {
            nixpkgs = null;
            inherit system;
          };
        };
      };
    };
}
