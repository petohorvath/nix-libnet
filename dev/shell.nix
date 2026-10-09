/*
  Tools a contributor reaches for on this repo: nix pins the flake CLI so
  checks and builds run a known version rather than the ambient one,
  nix-unit runs the test suites directly, the formatter matches `nix fmt`,
  statix and deadnix lint for anti-patterns and dead code, and actionlint
  checks the CI workflow.
*/
{
  actionlint,
  deadnix,
  formatter,
  git,
  mkShellNoCC,
  nil,
  nix,
  nix-unit,
  nixfmt,
  statix,
}:
mkShellNoCC {
  packages = [
    nix
    nix-unit
    git
    nil
    nixfmt
    statix
    deadnix
    actionlint
    formatter
  ];
}
