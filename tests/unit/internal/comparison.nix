{ internal, ... }:
let
  inherit (internal) comparison errors;

  # A kind of plain integers named `number`, checked like a raw argument.
  number = comparison.suite {
    namespace = "number";
    compareFor =
      caller: a: b:
      comparison.order (errors.expectType caller "int" a) (errors.expectType caller "int" b);
  };
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
