/*
  Comparison helpers. `suite` builds the comparison suite of a kind from
  one comparison, so that every function checks its operands and names
  itself in errors, as the error rules in `errors.nix` require:
  `hostname.lt` reports `hostname.lt`, not `hostname.compare`.
*/
let
  # Order two plain values, such as strings, as -1, 0 or 1.
  order =
    a: b:
    if a < b then
      -1
    else if a > b then
      1
    else
      0;

  /*
    `compareFor caller a b` checks the kinds of `a` and `b`, reporting
    `caller`, such as `hostname.lt`, and returns -1, 0 or 1. `namespace`
    is the public namespace, such as `hostname`.

    The public namespaces export the returned functions, so their headers
    describe public API.
  */
  suite =
    { namespace, compareFor }:
    let
      caller = function: "${namespace}.${function}";
    in
    {
      /*
        Order two values, for sorting.

        `a`, `b`: values of the kind.

        Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`.
      */
      compare = compareFor (caller "compare");

      /*
        Test whether `a` sorts strictly before `b`.

        `a`, `b`: values of the kind.

        Returns a Boolean.
      */
      lt = a: b: compareFor (caller "lt") a b == -1;

      /*
        Test whether `a` sorts before or equal to `b`.

        `a`, `b`: values of the kind.

        Returns a Boolean.
      */
      le = a: b: compareFor (caller "le") a b <= 0;

      /*
        Test whether `a` sorts strictly after `b`.

        `a`, `b`: values of the kind.

        Returns a Boolean.
      */
      gt = a: b: compareFor (caller "gt") a b == 1;

      /*
        Test whether `a` sorts after or equal to `b`.

        `a`, `b`: values of the kind.

        Returns a Boolean.
      */
      ge = a: b: compareFor (caller "ge") a b >= 0;

      /*
        Select the value that sorts first.

        `a`, `b`: values of the kind.

        Returns the smaller value, or `a` when they compare equal.
      */
      min = a: b: if compareFor (caller "min") a b <= 0 then a else b;

      /*
        Select the value that sorts last.

        `a`, `b`: values of the kind.

        Returns the larger value, or `a` when they compare equal.
      */
      max = a: b: if compareFor (caller "max") a b >= 0 then a else b;
    };
in
{
  inherit order suite;
}
