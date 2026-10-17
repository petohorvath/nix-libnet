# Build `testContext`, the single argument of every nix-unit suite. The
# library comes from source, as `flake.nix` imports it. Without nixpkgs,
# `lib` is null, so the suites prove that the core needs none.
{ nixpkgs }:
{
  lib = if nixpkgs == null then null else nixpkgs.lib;
  libnet = import ../.;
  # `lib/internal/` is not public API, so `libnet` does not export it.
  internal = {
    bits = import ../lib/internal/bits.nix;
    boundedInt = import ../lib/internal/bounded-int.nix;
    carry = import ../lib/internal/carry.nix;
    dnsLabel = import ../lib/internal/dns-label.nix;
    format = import ../lib/internal/format.nix;
    parse = import ../lib/internal/parse.nix;
    types = import ../lib/internal/types.nix;
  };
  helpers = import ./helpers/harness.nix;
}
