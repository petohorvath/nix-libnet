{ harness }:
let
  cidr = import ../lib/cidr.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  inherit (harness) throws;
  inherit (cidr) parse;
  formatIpv4 = ipv4.toString;
  formatIpv6 = ipv6.toString;
in
{
  # ===== Parse: positive =====
  testParseV4Prefix24 = {
    expr = cidr.toString (parse "10.0.0.0/24");
    expected = "10.0.0.0/24";
  };
  testParseV4Prefix0 = {
    expr = cidr.toString (parse "0.0.0.0/0");
    expected = "0.0.0.0/0";
  };
  testParseV4Prefix32 = {
    expr = cidr.toString (parse "1.2.3.4/32");
    expected = "1.2.3.4/32";
  };
  testParseV6Prefix64 = {
    expr = cidr.toString (parse "2001:db8::/64");
    expected = "2001:db8::/64";
  };
  testParseV6Prefix128 = {
    expr = cidr.toString (parse "::1/128");
    expected = "::1/128";
  };
  testParseV6Prefix0 = {
    expr = cidr.toString (parse "::/0");
    expected = "::/0";
  };
  testParseNonCanonical = {
    expr = cidr.toString (parse "10.0.0.5/24");
    expected = "10.0.0.5/24";
  }; # stores as-is

  # ===== Parse: negative =====
  testRejectNoSlash = {
    expr = throws (parse "10.0.0.0");
    expected = true;
  };
  testRejectV4Prefix33 = {
    expr = throws (parse "10.0.0.0/33");
    expected = true;
  };
  testRejectV6Prefix129 = {
    expr = throws (parse "::/129");
    expected = true;
  };
  testRejectNegativePrefix = {
    expr = throws (parse "10.0.0.0/-1");
    expected = true;
  };
  testRejectTextPrefix = {
    expr = throws (parse "10.0.0.0/a");
    expected = true;
  };
  testRejectBadAddress = {
    expr = throws (parse "999.0.0.0/24");
    expected = true;
  };

  # ===== tryParse =====
  testTryParseOk = {
    expr = (cidr.tryParse "10.0.0.0/24").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (cidr.tryParse "bad").success;
    expected = false;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = cidr.is (parse "10.0.0.0/24");
    expected = true;
  };
  testIsString = {
    expr = cidr.is "10.0.0.0/24";
    expected = false;
  };
  testIsIpv4V4 = {
    expr = cidr.isIpv4 (parse "10.0.0.0/24");
    expected = true;
  };
  testIsIpv4V6 = {
    expr = cidr.isIpv4 (parse "::/64");
    expected = false;
  };
  testIsIpv6V6 = {
    expr = cidr.isIpv6 (parse "::/64");
    expected = true;
  };
  testIsValidOk = {
    expr = cidr.isValid "10.0.0.0/24";
    expected = true;
  };
  testIsValidBad = {
    expr = cidr.isValid "bad";
    expected = false;
  };

  # ===== Accessors =====
  testPrefixV4 = {
    expr = cidr.prefix (parse "10.0.0.0/24");
    expected = 24;
  };
  testVersionV4 = {
    expr = cidr.version (parse "10.0.0.0/24");
    expected = 4;
  };
  testVersionV6 = {
    expr = cidr.version (parse "::/64");
    expected = 6;
  };

  # ===== Derived values: v4 /24 =====
  testNetworkV4Prefix24 = {
    expr = formatIpv4 (cidr.network (parse "10.0.0.5/24"));
    expected = "10.0.0.0";
  };
  testBroadcastV4Prefix24 = {
    expr = formatIpv4 (cidr.broadcast (parse "10.0.0.0/24"));
    expected = "10.0.0.255";
  };
  testNetmaskV4Prefix24 = {
    expr = formatIpv4 (cidr.netmask (parse "10.0.0.0/24"));
    expected = "255.255.255.0";
  };
  testHostmaskV4Prefix24 = {
    expr = formatIpv4 (cidr.hostmask (parse "10.0.0.0/24"));
    expected = "0.0.0.255";
  };
  testFirstHostV4Prefix24 = {
    expr = formatIpv4 (cidr.firstHost (parse "10.0.0.0/24"));
    expected = "10.0.0.1";
  };
  testLastHostV4Prefix24 = {
    expr = formatIpv4 (cidr.lastHost (parse "10.0.0.0/24"));
    expected = "10.0.0.254";
  };
  testSizeV4Prefix24 = {
    expr = cidr.size (parse "10.0.0.0/24");
    expected = 256;
  };
  testNumHostsV4Prefix24 = {
    expr = cidr.numHosts (parse "10.0.0.0/24");
    expected = 254;
  };

  # ===== Derived values: v4 /30 =====
  testFirstHostV4Prefix30 = {
    expr = formatIpv4 (cidr.firstHost (parse "10.0.0.0/30"));
    expected = "10.0.0.1";
  };
  testLastHostV4Prefix30 = {
    expr = formatIpv4 (cidr.lastHost (parse "10.0.0.0/30"));
    expected = "10.0.0.2";
  };
  testSizeV4Prefix30 = {
    expr = cidr.size (parse "10.0.0.0/30");
    expected = 4;
  };
  testNumHostsV4Prefix30 = {
    expr = cidr.numHosts (parse "10.0.0.0/30");
    expected = 2;
  };

  # ===== Derived values: v4 /31 (point-to-point) =====
  testFirstHostV4Prefix31 = {
    expr = formatIpv4 (cidr.firstHost (parse "10.0.0.0/31"));
    expected = "10.0.0.0";
  };
  testLastHostV4Prefix31 = {
    expr = formatIpv4 (cidr.lastHost (parse "10.0.0.0/31"));
    expected = "10.0.0.1";
  };
  testSizeV4Prefix31 = {
    expr = cidr.size (parse "10.0.0.0/31");
    expected = 2;
  };
  testNumHostsV4Prefix31 = {
    expr = cidr.numHosts (parse "10.0.0.0/31");
    expected = 2;
  };

  # ===== Derived values: v4 /32 =====
  testFirstHostV4Prefix32 = {
    expr = formatIpv4 (cidr.firstHost (parse "1.2.3.4/32"));
    expected = "1.2.3.4";
  };
  testLastHostV4Prefix32 = {
    expr = formatIpv4 (cidr.lastHost (parse "1.2.3.4/32"));
    expected = "1.2.3.4";
  };
  testSizeV4Prefix32 = {
    expr = cidr.size (parse "1.2.3.4/32");
    expected = 1;
  };
  testNumHostsV4Prefix32 = {
    expr = cidr.numHosts (parse "1.2.3.4/32");
    expected = 1;
  };

  # ===== Derived values: v4 /0 =====
  testSizeV4Prefix0 = {
    expr = cidr.size (parse "0.0.0.0/0");
    expected = 4294967296;
  };

  # ===== Derived values: v6 /64 =====
  testNetworkV6Prefix64 = {
    expr = formatIpv6 (cidr.network (parse "2001:db8::1/64"));
    expected = "2001:db8::";
  };
  testNetmaskV6Prefix64 = {
    expr = formatIpv6 (cidr.netmask (parse "2001:db8::/64"));
    expected = "ffff:ffff:ffff:ffff::";
  };
  testFirstHostV6Prefix64 = {
    expr = formatIpv6 (cidr.firstHost (parse "2001:db8::/64"));
    expected = "2001:db8::1";
  };
  testBroadcastV6Throws = {
    expr = throws (cidr.broadcast (parse "2001:db8::/64"));
    expected = true;
  };

  # ===== v6 /127 (point-to-point) =====
  testFirstHostV6Prefix127 = {
    expr = formatIpv6 (cidr.firstHost (parse "2001:db8::/127"));
    expected = "2001:db8::";
  };
  testLastHostV6Prefix127 = {
    expr = formatIpv6 (cidr.lastHost (parse "2001:db8::/127"));
    expected = "2001:db8::1";
  };
  testSizeV6Prefix127 = {
    expr = cidr.size (parse "2001:db8::/127");
    expected = 2;
  };

  # ===== v6 /128 =====
  testFirstHostV6Prefix128 = {
    expr = formatIpv6 (cidr.firstHost (parse "::1/128"));
    expected = "::1";
  };
  testSizeV6Prefix128 = {
    expr = cidr.size (parse "::1/128");
    expected = 1;
  };

  # ===== v6 /0 and /65 overflow =====
  testSizeV6Prefix65Throws = {
    expr = throws (cidr.size (parse "::/65"));
    expected = true;
  };
  testSizeV6Prefix0Throws = {
    expr = throws (cidr.size (parse "::/0"));
    expected = true;
  };
  testSizeV6Prefix66 = {
    expr = cidr.size (parse "::/66");
    expected = 4611686018427387904;
  };
  testNumHostsV6Prefix120 = {
    expr = cidr.numHosts (parse "2001:db8::/120");
    expected = 255;
  };
  testNumHostsV6Prefix64Throws = {
    expr = throws (cidr.numHosts (parse "2001:db8::/64"));
    expected = true;
  };
  testNumHostsV6Prefix126 = {
    expr = cidr.numHosts (parse "2001:db8::/126");
    expected = 3;
  };
  testNumHostsV6Prefix127 = {
    expr = cidr.numHosts (parse "2001:db8::/127");
    expected = 2;
  };
  testNumHostsV6Prefix128 = {
    expr = cidr.numHosts (parse "::1/128");
    expected = 1;
  };
  testLastHostV6Prefix120 = {
    expr = formatIpv6 (cidr.lastHost (parse "2001:db8::/120"));
    expected = "2001:db8::ff";
  };

  # ===== Enumeration =====
  testHostAt0 = {
    expr = formatIpv4 (cidr.hostAt 0 (parse "10.0.0.0/28"));
    expected = "10.0.0.0";
  };
  testHostAt5 = {
    expr = formatIpv4 (cidr.hostAt 5 (parse "10.0.0.0/28"));
    expected = "10.0.0.5";
  };
  testHostAtLast = {
    expr = formatIpv4 (cidr.hostAt 15 (parse "10.0.0.0/28"));
    expected = "10.0.0.15";
  };
  testHostAtNegative1 = {
    expr = formatIpv4 (cidr.hostAt (-1) (parse "10.0.0.0/28"));
    expected = "10.0.0.15";
  };
  testHostAtNegative2 = {
    expr = formatIpv4 (cidr.hostAt (-2) (parse "10.0.0.0/28"));
    expected = "10.0.0.14";
  };
  testHostAtOutOfRangePositive = {
    expr = throws (cidr.hostAt 16 (parse "10.0.0.0/28"));
    expected = true;
  };
  testHostAtOutOfRangeNegative = {
    expr = throws (cidr.hostAt (-17) (parse "10.0.0.0/28"));
    expected = true;
  };

  testHostsPrefix24 = {
    expr = builtins.length (cidr.hosts (parse "10.0.0.0/24"));
    expected = 254;
  };
  testHostsPrefix30 = {
    expr = map formatIpv4 (cidr.hosts (parse "10.0.0.0/30"));
    expected = [
      "10.0.0.1"
      "10.0.0.2"
    ];
  };
  testHostsV6Prefix126 = {
    expr = map formatIpv6 (cidr.hosts (parse "2001:db8::/126"));
    expected = [
      "2001:db8::1"
      "2001:db8::2"
      "2001:db8::3"
    ];
  };
  testHostsUnboundedV6Prefix126 = {
    expr = map formatIpv6 (cidr.hostsUnbounded (parse "2001:db8::/126"));
    expected = [
      "2001:db8::1"
      "2001:db8::2"
      "2001:db8::3"
    ];
  };
  testHostsV6Prefix127 = {
    expr = map formatIpv6 (cidr.hosts (parse "2001:db8::/127"));
    expected = [
      "2001:db8::"
      "2001:db8::1"
    ];
  };
  testHostsTooLargeThrows = {
    expr = throws (cidr.hosts (parse "10.0.0.0/15"));
    expected = true;
  };
  testHostsUnbounded = {
    expr = builtins.length (cidr.hostsUnbounded (parse "10.0.0.0/24"));
    expected = 254;
  };

  # ===== Containment =====
  testContainsAddressInside = {
    expr = cidr.contains (parse "10.0.0.0/24") (ipv4.parse "10.0.0.5");
    expected = true;
  };
  testContainsNetworkAddress = {
    expr = cidr.contains (parse "10.0.0.0/24") (ipv4.parse "10.0.0.0");
    expected = true;
  };
  testContainsBroadcastAddress = {
    expr = cidr.contains (parse "10.0.0.0/24") (ipv4.parse "10.0.0.255");
    expected = true;
  };
  testContainsAddressOutside = {
    expr = cidr.contains (parse "10.0.0.0/24") (ipv4.parse "10.0.1.0");
    expected = false;
  };
  testContainsAddressBelow = {
    expr = cidr.contains (parse "10.0.0.0/24") (ipv4.parse "9.255.255.255");
    expected = false;
  };
  testContainsSubnetInside = {
    expr = cidr.contains (parse "10.0.0.0/8") (parse "10.1.0.0/16");
    expected = true;
  };
  testContainsSubnetEqual = {
    expr = cidr.contains (parse "10.0.0.0/24") (parse "10.0.0.0/24");
    expected = true;
  };
  testContainsSubnetOutside = {
    expr = cidr.contains (parse "10.0.0.0/24") (parse "10.1.0.0/24");
    expected = false;
  };
  testContainsCrossFamily = {
    expr = cidr.contains (parse "10.0.0.0/24") (ipv6.parse "::1");
    expected = false;
  };
  testContainsV6 = {
    expr = cidr.contains (parse "2001:db8::/32") (ipv6.parse "2001:db8::1");
    expected = true;
  };

  testIsSubnetOfTrue = {
    expr = cidr.isSubnetOf (parse "10.0.0.0/24") (parse "10.0.0.0/8");
    expected = true;
  };
  testIsSubnetOfSelf = {
    expr = cidr.isSubnetOf (parse "10.0.0.0/24") (parse "10.0.0.0/24");
    expected = true;
  };
  testIsSubnetOfFalse = {
    expr = cidr.isSubnetOf (parse "10.0.0.0/8") (parse "10.0.0.0/24");
    expected = false;
  };
  testIsSubnetOfDisjoint = {
    expr = cidr.isSubnetOf (parse "10.0.0.0/24") (parse "11.0.0.0/24");
    expected = false;
  };
  testIsSubnetOfCrossFamily = {
    expr = cidr.isSubnetOf (parse "10.0.0.0/24") (parse "::/0");
    expected = false;
  };
  testIsSupernetOfTrue = {
    expr = cidr.isSupernetOf (parse "10.0.0.0/8") (parse "10.0.0.0/24");
    expected = true;
  };
  testOverlapsTrue = {
    expr = cidr.overlaps (parse "10.0.0.0/24") (parse "10.0.0.0/8");
    expected = true;
  };
  testOverlapsFalse = {
    expr = cidr.overlaps (parse "10.0.0.0/24") (parse "11.0.0.0/24");
    expected = false;
  };
  testOverlapsEqual = {
    expr = cidr.overlaps (parse "10.0.0.0/24") (parse "10.0.0.0/24");
    expected = true;
  };
  testOverlapsAdjacent = {
    expr = cidr.overlaps (parse "10.0.0.0/25") (parse "10.0.0.128/25");
    expected = false;
  };
  testOverlapsCrossFamily = {
    expr = cidr.overlaps (parse "10.0.0.0/24") (parse "::/0");
    expected = false;
  };

  # ===== Canonical =====
  testCanonicalZeroesHostBits = {
    expr = cidr.toString (cidr.canonical (parse "10.0.0.5/24"));
    expected = "10.0.0.0/24";
  };
  testCanonicalAlready = {
    expr = cidr.toString (cidr.canonical (parse "10.0.0.0/24"));
    expected = "10.0.0.0/24";
  };
  testIsCanonicalTrue = {
    expr = cidr.isCanonical (parse "10.0.0.0/24");
    expected = true;
  };
  testIsCanonicalFalse = {
    expr = cidr.isCanonical (parse "10.0.0.5/24");
    expected = false;
  };

  # ===== subnet / supernet =====
  testSubnet1SplitsInTwo = {
    expr = map cidr.toString (cidr.subnet 1 (parse "10.0.0.0/24"));
    expected = [
      "10.0.0.0/25"
      "10.0.0.128/25"
    ];
  };
  testSubnet2SplitsInFour = {
    expr = map cidr.toString (cidr.subnet 2 (parse "10.0.0.0/24"));
    expected = [
      "10.0.0.0/26"
      "10.0.0.64/26"
      "10.0.0.128/26"
      "10.0.0.192/26"
    ];
  };
  testSubnet0Identity = {
    expr = map cidr.toString (cidr.subnet 0 (parse "10.0.0.0/24"));
    expected = [ "10.0.0.0/24" ];
  };
  testSubnetExceedsMax = {
    expr = throws (cidr.subnet 1 (parse "10.0.0.0/32"));
    expected = true;
  };
  testSubnetTooMany = {
    expr = throws (cidr.subnet 17 (parse "10.0.0.0/8"));
    expected = true;
  };
  testSubnetV6SplitsInTwo = {
    expr = map cidr.toString (cidr.subnet 1 (parse "2001:db8::/64"));
    expected = [
      "2001:db8::/65"
      "2001:db8:0:0:8000::/65"
    ];
  };
  testSubnetV6SplitsInFour = {
    expr = map cidr.toString (cidr.subnet 2 (parse "2001:db8::/64"));
    expected = [
      "2001:db8::/66"
      "2001:db8:0:0:4000::/66"
      "2001:db8:0:0:8000::/66"
      "2001:db8:0:0:c000::/66"
    ];
  };
  testSubnetV6ZeroIdentity = {
    expr = map cidr.toString (cidr.subnet 0 (parse "2001:db8::/64"));
    expected = [ "2001:db8::/64" ];
  };
  testSubnetV6OfPrefix0 = {
    expr = map cidr.toString (cidr.subnet 1 (parse "::/0"));
    expected = [
      "::/1"
      "8000::/1"
    ];
  };
  testSubnetV6OfPrefix127 = {
    expr = map cidr.toString (cidr.subnet 1 (parse "2001:db8::/127"));
    expected = [
      "2001:db8::/128"
      "2001:db8::1/128"
    ];
  };
  testSubnetV6ExceedsMax = {
    expr = throws (cidr.subnet 1 (parse "::1/128"));
    expected = true;
  };

  testSupernet1 = {
    expr = cidr.toString (cidr.supernet 1 (parse "10.0.0.0/24"));
    expected = "10.0.0.0/23";
  };
  testSupernet8 = {
    expr = cidr.toString (cidr.supernet 8 (parse "10.0.0.0/24"));
    expected = "10.0.0.0/16";
  };
  testSupernetFromPrefix0Throws = {
    expr = throws (cidr.supernet 1 (parse "0.0.0.0/0"));
    expected = true;
  };

  # ===== Set algebra =====
  testSummarizeMerge = {
    expr = map cidr.toString (
      cidr.summarize [
        (parse "10.0.0.0/25")
        (parse "10.0.0.128/25")
      ]
    );
    expected = [ "10.0.0.0/24" ];
  };
  testSummarizeDuplicate = {
    expr = map cidr.toString (
      cidr.summarize [
        (parse "10.0.0.0/24")
        (parse "10.0.0.0/24")
      ]
    );
    expected = [ "10.0.0.0/24" ];
  };
  testSummarizeContained = {
    expr = map cidr.toString (
      cidr.summarize [
        (parse "10.0.0.0/8")
        (parse "10.0.0.0/24")
      ]
    );
    expected = [ "10.0.0.0/8" ];
  };
  testSummarizeMixed = {
    expr = map cidr.toString (
      cidr.summarize [
        (parse "10.0.0.0/24")
        (parse "::/0")
      ]
    );
    expected = [
      "10.0.0.0/24"
      "::/0"
    ];
  };
  testSummarizeFourToOne = {
    expr = map cidr.toString (
      cidr.summarize [
        (parse "10.0.0.0/26")
        (parse "10.0.0.64/26")
        (parse "10.0.0.128/26")
        (parse "10.0.0.192/26")
      ]
    );
    expected = [ "10.0.0.0/24" ];
  };
  testSummarizeEmpty = {
    expr = cidr.summarize [ ];
    expected = [ ];
  };

  testExcludeV4Half = {
    expr = map cidr.toString (cidr.exclude (parse "10.0.0.0/24") (parse "10.0.0.0/25"));
    expected = [ "10.0.0.128/25" ];
  };
  testExcludeV4Self = {
    expr = cidr.exclude (parse "10.0.0.0/24") (parse "10.0.0.0/24");
    expected = [ ];
  };
  testExcludeNotParent = {
    expr = throws (cidr.exclude (parse "10.0.0.0/24") (parse "11.0.0.0/25"));
    expected = true;
  };
  testExcludeV4Quarter = {
    expr = map cidr.toString (cidr.exclude (parse "10.0.0.0/24") (parse "10.0.0.0/26"));
    expected = [
      "10.0.0.64/26"
      "10.0.0.128/25"
    ];
  };
  testExcludeV6Half = {
    expr = map cidr.toString (cidr.exclude (parse "2001:db8::/64") (parse "2001:db8::/65"));
    expected = [ "2001:db8:0:0:8000::/65" ];
  };
  testExcludeV6Self = {
    expr = cidr.exclude (parse "2001:db8::/64") (parse "2001:db8::/64");
    expected = [ ];
  };
  testExcludeV6Depth2 = {
    expr = map cidr.toString (cidr.exclude (parse "2001:db8::/126") (parse "2001:db8::/128"));
    expected = [
      "2001:db8::1/128"
      "2001:db8::2/127"
    ];
  };
  testExcludeV6DeepLength = {
    expr = builtins.length (cidr.exclude (parse "2001:db8::/64") (parse "2001:db8::/128"));
    expected = 64;
  };
  testExcludeV6DeepFirst = {
    expr = cidr.toString (
      builtins.elemAt (cidr.exclude (parse "2001:db8::/64") (parse "2001:db8::/128")) 0
    );
    expected = "2001:db8::1/128";
  };
  testExcludeV6DeepLast = {
    expr = cidr.toString (
      builtins.elemAt (cidr.exclude (parse "2001:db8::/64") (parse "2001:db8::/128")) 63
    );
    expected = "2001:db8:0:0:8000::/65";
  };
  testExcludeV6NotParent = {
    expr = throws (cidr.exclude (parse "2001:db8::/64") (parse "2001:dead::/128"));
    expected = true;
  };

  testIntersectContained = {
    expr = cidr.toString (cidr.intersect (parse "10.0.0.0/8") (parse "10.0.0.0/24"));
    expected = "10.0.0.0/24";
  };
  testIntersectDisjoint = {
    expr = cidr.intersect (parse "10.0.0.0/24") (parse "11.0.0.0/24");
    expected = null;
  };
  testIntersectEqual = {
    expr = cidr.toString (cidr.intersect (parse "10.0.0.0/24") (parse "10.0.0.0/24"));
    expected = "10.0.0.0/24";
  };
  testIntersectCrossFamily = {
    expr = cidr.intersect (parse "10.0.0.0/24") (parse "::/0");
    expected = null;
  };

  # ===== make / fromAddress / accessors / direct containment =====
  testMakeOk = {
    expr = cidr.toString (cidr.make (ipv4.parse "10.0.0.0") 24);
    expected = "10.0.0.0/24";
  };
  testMakeBadPrefix = {
    expr = throws (cidr.make (ipv4.parse "10.0.0.0") 33);
    expected = true;
  };
  testMakeBadAddress = {
    expr = throws (cidr.make "10.0.0.0" 24);
    expected = true;
  };
  testMakeNonIntPrefix = {
    expr = throws (cidr.make (ipv4.parse "10.0.0.0") "24");
    expected = true;
  };
  testFromAddressV4 = {
    expr = cidr.toString (cidr.fromAddress (ipv4.parse "10.0.0.5"));
    expected = "10.0.0.5/32";
  };
  testFromAddressV6 = {
    expr = cidr.toString (cidr.fromAddress (ipv6.parse "2001:db8::1"));
    expected = "2001:db8::1/128";
  };
  testFromAddressBad = {
    expr = throws (cidr.fromAddress "10.0.0.5");
    expected = true;
  };
  testAddressAccessor = {
    expr = ipv4.toString (cidr.address (parse "10.0.0.5/24"));
    expected = "10.0.0.5";
  };
  testTopAddressV4 = {
    expr = ipv4.toString (cidr.topAddress (parse "10.0.0.0/24"));
    expected = "10.0.0.255";
  };
  testTopAddressV6 = {
    expr = ipv6.toString (cidr.topAddress (parse "2001:db8::/120"));
    expected = "2001:db8::ff";
  };
  testContainsAddressDirect = {
    expr = cidr.containsAddress (parse "10.0.0.0/24") (ipv4.parse "10.0.0.5");
    expected = true;
  };
  testContainsAddressOut = {
    expr = cidr.containsAddress (parse "10.0.0.0/24") (ipv4.parse "10.0.1.0");
    expected = false;
  };
  testContainsCidrDirect = {
    expr = cidr.containsCidr (parse "10.0.0.0/8") (parse "10.1.0.0/16");
    expected = true;
  };
  testContainsCidrOut = {
    expr = cidr.containsCidr (parse "10.0.0.0/24") (parse "11.0.0.0/24");
    expected = false;
  };

  # ===== Comparison helpers =====
  testComparisonLt = {
    expr = cidr.lt (parse "10.0.0.0/24") (parse "10.0.0.0/25");
    expected = true;
  };
  testComparisonLe = {
    expr = cidr.le (parse "10.0.0.0/24") (parse "10.0.0.0/25");
    expected = true;
  };
  testComparisonGt = {
    expr = cidr.gt (parse "10.0.0.0/25") (parse "10.0.0.0/24");
    expected = true;
  };
  testComparisonGe = {
    expr = cidr.ge (parse "10.0.0.0/25") (parse "10.0.0.0/24");
    expected = true;
  };
  testComparisonMin = {
    expr = cidr.toString (cidr.min (parse "10.0.0.0/24") (parse "10.0.0.0/25"));
    expected = "10.0.0.0/24";
  };
  testComparisonMax = {
    expr = cidr.toString (cidr.max (parse "10.0.0.0/24") (parse "10.0.0.0/25"));
    expected = "10.0.0.0/25";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = cidr.eq (parse "10.0.0.0/24") (parse "10.0.0.0/24");
    expected = true;
  };
  testEqNonCanonical = {
    expr = cidr.eq (parse "10.0.0.0/24") (parse "10.0.0.5/24");
    expected = true;
  }; # canonical eq
  testEqDifferentPrefix = {
    expr = cidr.eq (parse "10.0.0.0/24") (parse "10.0.0.0/25");
    expected = false;
  };
  testEqDifferentNetwork = {
    expr = cidr.eq (parse "10.0.0.0/24") (parse "10.0.1.0/24");
    expected = false;
  };
  testEqCrossFamily = {
    expr = cidr.eq (parse "10.0.0.0/24") (parse "::/0");
    expected = false;
  };
  testCompareV4V6 = {
    expr = cidr.compare (parse "10.0.0.0/24") (parse "::/0");
    expected = -1;
  };
  testCompareV6V4 = {
    expr = cidr.compare (parse "::/0") (parse "10.0.0.0/24");
    expected = 1;
  };
  testCompareSame = {
    expr = cidr.compare (parse "10.0.0.0/24") (parse "10.0.0.0/24");
    expected = 0;
  };
  testComparePrefixLt = {
    expr = cidr.compare (parse "10.0.0.0/24") (parse "10.0.0.0/25");
    expected = -1;
  };
}
