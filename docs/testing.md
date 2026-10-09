# Testing

[nix-unit](https://github.com/nix-community/nix-unit) runs `tests/unit.nix`, which returns one suite per public namespace and an `internal` group for `lib/internal/`. Each suite file mirrors a `lib/` file, takes `{ harness }`, and returns cases of the form `testName = { expr; expected; };` with camelCase names that start with `test`. `harness.throws expr` is `true` when forcing `expr` throws.

`tests/types.nix` also takes `lib` and runs only when `tests/unit.nix` receives one.

`tests/default.nix` assembles the flake's checks. The `core` check runs the suites with `lib = null`, proving the core needs no nixpkgs; `full` passes `nixpkgs.lib` and adds the module-type suite. `formatting` fails on unformatted files.

```sh
nix develop --command nix-unit tests/unit.nix      # core suites
nix build .#checks.x86_64-linux.full               # core plus module types, with the pinned nixpkgs
```

## Coverage rules

- Every public function has a positive case.
- Every throwing branch has a case asserting `throws`.
- Every predicate has a positive and a negative case.
- Every parsed kind round-trips: `toString (parse s) == s` on canonical text.
- Every boundary is pinned: range ends, prefix lengths `/0`, `/31`, `/32`, `/127` and `/128`, arithmetic carry and overflow, and each enumeration size guard on both sides of its limit.
- Every cross-family and cross-kind rule from [ADR 0007](adr/0007-cross-type-comparison.md) has a case; `tests/cross-type-equality.nix` covers `eq` across all kinds.
- Each kind exercises partial application at least once, such as `map (add 1) values`.
