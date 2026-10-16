# Run the tests on nix-unit's flake-parts module

The unit suites run on nix-unit's flake-parts module, as the devnix-labs test standard requires, instead of a runner kept in this repo. The module lives only in nix-unit's flake, so the root gains a `nix-unit` input that serves only the tests, and the `dev` partition exports a `tests` output beside `checks`, `devShells` and `formatter`. This changes [ADR 0017](0017-flake-parts-root.md), whose root declared only `nixpkgs` and `flake-parts` and exported only `lib`, and whose `dev` partition needed no input of its own.

## Consequences

- Flake consumers lock one more input, `nix-unit`. Its `nixpkgs` follows libnet's, and its `treefmt-nix` and `nix-github-actions` inputs are empty, so consumers gain no second nixpkgs. A consumer can drop the input with `inputs.nix-libnet.inputs.nix-unit.follows = "";`.
- A test that locks a consumer of libnet inside the build sandbox must also override `nix-libnet/nix-unit`.
- `tests` becomes a public output under the project policy.
- The `nix-unit` check copies each overridden input, nixpkgs included, into a store inside its build directory, and it depends on the whole flake source, so any edit reruns it.

## Considered options

- **Keep a runner in the repo.** It needs no extra input, but it is custom test-running code that every devnix-labs repo would have to copy and keep in sync.
- **Give the `dev` partition its own inputs flake for `nix-unit`.** Consumers would lock nothing extra, but the repo would keep a second lock file, which ADR 0017 already rejected, and it would differ from the other devnix-labs repos.
