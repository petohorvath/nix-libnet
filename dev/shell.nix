/*
  Tools a contributor reaches for on this repo: nix pins the flake CLI so
  checks and builds run a known version rather than the ambient one,
  nix-unit runs the test suites directly, git and nil support everyday
  editing, and statix lints for anti-patterns. `treefmtShell` adds treefmt
  and every program in `treefmt.nix`, so each formatter and linter that
  `nix fmt` runs also runs on single files.
*/
{
  git,
  mkShellNoCC,
  nil,
  nix,
  nix-unit,
  statix,
  treefmtShell,
}:
mkShellNoCC {
  inputsFrom = [ treefmtShell ];
  packages = [
    nix
    nix-unit
    git
    nil
    statix
  ];
}
