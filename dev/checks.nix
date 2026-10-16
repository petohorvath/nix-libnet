/*
  Assemble the named checks: the test checks from `tests/default.nix`, and
  `formatting`, which fails on unformatted files. The policy runs
  `nix flake check` but not `nix fmt`, so the formatting gate lives here as
  a check.
*/
{ formatter, pkgs }:
pkgs.lib.attrsets.unionOfDisjoint (import ../tests { inherit pkgs; }) {
  formatting =
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
      '';
}
