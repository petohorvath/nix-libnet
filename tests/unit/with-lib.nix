# `withLib` needs `nixpkgs.lib`; without it the suite has no tests.
{ lib, libnet, ... }:
let
  extended = libnet.withLib lib;
  coreNames = builtins.attrNames (removeAttrs libnet [ "withLib" ]);
in
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
    testAddsOnlyTypes = {
      expr = builtins.filter (name: !(builtins.elem name coreNames)) (builtins.attrNames extended);
      expected = [ "types" ];
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
