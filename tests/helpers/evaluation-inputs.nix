# test-standard v1: copied from the test-standard skill; do not edit here.
/*
  Rebuild a flake input from store paths, so evaluation in the build
  sandbox fetches nothing. Takes `{ path; inputs; }`, where each input
  is a tree of the same shape or an already-built flake, or
  `{ path; flake = false; }` for a non-flake input.
*/
let
  rebuild =
    {
      path,
      inputs ? { },
      flake ? true,
    }:
    if !flake then
      { outPath = path; }
    else
      let
        rebuiltInputs = builtins.mapAttrs (
          _: input: if input ? outPath then input else rebuild input
        ) inputs;
        self = (import (path + "/flake.nix")).outputs (rebuiltInputs // { inherit self; }) // {
          outPath = path;
          inputs = rebuiltInputs;
        };
      in
      self;
in
rebuild
