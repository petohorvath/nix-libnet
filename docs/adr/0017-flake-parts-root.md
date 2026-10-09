# Assemble the flake with flake-parts

The flake is assembled with `flake-parts.lib.mkFlake`, following the layout the other devnix-labs projects use. The root declares `nixpkgs` and `flake-parts`, whose `nixpkgs-lib` input follows `nixpkgs`, and exports only `lib`. A `dev` partition in `dev/` supplies `checks`, `devShells` and `formatter` for the same four systems as before, reusing the root inputs.

The previous plain `outputs` function inlined the system loop, the check derivations and the development shell in `flake.nix`. With the partition, evaluating `lib` loads no development code, and each development output lives in its own file under `dev/`.

`tests/default.nix` assembles the checks, as in the shared layout, so the nix-unit entry point moves to `tests/unit.nix`. `dev/checks.nix` adds the `formatting` check, which needs the formatter from the partition.

## Consequences

- Flake consumers gain `flake-parts` in their lock graph. Because its library follows `nixpkgs`, they gain no second nixpkgs input.
- The core is unchanged: `import ./.` still needs only builtins ([ADR 0001](0001-pure-nix-core.md)), and non-flake users never evaluate flake-parts.
- flake-parts publishes empty `apps`, `legacyPackages` and `packages` namespaces, which the project policy reports as notices without failing.

## Considered options

- **Keep a plain flake.** This avoids the extra input but keeps development wiring in `flake.nix` and diverges from the shared layout.
- **Give the `dev` partition its own inputs flake.** This adds a second lock without removing a root input; the partition needs only `nixpkgs` and `flake-parts`, which the root already declares.
