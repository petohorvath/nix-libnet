{
  perSystem =
    { config, pkgs, ... }:
    {
      formatter = pkgs.callPackage ./formatter.nix { };
      devShells.default = pkgs.callPackage ./shell.nix {
        inherit (config) formatter;
      };
      checks = import ./checks.nix {
        inherit (config) formatter;
        inherit pkgs;
      };
    };
}
