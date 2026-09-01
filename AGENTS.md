# AGENTS.md

## Repository structure

- `default.nix` defines the public `libnet` API.
- `lib/` contains implementations; `lib/internal/` is not public API.
- `tests/` mirrors the library modules; register new suites in `tests/default.nix`.
- `SPEC.md` is the authoritative API and behavior contract.
- `README.md` documents the user-facing API and examples.
- `flake.nix` defines formatting, development tooling, and CI checks.

## Contribution rules

- Keep the core library pure Nix builtins with zero `nixpkgs` dependency. `nixpkgs.lib` is allowed only through the opt-in `withLib`/module-type integration.
- Preserve pure evaluation: no evaluation-time network access, impure host inputs, or import-from-derivation unless explicitly designed, documented, and tested.
- Preserve the minimum supported Nix version, 2.18; do not use newer builtins without an explicit compatibility change.
- Treat public API changes as contract changes. Keep `default.nix`, `SPEC.md`, `README.md`, tests, and `CHANGELOG.md` consistent.
- Add focused tests for normal behavior, boundaries, invalid inputs, errors, and laziness where applicable.
- Preserve tagged-value shapes, established naming, error behavior, and cross-family/type semantics.
- Keep changes narrow; do not reformat, refactor, or update `flake.lock` unrelated to the task.

## Required checks

Run formatting and the checks for the contributor's supported host system. Set `SYSTEM` to the matching `checks.<system>` value, such as `x86_64-linux`:

```sh
SYSTEM=x86_64-linux
nix fmt
git diff --exit-code
nix build --print-build-logs ".#checks.${SYSTEM}.core"
nix build --print-build-logs ".#checks.${SYSTEM}.full"
```

CI runs the `core` and `full` commands for both `x86_64-linux` and `aarch64-linux`. It also runs the full suite against both supported nixpkgs channels:

```sh
nix build --print-build-logs --override-input nixpkgs github:NixOS/nixpkgs/nixos-25.11 .#checks.x86_64-linux.full
nix build --print-build-logs --override-input nixpkgs github:NixOS/nixpkgs/nixos-unstable .#checks.x86_64-linux.full
```
