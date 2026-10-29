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

  # Order by `rank` first, so that a union keeps a fixed order between
  # its members, such as IPv4 before IPv6, then by `compareSame` for two
  # values of the same rank.
  byRank =
    rank: compareSame: a: b:
    let
      rankOrder = order (rank a) (rank b);
    in
    if rankOrder != 0 then rankOrder else compareSame a b;

  # The first of the `orders` that is not 0, for ordering by several keys
  # in turn. A key is evaluated only when every earlier key ties.
  lexicographic = builtins.foldl' (result: next: if result != 0 then result else next) 0;

  # Order values that may be null, null first and the rest by
  # `compareValues`, for optional components such as a URL's query.
  optional =
    compareValues: a: b:
    if a == null && b == null then
      0
    else if a == null then
      -1
    else if b == null then
      1
    else
      compareValues a b;

  /*
    `compareFor function a b` checks the kinds of `a` and `b`, reporting
    the public function named `function`, such as `lt` for `hostname.lt`,
    and returns -1, 0 or 1.

    The public namespaces export the returned functions, so their headers
    describe public API.
  */
  suite = compareFor: {
    /*
      Order two values, for sorting.

      `a`, `b`: values of the kind.

      Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`.
    */
    compare = compareFor "compare";

    /*
      Test whether `a` sorts strictly before `b`.

      `a`, `b`: values of the kind.

      Returns a Boolean.
    */
    lt = a: b: compareFor "lt" a b == -1;

    /*
      Test whether `a` sorts before or equal to `b`.

      `a`, `b`: values of the kind.

      Returns a Boolean.
    */
    le = a: b: compareFor "le" a b <= 0;

    /*
      Test whether `a` sorts strictly after `b`.

      `a`, `b`: values of the kind.

      Returns a Boolean.
    */
    gt = a: b: compareFor "gt" a b == 1;

    /*
      Test whether `a` sorts after or equal to `b`.

      `a`, `b`: values of the kind.

      Returns a Boolean.
    */
    ge = a: b: compareFor "ge" a b >= 0;

    /*
      Select the value that sorts first.

      `a`, `b`: values of the kind.

      Returns the smaller value, or `a` when they compare equal.
    */
    min = a: b: if compareFor "min" a b <= 0 then a else b;

    /*
      Select the value that sorts last.

      `a`, `b`: values of the kind.

      Returns the larger value, or `a` when they compare equal.
    */
    max = a: b: if compareFor "max" a b >= 0 then a else b;
  };
in
{
  inherit
    byRank
    lexicographic
    optional
    order
    suite
    ;
}
