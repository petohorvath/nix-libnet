/*
  libnet.withLib

  Opt-in entry point that injects `nixpkgs.lib` into the core library
  so NixOS option types under `libnet.types.*` become available.
  Without this call, libnet has no dependency on nixpkgs.

  Example:
    libnet.withLib pkgs.lib
    => libnet // { types = { ipv4 = <option-type>; ... }; }
*/
core: lib: core // (import ./types.nix { inherit lib; })
