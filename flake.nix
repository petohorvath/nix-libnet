{
  description = "libnet — pure-Nix IP, MAC, and network-address library (zero nixpkgs dependency in the core)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    /*
      Build-time only: drives the pre-commit / pre-push git hooks
      the devShell installs. Not a runtime dependency of the
      library — consumers of `lib` never pull this in.
    */
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, git-hooks, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      /*
        Pre-commit + pre-push git hooks managed by git-hooks.nix.
        The devShell's shellHook installs them into `.git/hooks/`
        on every `nix develop` / direnv reload; `--no-verify`
        stays the per-invocation escape hatch.

        - pre-commit: `treefmt` driven by `nixfmt-tree` — the same
          binary `nix fmt` runs, so the hook can never disagree
          with CI's `git diff --exit-code` formatting gate.
        - pre-push: builds the `core` + `full` check tiers, the
          same contracts CI's test job enforces.

        statix / deadnix ship in the devShell for ad-hoc linting
        but are deliberately not hooks: the tree carries existing
        findings (some intentional, e.g. the uniform `{ harness }:`
        test signature) that would otherwise block every commit.

        The `pre-commit` stage hook is also exposed under
        `checks.<system>.pre-commit` so `nix flake check` verifies
        it passes. `flake-check-fast` is `pre-push`-only, so it
        does not recurse into `nix build .#checks…` from there.
      */
      gitHooksBySystem = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fastCheckTargets = nixpkgs.lib.concatStringsSep " " [
            ".#checks.${system}.core"
            ".#checks.${system}.full"
          ];
        in
        git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            treefmt = {
              enable = true;
              package = pkgs.nixfmt-tree;
            };

            flake-check-fast = {
              enable = true;
              name = "nix flake check (core + full)";
              entry = "nix build --no-link --print-build-logs ${fastCheckTargets}";
              pass_filenames = false;
              stages = [ "pre-push" ];
            };
          };
        }
      );
    in
    {
      lib = import ./.;

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          runEval =
            name: args:
            pkgs.runCommand name {
              passed = (import ./tests/default.nix args).passed;
            } "touch $out";
        in
        {
          core = runEval "libnet-core-tests" { lib = null; };
          full = runEval "libnet-full-tests" { lib = pkgs.lib; };
          pre-commit = gitHooksBySystem.${system};
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            /*
              Tools a contributor reaches for on this repo: nix to
              pin the flake CLI itself (so checks/builds run a known
              version rather than the ambient one), nixfmt-tree for
              formatting (matches `nix fmt`), and statix + deadnix
              for ad-hoc linting of anti-patterns and dead code.
            */
            packages = [
              pkgs.nix
              pkgs.nixfmt-tree
              pkgs.statix
              pkgs.deadnix
            ];

            # Install/refresh `.git/hooks` on every shell entry.
            shellHook = gitHooksBySystem.${system}.shellHook;
          };
        }
      );
    };
}
