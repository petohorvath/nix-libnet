# Assemble the test entries. `unit-core` runs the unit suites without
# nixpkgs, proving the core needs none; `unit` passes nixpkgs, which adds
# the module-type suite.
{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  repo = "libnet";
  srcDir = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../default.nix
      ../lib
      ./helpers
      ./test-context.nix
      ./unit
    ];
  };
  runNixUnit = import ./runners/nix-unit.nix {
    inherit
      inputs
      pkgs
      repo
      srcDir
      ;
  };
in
lib.foldl' lib.attrsets.unionOfDisjoint { } [
  {
    unit = runNixUnit { kind = "unit"; };
    unit-core = runNixUnit {
      kind = "unit";
      name = "unit-core";
      extraArgs.nixpkgs = "null";
    };
  }
]
