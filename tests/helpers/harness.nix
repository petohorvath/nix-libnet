/*
  Helpers shared by the test suites. nix-unit runs the suites; these
  helpers only shape assertions.
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
}
