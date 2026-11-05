# The flake's `lib` output carries the module types, so it needs
# `nixpkgs.lib`; without it `flakeLib` is null and the suite has no tests.
{
  flakeLib,
  lib,
  libnet,
  ...
}:
let
  coreNames = builtins.attrNames (removeAttrs libnet [ "withLib" ]);

  # A `lib` whose option types carry a marker, so a test can tell which
  # `lib` built them.
  markedLib = lib // {
    types = lib.types // {
      mkOptionType = attrs: lib.types.mkOptionType attrs // { libMarker = true; };
    };
  };
in
if flakeLib == null then
  { }
else
  {
    # Functions are not comparable, so `==` holds only for the very same
    # values: a namespace rebuilt for the flake output fails it.
    testKeepsCoreValuesUnchanged = {
      expr = builtins.filter (name: flakeLib.${name} != libnet.${name}) coreNames;
      expected = [ ];
    };
    testAddsOnlyTypesAndWithLib = {
      expr = builtins.filter (name: !(builtins.elem name coreNames)) (builtins.attrNames flakeLib);
      expected = [
        "types"
        "withLib"
      ];
    };
    testTypesAreOptionTypes = {
      expr = builtins.all lib.isOptionType (builtins.attrValues flakeLib.types);
      expected = true;
    };
    testTypesMatchWithLib = {
      expr = builtins.attrNames flakeLib.types;
      expected = builtins.attrNames (libnet.withLib lib).types;
    };
    testTypesCoverIpv4 = {
      expr = flakeLib.types.ipv4.check "192.0.2.1";
      expected = true;
    };
    testWithLibBuildsCallerTypes = {
      expr = (flakeLib.withLib markedLib).types.ipv4 ? libMarker;
      expected = true;
    };
    testWithLibKeepsCoreValuesUnchanged = {
      expr =
        let
          rebuilt = flakeLib.withLib markedLib;
        in
        builtins.filter (name: rebuilt.${name} != libnet.${name}) coreNames;
      expected = [ ];
    };
  }
