/*
  Assemble the named checks. Each runs the nix-unit suites from `unit.nix`
  in the build sandbox: `core` without nixpkgs, proving the core needs none,
  and `full` with the nixpkgs library of `pkgs`, adding the module-type
  suite.
*/
{ pkgs }:
let
  unitTestsPath = "${../.}/tests/unit.nix";
  # nix-unit evaluates inside the build sandbox, so it needs a writable
  # eval store; `extraArgs` passes Nix function arguments.
  runUnitTests =
    name: extraArgs:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.nix-unit ]; } ''
      export HOME="$TMPDIR"
      nix-unit --quiet --eval-store "$HOME" ${extraArgs} ${unitTestsPath}
      touch "$out"
    '';
in
{
  core = runUnitTests "libnet-core-tests" "";
  full = runUnitTests "libnet-full-tests" "--arg lib 'import ${pkgs.path}/lib'";
}
