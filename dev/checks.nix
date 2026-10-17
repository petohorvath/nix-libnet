# treefmt-nix's module adds the `treefmt` entry and nix-unit's the
# `nix-unit` entry. `lint` runs statix here because treefmt runs only
# `statix fix`, which leaves the lints it cannot fix unreported.
{ pkgs }:
{
  lint = pkgs.runCommand "libnet-lint" { nativeBuildInputs = [ pkgs.statix ]; } ''
    cd ${../.}
    statix check .
    touch "$out"
  '';
}
