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
        "\n    <threw during evaluation; real error surfaced below>"
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
          };
      results = builtins.mapAttrs runOne tests;
      failures = builtins.filter (v: v != null) (builtins.attrValues results);
      threwFailures = builtins.filter (f: f.threw) failures;
    in
    if failures == [ ] then
      { passed = builtins.length (builtins.attrNames tests); }
    else if threwFailures != [ ] then
      # builtins.tryEval cannot recover a throw's message, so re-evaluate
      # the first throwing test outside tryEval and let Nix surface the
      # real error — tagged via addErrorContext with the failure summary
      # (which names every failing test), so nothing is hidden.
      let
        first = builtins.head threwFailures;
      in
      builtins.addErrorContext (formatFailures failures) (
        builtins.deepSeq tests.${first.name}.expr (builtins.throw (formatFailures failures))
      )
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
