# `withLib` needs `nixpkgs.lib`; without it the suite has no tests.
{ lib, libnet, ... }:
let
  extended = libnet.withLib lib;
  coreNames = builtins.attrNames (removeAttrs libnet [ "withLib" ]);

  # A `lib` whose option types carry a marker, so a test can tell which
  # `lib` built them.
  markedLib = lib // {
    types = lib.types // {
      mkOptionType = attrs: lib.types.mkOptionType attrs // { libMarker = true; };
    };
  };
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
