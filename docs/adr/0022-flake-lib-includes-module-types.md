# The flake's `lib` output includes the module types

The flake's `lib` output is `(import ./.).withLib inputs.nixpkgs.lib`: the core plus `types` built against the flake's `nixpkgs` input, so a flake consumer reads `nix-libnet.lib.types.ipv4` instead of calling `withLib` in every module that declares a libnet-typed option. This adds no dependency, because evaluating the flake's `lib` already loads `nixpkgs.lib` through flake-parts ([ADR 0017](0017-flake-parts-root.md)). The core stays builtins-only: `import ./.` still returns it without `types` ([ADR 0001](0001-pure-nix-core.md)).

`withLib lib` returns the core, `types` built against `lib`, and `withLib` itself, so any result, the flake's `lib` included, rebuilds its types against another `lib`.

## Consequences

- A consumer that sets `inputs.nix-libnet.inputs.nixpkgs.follows = "nixpkgs"` gets types built against its own `lib`. Without `follows`, the types come from libnet's locked nixpkgs, and a consumer whose modules evaluate against another `lib` calls `nix-libnet.lib.withLib lib`.
- Consumers that import the source, or evaluate modules against more than one nixpkgs, keep using `withLib`.
- The flake's `lib` has a `types` attribute that `import ./.` lacks, so the two are no longer the same set.

## Considered options

- **Export the prebuilt set under a second name**, such as `libWithTypes`. It leaves `lib` unchanged, but consumers must learn a second name for the same library.
- **Keep `lib` as the core only.** Every flake consumer repeats `withLib lib` in each module that declares a libnet-typed option.
- **Replace `withLib` with a function that returns only the types.** It fits `inherit (libnet.withLib lib) types;`, but renames an API that 0.2.0 settled and leaves consumers to combine the two sets.
