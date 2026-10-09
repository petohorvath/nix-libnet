# AGENTS.md

## Repository structure

- `default.nix` defines the public `libnet` API.
- `lib/` contains implementations; `lib/internal/` is not public API.
- `tests/` mirrors the library modules; register new suites in `tests/unit.nix`; `tests/default.nix` assembles the flake checks.
- `docs/reference/` is the authoritative API and behavior contract; read the page for any namespace you change.
- `GLOSSARY.md` defines the domain vocabulary, and `docs/adr/` records design decisions with their rationale.
- `docs/testing.md` holds the test suite conventions and coverage rules.
- `README.md` documents the user-facing overview and examples.
- `flake.nix` assembles the public outputs with flake-parts; the `dev` partition in `dev/` defines formatting, development tooling, and CI checks.

## Contribution rules

- Keep the core library pure Nix builtins with zero `nixpkgs` dependency. `nixpkgs.lib` is allowed only through the opt-in `withLib`/module-type integration.
- Preserve pure evaluation: no evaluation-time network access, impure host inputs, or import-from-derivation unless explicitly designed, documented, and tested.
- Preserve the minimum supported Nix version, 2.18; do not use newer builtins without an explicit compatibility change.
- Treat public API changes as contract changes. Keep `default.nix`, `docs/reference/`, `README.md`, tests, and `CHANGELOG.md` consistent.
- Add focused tests for normal behavior, boundaries, invalid inputs, errors, and laziness where applicable.
- Preserve tagged-value shapes, established naming, error behavior, and cross-family/type semantics.
- Keep changes narrow; do not reformat, refactor, or update `flake.lock` unrelated to the task.

## Required checks

Run the checks for the contributor's supported host system. `nix flake check` builds `checks.<system>.core`, `full`, and `formatting`; run `nix fmt` to fix a failing `formatting` check:

```sh
nix fmt
nix flake check --print-build-logs
```

CI calls the [shared project policy](https://github.com/petohorvath/nixos-project-policy/blob/v0.5/POLICY.md) from [`.github/workflows/check.yml`](.github/workflows/check.yml). On `x86_64-linux` and `aarch64-linux`, the policy checks the inputs, public outputs, development shell, and formatter, and runs `nix flake check` with the locked nixpkgs and with the policy's stable and unstable pins. To run the same checks locally from a clean checkout:

```sh
nix run github:petohorvath/nixos-project-policy/v0.5 -- check .
nix run github:petohorvath/nixos-project-policy/v0.5 -- test . --nixpkgs locked
nix run github:petohorvath/nixos-project-policy/v0.5 -- test . --nixpkgs stable
nix run github:petohorvath/nixos-project-policy/v0.5 -- test . --nixpkgs unstable
```

## Agent skills

### Issue tracker

Issues live in GitHub Issues on `petohorvath/nix-libnet`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five triage roles use the default label names: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human` and `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
