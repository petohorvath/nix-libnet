{ internal, ... }:
let
  inherit (internal) comparison errors;

  # A kind of plain integers named `number`, checked like a raw argument.
  number = comparison.suite (
    function: a: b:
    let
      caller = "number.${function}";
    in
    comparison.order (errors.expectType caller "int" a) (errors.expectType caller "int" b)
  );
in
{
  # ===== order =====
  testOrder = {
    expr = [
      (comparison.order "a" "b")
      (comparison.order "b" "b")
      (comparison.order "b" "a")
    ];
    expected = [
      (-1)
      0
      1
    ];
  };

  # ===== byRank =====
  # Strings rank before integers; values of one rank compare by `order`.
  testByRank =
    let
      compare = comparison.byRank (value: if builtins.isString value then 0 else 1) comparison.order;
    in
    {
      expr = [
        (compare "z" 1)
        (compare 1 "a")
        (compare 1 2)
        (compare "b" "a")
        (compare 2 2)
      ];
      expected = [
        (-1)
        1
        (-1)
        1
        0
      ];
    };

  # ===== lexicographic =====
  testLexicographic = {
    expr = [
      (comparison.lexicographic [ ])
      (comparison.lexicographic [
        0
        0
        1
      ])
      (comparison.lexicographic [
        0
        (-1)
        1
      ])
    ];
    expected = [
      0
      1
      (-1)
    ];
  };
  # A later key is not evaluated once an earlier one differs.
  testLexicographicIsLazy = {
    expr = comparison.lexicographic [
      1
      (throw "evaluated")
    ];
    expected = 1;
  };

  # ===== optional =====
  # Null sorts before any value; two values compare by the given order.
  testOptional = {
    expr = [
      (comparison.optional comparison.order null null)
      (comparison.optional comparison.order null "a")
      (comparison.optional comparison.order "a" null)
      (comparison.optional comparison.order "a" "b")
      (comparison.optional comparison.order "b" "b")
    ];
    expected = [
      0
      (-1)
      1
      (-1)
      0
    ];
  };
  # The given order sees only non-null values.
  testOptionalSkipsOrderForNull = {
    expr = comparison.optional (_: _: throw "compared") null 1;
    expected = -1;
  };

  # ===== suite =====
  testSuiteRelations = {
    expr = [
      (number.compare 1 2)
      (number.lt 1 2)
      (number.le 2 2)
      (number.gt 1 2)
      (number.ge 2 2)
      (number.min 2 1)
      (number.max 2 1)
    ];
    expected = [
      (-1)
      true
      true
      false
      true
      1
      2
    ];
  };
  testSuitePartiallyApplied = {
    expr = builtins.filter (number.lt 2) [
      1
      2
      3
    ];
    expected = [ 3 ];
  };
  # Each function names itself, not `compare`.
  testSuiteLtNamesItself = {
    expr = number.lt 1 "2";
    expectedError.msg = "^libnet\\.number\\.lt: expected int, got string$";
  };
  testSuiteMaxNamesItself = {
    expr = number.max null 1;
    expectedError.msg = "^libnet\\.number\\.max: expected int, got null$";
  };
}
