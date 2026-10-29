# Testing

All tests are [nix-unit](https://github.com/nix-community/nix-unit) unit suites.

`tests/unit/default.nix` is the entry point. It lists each suite by hand, so a suite file missing from the list does not run. Suite attribute names are the kebab-case file names, such as `bind-url`, rather than the camelCase names that the library and `testContext` use, so an attribute path reads as the file path. Each suite mirrors a `lib/` file at the same path, such as `tests/unit/internal/parse.nix` (attribute `unit.internal.parse`) for `lib/internal/parse.nix`. `tests/unit/cross-type-equality.nix` and `tests/unit/compare-agrees-with-eq.nix` test behavior across every kind, so they match no source file.

Every suite takes `testContext`, built by `tests/test-context.nix`, and destructures what it uses:

- `libnet`: the library, imported from source as `import ../.`.
- `internal`: the modules of `lib/internal/`, which `libnet` does not export.
- `lib`: `nixpkgs.lib`, or `null` without nixpkgs.
- `helpers`: assertion helpers from `tests/helpers/`. `helpers.throws expr` is `true` when forcing `expr` throws.

Suites return cases of the form `testName = { expr; expected; };` with camelCase names that start with `test`. `tests/unit/types.nix` and `tests/unit/with-lib.nix` test the module types and `withLib`, which need `nixpkgs.lib`, so they return no cases when `lib` is `null`.

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

## Coverage rules

- Every public function has a positive case.
- Every throwing branch has a case asserting `throws`.
- Every predicate has a positive and a negative case.
- Every parsed kind round-trips: `toString (parse s) == s` on canonical text.
- Every boundary is pinned: range ends, prefix lengths `/0`, `/31`, `/32`, `/127` and `/128`, arithmetic carry and overflow, and each enumeration size guard on both sides of its limit.
- Every cross-family and cross-kind rule from [ADR 0007](adr/0007-cross-type-comparison.md) has a case; `tests/unit/cross-type-equality.nix` covers `eq` across all kinds.
- `compare a b` is `0` exactly when `eq a b`; `tests/unit/compare-agrees-with-eq.nix` checks every pair of its samples, which must cover each namespace with a comparison suite and include spellings that `eq` ignores.
- Each kind exercises partial application at least once, such as `map (add 1) values`.
