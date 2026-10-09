# The policy runs `nix flake check` but not `nix fmt`, so the formatting
# gate lives here as a check.
{ formatter, pkgs }:
pkgs.runCommand "libnet-formatting"
  {
    src = ../.;
    nativeBuildInputs = [ formatter ];
  }
  ''
    cp -R --no-preserve=mode "$src" source
    cd source
    treefmt --ci --tree-root .
    touch "$out"
  ''
