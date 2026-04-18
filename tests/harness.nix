let
  formatValue =
    v:
    let
      r = builtins.tryEval (builtins.toJSON v);
    in
    if r.success then r.value else builtins.toString v;

  formatFailure =
    f:
    "\n  ${f.name}:"
    + (
      if f.threw then
        "\n    <expression threw: ${f.throwMsg}>"
      else
        "\n    actual:   ${formatValue f.actual}"
    )
    + "\n    expected: ${formatValue f.expected}";

  formatFailures =
    fs:
    "libnet tests: ${toString (builtins.length fs)} failure(s):"
    + builtins.concatStringsSep "" (map formatFailure fs);

  runTests =
    tests:
    let
      runOne =
        name: t:
        let
          evaluated = builtins.tryEval t.expr;
          ok = evaluated.success && evaluated.value == t.expected;
        in
        if ok then
          null
        else
          {
            inherit name;
            expected = t.expected;
            actual = if evaluated.success then evaluated.value else null;
            threw = !evaluated.success;
            throwMsg = if evaluated.success then "" else "see eval trace";
          };
      results = builtins.mapAttrs runOne tests;
      failures = builtins.filter (v: v != null) (builtins.attrValues results);
    in
    if failures == [ ] then
      { passed = builtins.length (builtins.attrNames tests); }
    else
      builtins.throw (formatFailures failures);

  throws = expr: (builtins.tryEval expr).success == false;

  succeeds = expr: (builtins.tryEval expr).success == true;

  prefix =
    p: ts:
    builtins.listToAttrs (
      map (n: {
        name = "${p}.${n}";
        value = ts.${n};
      }) (builtins.attrNames ts)
    );
in
{
  inherit
    runTests
    throws
    succeeds
    prefix
    ;
}
