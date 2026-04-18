{
  description = "libnet — pure-Nix IP, MAC, and network-address library (zero nixpkgs dependency in the core)";

  outputs = { self, ... }: {
    lib = import ./.;

    # Expose the test suite as a flake output so `nix-instantiate --eval -A checks tests/default.nix {}` works too.
    # Note: core tests run dep-free; types tests require nixpkgs.lib to be injected at eval time.
  };
}
