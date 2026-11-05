/*
  Helpers shared by the test suites. nix-unit runs the suites; these
  helpers shape assertions and their fixtures.
*/
{
  /*
    Report whether evaluating a value fails, so suites can assert on
    rejected input with an ordinary `expected = true` comparison.

    `expr`: the value to force.

    Returns true when `builtins.tryEval` catches a `throw` or failed
    `assert` while forcing `expr` to weak head normal form.
  */
  throws = expr: !(builtins.tryEval expr).success;

  /*
    Mark the option types that a `lib` builds, so a suite can tell which
    `lib` built a module type.

    `lib`: the nixpkgs library to wrap.

    Returns `lib` whose `types.mkOptionType` adds `libMarker = true` to
    every option type it makes.
  */
  markLib =
    lib:
    lib
    // {
      types = lib.types // {
        mkOptionType = attrs: lib.types.mkOptionType attrs // { libMarker = true; };
      };
    };
}
