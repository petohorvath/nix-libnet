# Testing

All tests are [nix-unit](https://github.com/nix-community/nix-unit) unit suites.

`tests/unit/default.nix` is the entry point. It lists each suite by hand, so a suite file missing from the list does not run. Suite attribute names are the kebab-case file names, such as `bind-url`, rather than the camelCase names that the library and `testContext` use, so an attribute path reads as the file path. Each suite mirrors a `lib/` file at the same path, such as `tests/unit/internal/parse.nix` (attribute `unit.internal.parse`) for `lib/internal/parse.nix`. `tests/unit/cross-type-equality.nix`, `tests/unit/compare-agrees-with-eq.nix` and `tests/unit/wrong-kind.nix` test behavior across every kind, so they match no source file.

Every suite takes `testContext`, built by `tests/test-context.nix`, and destructures what it uses:

- `libnet`: the library, imported from source as `import ../.`.
- `internal`: the modules of `lib/internal/`, which `libnet` does not export.
- `lib`: `nixpkgs.lib`, or `null` without nixpkgs.
- `helpers`: assertion helpers from `tests/helpers/`. `helpers.throws expr` is `true` when forcing `expr` throws.

Suites return cases of the form `testName = { expr; expected; };` with camelCase names that start with `test`, or `testName = { expr; expectedError.msg; };` for an error. `tests/unit/types.nix` and `tests/unit/with-lib.nix` test the module types and `withLib`, which need `nixpkgs.lib`, so they return no cases when `lib` is `null`.

`dev/default.nix` runs the suites on [nix-unit's flake-parts module](https://github.com/nix-community/nix-unit/blob/main/lib/modules/flake/system.nix), which exposes them as the flake's `tests.systems.<system>` output. They appear there twice: `unit-core` passes `nixpkgs = null`, proving the core needs none, and `unit` passes the flake's `nixpkgs` input, which adds the module-type and `withLib` suites. The module adds the `nix-unit` check, which runs both in the build sandbox, with the flake's inputs passed as `--override-input`. treefmt-nix's module adds `treefmt`, which fails on files that `nix fmt` would change, and `dev/checks.nix` adds `lint`, which runs `statix check`.

```sh
nix develop --command nix-unit --flake .#tests.systems.x86_64-linux                                         # all suites
nix develop --command nix-unit --flake .#tests.systems.x86_64-linux.unit-core                               # core suites only
nix develop --command nix-unit --flake .#tests.systems.x86_64-linux.unit.internal.parse                     # one suite
nix develop --command nix-unit --flake .#tests.systems.x86_64-linux.unit.internal.parse --attr testDecimal0 # one test
nix build .#checks.x86_64-linux.nix-unit                                                                    # the check, in the build sandbox
```

nix-unit treats a selected attribute as a suite, so selecting a test by its full path does not work: select its suite and name the test with `--attr`.

Add `--override-input nixpkgs <flake-ref>` to run the suites against another nixpkgs.

## Error assertions

Assert a thrown error with nix-unit's `expectedError.msg`, a regular expression that nix-unit searches for in the message. Anchor it with `^` and spell out the prefix and the start of the detail, so a message that names the wrong function or carries a second prefix fails. Inside a Nix string, escape `.`, `[`, `]` and `+` with a doubled backslash, as in `\\.`. Anchor the end with `$` when the whole detail matters:

```nix
testPrevAtMinNamesPrev = {
  expr = port.prev (parse "0");
  expectedError.msg = "^libnet\\.port\\.prev: out of range \\[0, 65535\\]: 0 - 1$";
};
```

`tryParse` does not throw, so assert its `error` string with `expected`. Keep `helpers.throws` for cases where only the throw matters, such as `builtins.all` over a list of rejected inputs.

## The wrong-kind suite

`tests/unit/wrong-kind.nix` checks the argument-kind rule of [ADR 0007](adr/0007-cross-type-comparison.md) with one row per namespace in `cases`:

- `module` and `value`: the namespace and a valid value of its kind.
- `rejects.<function>.<argument>`: a call of `<function>` with one argument of the wrong kind, named for what it gets wrong, such as `add.floatOffset`. The suite asserts that each call throws `libnet.<ns>.<function>: expected …`, in a test named `test<Function><Argument>`.

Each row covers a representative function that takes a value of the kind, `make` where the namespace has one, and arithmetic offsets and indices where it has them. The suite also asserts that `is`, `eq`, `isValid` and `tryParse` accept every value in `anyValues` without throwing, and that a failed `tryParse` names `<ns>.parse`. A namespace adopting the rule adds its row; behavior beyond the representative calls belongs in its own suite.

## Coverage rules

- Every public function has a positive case.
- Every throwing branch has a case asserting its error, with `expectedError.msg` where the message matters.
- Every predicate has a positive and a negative case.
- Every parsed kind round-trips: `toString (parse s) == s` on canonical text.
- Every boundary is pinned: range ends, prefix lengths `/0`, `/31`, `/32`, `/127` and `/128`, arithmetic carry and overflow, and each enumeration size guard on both sides of its limit.
- Every cross-family and cross-kind rule from [ADR 0007](adr/0007-cross-type-comparison.md) has a case; `tests/unit/cross-type-equality.nix` covers `eq` across all kinds.
- `compare a b` is `0` exactly when `eq a b`; `tests/unit/compare-agrees-with-eq.nix` checks every pair of its samples, which must cover each namespace with a comparison suite and include spellings that `eq` ignores.
- Each kind exercises partial application at least once, such as `map (add 1) values`.
