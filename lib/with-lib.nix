/*
  libnet.withLib

  Opt-in entry point that adds NixOS option types under `libnet.types.*`.
  The caller supplies `nixpkgs.lib`, so the core library keeps no
  dependency on nixpkgs.

  `core`: the core libnet attrset; `default.nix` binds it.
  `lib`: the nixpkgs library, such as `pkgs.lib`.

  Returns `core` extended with a `types` attrset of option types and with
  `withLib` itself, so the result can rebuild its types against another
  `lib`.

  Example:
    libnet.withLib pkgs.lib
    => libnet // { types = { ipv4 = <option-type>; ... }; withLib = <fn>; }
*/
core:
let
  withLib = lib: core // (import ./types.nix { inherit lib; }) // { inherit withLib; };
in
withLib
