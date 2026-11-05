# `withLib` needs `nixpkgs.lib`; without it only the laziness tests run.
{
  helpers,
  lib,
  libnet,
  ...
}:
let
  extended = libnet.withLib lib;
  coreNames = builtins.attrNames (removeAttrs libnet [ "withLib" ]);
  markedLib = helpers.markLib lib;

  # The flake's `lib` output is a `withLib` result, so reading the core
  # through one must not force `lib`.
  unforcedLib = libnet.withLib (throw "libnet test: lib forced");
in
{
  testCoreNeedsNoLib = {
    expr = unforcedLib.ipv4 == libnet.ipv4;
    expected = true;
  };
  testAttributeNamesNeedNoLib = {
    expr = builtins.attrNames unforcedLib;
    expected = builtins.sort builtins.lessThan (builtins.attrNames libnet ++ [ "types" ]);
  };
}
// (
  if lib == null then
    { }
  else
    {
      testKeepsEveryCoreAttribute = {
        expr = builtins.filter (name: !(extended ? ${name})) coreNames;
        expected = [ ];
      };
      # Functions are not comparable, so `==` holds only for the very same
      # values: any rebuilt or wrapped namespace fails it.
      testKeepsCoreValuesUnchanged = {
        expr = builtins.filter (name: extended.${name} != libnet.${name}) coreNames;
        expected = [ ];
      };
      testAddsOnlyTypesAndWithLib = {
        expr = builtins.filter (name: !(builtins.elem name coreNames)) (builtins.attrNames extended);
        expected = [
          "types"
          "withLib"
        ];
      };
      testBuildsTypesFromCallerLib = {
        expr = (libnet.withLib markedLib).types.ipv4 ? libMarker;
        expected = true;
      };
      testWithLibAgainRebuildsTypes = {
        expr = ((libnet.withLib markedLib).withLib lib).types.ipv4 ? libMarker;
        expected = false;
      };
      testWithLibAgainKeepsAttributes = {
        expr = builtins.attrNames ((libnet.withLib markedLib).withLib lib);
        expected = builtins.attrNames extended;
      };
      testTypesAreOptionTypes = {
        expr = builtins.all lib.isOptionType (builtins.attrValues extended.types);
        expected = true;
      };
      testTypesCoverIpv4 = {
        expr = extended.types.ipv4.check "192.0.2.1";
        expected = true;
      };
      testCoreHasNoTypes = {
        expr = libnet ? types;
        expected = false;
      };
    }
)
