# Testing

All tests are [nix-unit](https://github.com/nix-community/nix-unit) unit suites.

`tests/unit/default.nix` is the entry point. It lists each suite by hand, so a suite file missing from the list does not run. Suite attribute names are the kebab-case file names, such as `bind-url`, rather than the camelCase names that the library and `testContext` use, so an attribute path reads as the file path. Each suite mirrors a `lib/` file at the same path, such as `tests/unit/internal/parse.nix` (attribute `internal.parse`) for `lib/internal/parse.nix`. `tests/unit/cross-type-equality.nix` tests behavior across every kind, so it matches no source file.

Every suite takes `testContext`, built by `tests/test-context.nix`, and destructures what it uses:

- `libnet`: the library, imported from source as `import ../.`.
- `internal`: the modules of `lib/internal/`, which `libnet` does not export.
- `lib`: `nixpkgs.lib`, or `null` without nixpkgs.
- `helpers`: assertion helpers from `tests/helpers/`. `helpers.throws expr` is `true` when forcing `expr` throws.

Suites return cases of the form `testName = { expr; expected; };` with camelCase names that start with `test`. `tests/unit/types.nix` tests the module types, which need `nixpkgs.lib`, so it returns no cases when `lib` is `null`.

`tests/default.nix` assembles the test entries of the flake's checks with the runner in `tests/runners/nix-unit.nix`. `unit-core` runs the suites without nixpkgs, proving the core needs none; `unit` passes the flake's `nixpkgs` input and adds the module-type suite. `dev/checks.nix` adds `formatting`, which fails on unformatted files. The runner and `tests/helpers/evaluation-inputs.nix` are shared copies; their header line names the canonical copy to change instead.

```sh
nix develop --command nix-unit tests/unit                       # all suites, with the locked nixpkgs
nix develop --command nix-unit --arg nixpkgs null tests/unit    # core suites only
nix develop --command nix-unit --attr internal.parse tests/unit # one suite
nix build .#checks.x86_64-linux.unit                            # one entry, in the build sandbox
```

## Coverage rules

- Every public function has a positive case.
- Every throwing branch has a case asserting `throws`.
- Every predicate has a positive and a negative case.
- Every parsed kind round-trips: `toString (parse s) == s` on canonical text.
- Every boundary is pinned: range ends, prefix lengths `/0`, `/31`, `/32`, `/127` and `/128`, arithmetic carry and overflow, and each enumeration size guard on both sides of its limit.
- Every cross-family and cross-kind rule from [ADR 0007](adr/0007-cross-type-comparison.md) has a case; `tests/unit/cross-type-equality.nix` covers `eq` across all kinds.
- Each kind exercises partial application at least once, such as `map (add 1) values`.
