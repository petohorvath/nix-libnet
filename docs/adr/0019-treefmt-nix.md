# Format and lint through treefmt-nix

The repo formats and lints its files as the devnix-labs code quality standard requires: one [treefmt-nix](https://github.com/numtide/treefmt-nix) configuration in `dev/treefmt.nix` provides `nix fmt` and the `treefmt` check, which runs nixfmt, deadnix, actionlint, and prettier. statix runs in a separate `lint` check, because treefmt runs only `statix fix`, which leaves the lints it cannot fix unreported. The root gains a `treefmt-nix` input that serves only these development outputs, as the `nix-unit` input of [ADR 0018](0018-nix-unit-flake-module.md) serves only the tests.

## Consequences

- Flake consumers lock one more input, `treefmt-nix`. Its `nixpkgs` follows libnet's, so consumers gain no second nixpkgs. A consumer can drop the input with `inputs.nix-libnet.inputs.treefmt-nix.follows = "";`.
- `checks.<system>.formatting` becomes `checks.<system>.treefmt`, and `checks.<system>.lint` is new.
- The tools come from the nixpkgs in use, so the project policy's unstable run lints with newer tool versions, and a tool release can fail that run without a change in the repo.

## Considered options

- **Keep `nixfmt-tree`.** It needs no input or configuration but formats only Nix; adding prettier, deadnix, or actionlint needs treefmt anyway.
