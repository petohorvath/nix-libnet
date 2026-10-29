{ helpers, libnet, ... }:
let
  inherit (libnet) cidr ipv4 ipv6;
  inherit (helpers) throws;
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

  # ===== Parse: negative =====
  # The address's failure keeps its detail under cidr.parse alone.
  testParseBadAddressNamesCidrParseOnce = {
    expr =
      map
        (
          input:
          let
            inherit (cidr.tryParse input) error;
          in
          [
            (builtins.match "libnet[.]cidr[.]parse: .*" error != null)
            (builtins.match ".*libnet[.]ipv[46].*" error == null)
          ]
        )
        [
          "300.0.0.0/8"
          "2001:db8:::/32"
        ];
    expected = [
      [
        true
        true
      ]
      [
        true
        true
      ]
    ];
  };
  testParseHostBitsNamesParse = {
    expr = parse "10.0.0.5/24";
    expectedError.msg = "^libnet\\.cidr\\.parse: host bits set in \"10\\.0\\.0\\.5/24\"; the CIDR is 10\\.0\\.0\\.0/24";
  };
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
  testRejectV4HostBits = {
    expr = throws (parse "10.0.0.5/24");
    expected = true;
  };
  testRejectV4HostBitsPrefix0 = {
    expr = throws (parse "0.0.0.1/0");
    expected = true;
  };
  testRejectV4HostBitsPrefix31 = {
    expr = throws (parse "10.0.0.1/31");
    expected = true;
  };
  testRejectV6HostBits = {
    expr = throws (parse "2001:db8::1/64");
    expected = true;
  };
  testRejectV6HostBitsPrefix127 = {
    expr = throws (parse "2001:db8::1/127");
    expected = true;
  };
  testRejectV6HostBitsWord0Prefix0 = {
    expr = throws (parse "8000::/0");
    expected = true;
  };
  testRejectV6HostBitsInsideWordPrefix33 = {
    expr = throws (parse "2001:db8:4000::/33");
    expected = true;
  };
  testRejectV6HostBitsWordBoundaryPrefix96 = {
    expr = throws (parse "::1/96");
    expected = true;
  };
  testParseV6Prefix33 = {
    expr = cidr.toString (parse "2001:db8:8000::/33");
    expected = "2001:db8:8000::/33";
  };
  testRejectBadAddress = {
    expr = throws (parse "999.0.0.0/24");
    expected = true;
  };

  testRejectLeadingZeroPrefix = {
    expr = map (input: (cidr.tryParse input).success) [
      "10.0.0.0/08"
      "0.0.0.0/00"
      "2001:db8::/032"
    ];
    expected = [
      false
      false
      false
    ];
  };
  testRejectLeadingZeroPrefixError = {
    expr = (cidr.tryParse "10.0.0.0/08").error;
    expected = "libnet.cidr.parse: invalid prefix \"08\"";
  };
  testTryParseOverlongPrefix = {
    expr = map (input: (cidr.tryParse input).success) [
      "10.0.0.0/99999999999999999999"
      "::/99999999999999999999"
    ];
    expected = [
      false
      false
    ];
  };
  testTryParseOverlongPrefixError = {
    expr = (cidr.tryParse "10.0.0.0/99999999999999999999").error;
    expected = "libnet.cidr.parse: prefix /99999999999999999999 out of range";
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
  testTryParseHostBitsError = {
    expr = (cidr.tryParse "10.0.0.5/24").error;
    expected = "libnet.cidr.parse: host bits set in \"10.0.0.5/24\"; the CIDR is 10.0.0.0/24, and interfaceAddress keeps a host address with its prefix";
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
  testTryParseV6HostBitsError = {
    expr = (cidr.tryParse "2001:db8::1/64").error;
    expected = "libnet.cidr.parse: host bits set in \"2001:db8::1/64\"; the CIDR is 2001:db8::/64, and interfaceAddress keeps a host address with its prefix";
  };
  testIsValidHostBits = {
    expr = cidr.isValid "10.0.0.5/24";
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
  testNetworkAddressV4Prefix24 = {
    expr = formatIpv4 (cidr.networkAddress (parse "10.0.0.0/24"));
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
  testHostCountV4Prefix24 = {
    expr = cidr.hostCount (parse "10.0.0.0/24");
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
  testHostCountV4Prefix30 = {
    expr = cidr.hostCount (parse "10.0.0.0/30");
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
  testHostCountV4Prefix31 = {
    expr = cidr.hostCount (parse "10.0.0.0/31");
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
  testHostCountV4Prefix32 = {
    expr = cidr.hostCount (parse "1.2.3.4/32");
    expected = 1;
  };

  # ===== Derived values: v4 /0 =====
  testSizeV4Prefix0 = {
    expr = cidr.size (parse "0.0.0.0/0");
    expected = 4294967296;
  };

  # ===== Derived values: v6 /64 =====
  testNetworkAddressV6Prefix64 = {
    expr = formatIpv6 (cidr.networkAddress (parse "2001:db8::/64"));
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
    expr = cidr.broadcast (parse "2001:db8::/64");
    expectedError.msg = "^libnet\\.cidr\\.broadcast: IPv6 has no broadcast$";
  };
  testBroadcastV4Prefix30 = {
    expr = formatIpv4 (cidr.broadcast (parse "10.0.0.0/30"));
    expected = "10.0.0.3";
  };
  # RFC 3021: both addresses of a /31 are hosts, so it has no broadcast.
  testBroadcastV4Prefix31Throws = {
    expr = cidr.broadcast (parse "10.0.0.0/31");
    expectedError.msg = "^libnet\\.cidr\\.broadcast: /31 has no broadcast \\(RFC 3021\\)$";
  };
  testBroadcastV4Prefix32Throws = {
    expr = cidr.broadcast (parse "10.0.0.1/32");
    expectedError.msg = "^libnet\\.cidr\\.broadcast: /32 has no broadcast$";
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
    expr = cidr.size (parse "::/65");
    expectedError.msg = "^libnet\\.cidr\\.size: block too large for a Nix integer \\(2\\^63 addresses\\)$";
  };
  testSizeV6Prefix0Throws = {
    expr = throws (cidr.size (parse "::/0"));
    expected = true;
  };
  testSizeV6Prefix66 = {
    expr = cidr.size (parse "::/66");
    expected = 4611686018427387904;
  };
  testHostCountV6Prefix120 = {
    expr = cidr.hostCount (parse "2001:db8::/120");
    expected = 255;
  };
  testHostCountV6Prefix64Throws = {
    expr = cidr.hostCount (parse "2001:db8::/64");
    expectedError.msg = "^libnet\\.cidr\\.hostCount: block too large for a Nix integer \\(2\\^64 addresses\\)$";
  };
  testHostCountV6Prefix66 = {
    expr = cidr.hostCount (parse "::/66");
    expected = 4611686018427387903;
  };
  testHostCountRejectsIpv4 = {
    expr = cidr.hostCount (ipv4.parse "10.0.0.0");
    expectedError.msg = "^libnet\\.cidr\\.hostCount: expected cidr value, got ipv4 value$";
  };
  testHostCountV6Prefix126 = {
    expr = cidr.hostCount (parse "2001:db8::/126");
    expected = 3;
  };
  testHostCountV6Prefix127 = {
    expr = cidr.hostCount (parse "2001:db8::/127");
    expected = 2;
  };
  testHostCountV6Prefix128 = {
    expr = cidr.hostCount (parse "::1/128");
    expected = 1;
  };
  testLastHostV6Prefix120 = {
    expr = formatIpv6 (cidr.lastHost (parse "2001:db8::/120"));
    expected = "2001:db8::ff";
  };

  # ===== Enumeration =====
  testAddressAt0 = {
    expr = formatIpv4 (cidr.addressAt 0 (parse "10.0.0.0/28"));
    expected = "10.0.0.0";
  };
  testAddressAt5 = {
    expr = formatIpv4 (cidr.addressAt 5 (parse "10.0.0.0/28"));
    expected = "10.0.0.5";
  };
  testAddressAtLast = {
    expr = formatIpv4 (cidr.addressAt 15 (parse "10.0.0.0/28"));
    expected = "10.0.0.15";
  };
  testAddressAtNegative1 = {
    expr = formatIpv4 (cidr.addressAt (-1) (parse "10.0.0.0/28"));
    expected = "10.0.0.15";
  };
  testAddressAtNegative2 = {
    expr = formatIpv4 (cidr.addressAt (-2) (parse "10.0.0.0/28"));
    expected = "10.0.0.14";
  };
  testAddressAtPartial = {
    expr = map formatIpv4 (
      map (cidr.addressAt 1) [
        (parse "10.0.0.0/24")
        (parse "192.168.0.0/30")
      ]
    );
    expected = [
      "10.0.0.1"
      "192.168.0.1"
    ];
  };
  testAddressAtV6 = {
    expr = formatIpv6 (cidr.addressAt (-1) (parse "2001:db8::/120"));
    expected = "2001:db8::ff";
  };
  testAddressAtOutOfRangePositive = {
    expr = cidr.addressAt 16 (parse "10.0.0.0/28");
    expectedError.msg = "^libnet\\.cidr\\.addressAt: index out of range \\[0, 16\\): 16$";
  };
  testAddressAtOutOfRangeNegative = {
    expr = cidr.addressAt (-17) (parse "10.0.0.0/28");
    expectedError.msg = "^libnet\\.cidr\\.addressAt: index out of range \\[0, 16\\): -17$";
  };
  testAddressAtRejectsFloat = {
    expr = cidr.addressAt 1.0 (parse "10.0.0.0/28");
    expectedError.msg = "^libnet\\.cidr\\.addressAt: expected int, got float$";
  };
  testAddressAtV6Prefix64Gateway = {
    expr = formatIpv6 (cidr.addressAt 1 (parse "2001:db8::/64"));
    expected = "2001:db8::1";
  };
  # A /64 holds 2^64 addresses, so every Int index lands inside: the
  # largest counts up from the network address and the smallest, -2^63,
  # counts back from the top address.
  testAddressAtV6Prefix64Ends = {
    expr = map (n: formatIpv6 (cidr.addressAt n (parse "2001:db8::/64"))) [
      0
      (-1)
      9223372036854775807
      (-9223372036854775807 - 1)
    ];
    expected = [
      "2001:db8::"
      "2001:db8::ffff:ffff:ffff:ffff"
      "2001:db8::7fff:ffff:ffff:ffff"
      "2001:db8:0:0:8000::"
    ];
  };
  # A /65 holds exactly 2^63 addresses, so the Int range reaches both ends.
  testAddressAtV6Prefix65Ends = {
    expr = map (n: formatIpv6 (cidr.addressAt n (parse "::/65"))) [
      9223372036854775807
      (-9223372036854775807 - 1)
    ];
    expected = [
      "::7fff:ffff:ffff:ffff"
      "::"
    ];
  };
  testAddressAtV6Prefix0Ends = {
    expr = map (n: formatIpv6 (cidr.addressAt n (parse "::/0"))) [
      1
      (-1)
    ];
    expected = [
      "::1"
      "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"
    ];
  };
  testAddressAtV6Prefix66Ends = {
    expr = map (n: formatIpv6 (cidr.addressAt n (parse "::/66"))) [
      0
      (-1)
      (-4611686018427387904)
    ];
    expected = [
      "::"
      "::3fff:ffff:ffff:ffff"
      "::"
    ];
  };
  testAddressAtV4Prefix0Ends = {
    expr = map (n: formatIpv4 (cidr.addressAt n (parse "0.0.0.0/0"))) [
      0
      (-1)
      4294967295
    ];
    expected = [
      "0.0.0.0"
      "255.255.255.255"
      "255.255.255.255"
    ];
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
    expr = cidr.hosts (parse "10.0.0.0/15");
    expectedError.msg = "^libnet\\.cidr\\.hosts: block too large \\(131072 addresses > 2\\^16\\); use addressAt or hostsUnbounded$";
  };
  testHostsAtLimit = {
    expr = builtins.length (cidr.hosts (parse "10.0.0.0/16"));
    expected = 65534;
  };
  testHostsV6Prefix64NamesHosts = {
    expr = cidr.hosts (parse "2001:db8::/64");
    expectedError.msg = "^libnet\\.cidr\\.hosts: block too large \\(2\\^64 addresses > 2\\^16\\); use addressAt$";
  };
  testHostsUnboundedV6Prefix64NamesItself = {
    expr = cidr.hostsUnbounded (parse "2001:db8::/64");
    expectedError.msg = "^libnet\\.cidr\\.hostsUnbounded: block too large for a Nix integer \\(2\\^64 addresses\\)$";
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
  # A block is not an element; the throw points callers at isSupernetOf.
  testContainsCidrThrows = {
    expr = cidr.contains (parse "10.0.0.0/8") (parse "10.1.0.0/16");
    expectedError.msg = "^libnet\\.cidr\\.contains: expected ipv4 or ipv6 value, got cidr value; test a block with isSupernetOf$";
  };
  testContainsNonAddress = {
    expr = cidr.contains (parse "10.0.0.0/24") "10.0.0.5";
    expectedError.msg = "^libnet\\.cidr\\.contains: expected ipv4 or ipv6 value, got string$";
  };
  testContainsMac = {
    expr = cidr.contains (parse "10.0.0.0/24") (libnet.mac.parse "00:00:5e:00:53:01");
    expectedError.msg = "^libnet\\.cidr\\.contains: expected ipv4 or ipv6 value, got mac value$";
  };
  testContainsAddressAsBlock = {
    expr = cidr.contains (ipv4.parse "10.0.0.0") (ipv4.parse "10.0.0.5");
    expectedError.msg = "^libnet\\.cidr\\.contains: expected cidr value, got ipv4 value$";
  };
  testContainsCrossFamily = {
    expr = cidr.contains (parse "10.0.0.0/24") (ipv6.parse "::1");
    expected = false;
  };
  testContainsV6 = {
    expr = cidr.contains (parse "2001:db8::/32") (ipv6.parse "2001:db8::1");
    expected = true;
  };
  testContainsPartial = {
    expr = map ipv4.toString (
      builtins.filter (cidr.contains (parse "10.0.0.0/24")) (
        map ipv4.parse [
          "10.0.0.5"
          "10.0.1.5"
          "10.0.0.255"
        ]
      )
    );
    expected = [
      "10.0.0.5"
      "10.0.0.255"
    ];
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
  testIsSubnetOfRejectsAddress = {
    expr = cidr.isSubnetOf (ipv4.parse "10.0.0.1") (parse "10.0.0.0/24");
    expectedError.msg = "^libnet\\.cidr\\.isSubnetOf: expected cidr value, got ipv4 value$";
  };
  testIsSupernetOfRejectsAddress = {
    expr = cidr.isSupernetOf (parse "10.0.0.0/24") (ipv4.parse "10.0.0.1");
    expectedError.msg = "^libnet\\.cidr\\.isSupernetOf: expected cidr value, got ipv4 value$";
  };
  testIsSupernetOfTrue = {
    expr = cidr.isSupernetOf (parse "10.0.0.0/8") (parse "10.0.0.0/24");
    expected = true;
  };
  testIsSupernetOfSelf = {
    expr = cidr.isSupernetOf (parse "10.0.0.0/24") (parse "10.0.0.0/24");
    expected = true;
  };
  testIsSupernetOfDisjoint = {
    expr = cidr.isSupernetOf (parse "10.0.0.0/24") (parse "10.1.0.0/24");
    expected = false;
  };
  testIsSupernetOfCrossFamily = {
    expr = cidr.isSupernetOf (parse "::/0") (parse "10.0.0.0/24");
    expected = false;
  };
  # The converse partially applied keeps the blocks inside the parameter.
  testIsSupernetOfPartial = {
    expr = map cidr.toString (
      builtins.filter (cidr.isSupernetOf (parse "10.0.0.0/8")) (
        map parse [
          "10.1.0.0/16"
          "11.0.0.0/16"
          "0.0.0.0/0"
        ]
      )
    );
    expected = [ "10.1.0.0/16" ];
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

  # ===== subnets / supernet =====
  testSubnets1SplitsInTwo = {
    expr = map cidr.toString (cidr.subnets 1 (parse "10.0.0.0/24"));
    expected = [
      "10.0.0.0/25"
      "10.0.0.128/25"
    ];
  };
  testSubnets2SplitsInFour = {
    expr = map cidr.toString (cidr.subnets 2 (parse "10.0.0.0/24"));
    expected = [
      "10.0.0.0/26"
      "10.0.0.64/26"
      "10.0.0.128/26"
      "10.0.0.192/26"
    ];
  };
  testSubnets0Identity = {
    expr = map cidr.toString (cidr.subnets 0 (parse "10.0.0.0/24"));
    expected = [ "10.0.0.0/24" ];
  };
  testSubnetsExceedsMax = {
    expr = cidr.subnets 1 (parse "10.0.0.0/32");
    expectedError.msg = "^libnet\\.cidr\\.subnets: resulting prefix /33 exceeds max /32$";
  };
  testSubnetsTooMany = {
    expr = cidr.subnets 17 (parse "10.0.0.0/8");
    expectedError.msg = "^libnet\\.cidr\\.subnets: n too large \\(>16\\); would produce > 2\\^16 subnets$";
  };
  testSubnetsNegative = {
    expr = cidr.subnets (-1) (parse "10.0.0.0/8");
    expectedError.msg = "^libnet\\.cidr\\.subnets: n must not be negative: -1$";
  };
  testSubnetsRejectsString = {
    expr = cidr.subnets "1" (parse "10.0.0.0/8");
    expectedError.msg = "^libnet\\.cidr\\.subnets: expected int, got string$";
  };
  testSubnetsV6SplitsInTwo = {
    expr = map cidr.toString (cidr.subnets 1 (parse "2001:db8::/64"));
    expected = [
      "2001:db8::/65"
      "2001:db8:0:0:8000::/65"
    ];
  };
  testSubnetsV6SplitsInFour = {
    expr = map cidr.toString (cidr.subnets 2 (parse "2001:db8::/64"));
    expected = [
      "2001:db8::/66"
      "2001:db8:0:0:4000::/66"
      "2001:db8:0:0:8000::/66"
      "2001:db8:0:0:c000::/66"
    ];
  };
  testSubnetsV6ZeroIdentity = {
    expr = map cidr.toString (cidr.subnets 0 (parse "2001:db8::/64"));
    expected = [ "2001:db8::/64" ];
  };
  testSubnetsV6OfPrefix0 = {
    expr = map cidr.toString (cidr.subnets 1 (parse "::/0"));
    expected = [
      "::/1"
      "8000::/1"
    ];
  };
  testSubnetsV6OfPrefix127 = {
    expr = map cidr.toString (cidr.subnets 1 (parse "2001:db8::/127"));
    expected = [
      "2001:db8::/128"
      "2001:db8::1/128"
    ];
  };
  testSubnetsV6ExceedsMax = {
    expr = throws (cidr.subnets 1 (parse "::1/128"));
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
  # Keeps the first 16 bits, `10.1`, not `10.0`.
  testSupernetKeepsSurvivingBits = {
    expr = cidr.toString (cidr.supernet 8 (parse "10.1.0.0/24"));
    expected = "10.1.0.0/16";
  };
  testSupernetFromPrefix0Throws = {
    expr = cidr.supernet 1 (parse "0.0.0.0/0");
    expectedError.msg = "^libnet\\.cidr\\.supernet: n exceeds current prefix /0: 1$";
  };
  testSupernetNegative = {
    expr = cidr.supernet (-1) (parse "10.0.0.0/8");
    expectedError.msg = "^libnet\\.cidr\\.supernet: n must not be negative: -1$";
  };
  testSupernetRejectsFloat = {
    expr = cidr.supernet 1.0 (parse "10.0.0.0/8");
    expectedError.msg = "^libnet\\.cidr\\.supernet: expected int, got float$";
  };
  testSummarizeRejectsSet = {
    expr = cidr.summarize { };
    expectedError.msg = "^libnet\\.cidr\\.summarize: expected list, got set$";
  };
  testSummarizeRejectsAddress = {
    expr = cidr.summarize [
      (parse "10.0.0.0/8")
      (ipv4.parse "10.0.0.0")
    ];
    expectedError.msg = "^libnet\\.cidr\\.summarize: expected cidr value, got ipv4 value$";
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
    expr = map cidr.toString (cidr.exclude (parse "10.0.0.0/25") (parse "10.0.0.0/24"));
    expected = [ "10.0.0.128/25" ];
  };
  # The removed block comes first, so `cidr.exclude reserved` maps over
  # pools.
  testExcludePartial = {
    expr = map cidr.toString (
      builtins.concatMap (cidr.exclude (parse "10.0.0.0/26")) [
        (parse "10.0.0.0/25")
        (parse "10.0.0.0/24")
      ]
    );
    expected = [
      "10.0.0.64/26"
      "10.0.0.64/26"
      "10.0.0.128/25"
    ];
  };
  testExcludeV4Self = {
    expr = cidr.exclude (parse "10.0.0.0/24") (parse "10.0.0.0/24");
    expected = [ ];
  };
  testExcludeNotParent = {
    expr = cidr.exclude (parse "11.0.0.0/25") (parse "10.0.0.0/24");
    expectedError.msg = "^libnet\\.cidr\\.exclude: child not contained in parent$";
  };
  testExcludeV4Quarter = {
    expr = map cidr.toString (cidr.exclude (parse "10.0.0.0/26") (parse "10.0.0.0/24"));
    expected = [
      "10.0.0.64/26"
      "10.0.0.128/25"
    ];
  };
  testExcludeV6Half = {
    expr = map cidr.toString (cidr.exclude (parse "2001:db8::/65") (parse "2001:db8::/64"));
    expected = [ "2001:db8:0:0:8000::/65" ];
  };
  testExcludeV6Self = {
    expr = cidr.exclude (parse "2001:db8::/64") (parse "2001:db8::/64");
    expected = [ ];
  };
  testExcludeV6Depth2 = {
    expr = map cidr.toString (cidr.exclude (parse "2001:db8::/128") (parse "2001:db8::/126"));
    expected = [
      "2001:db8::1/128"
      "2001:db8::2/127"
    ];
  };
  testExcludeV6DeepLength = {
    expr = builtins.length (cidr.exclude (parse "2001:db8::/128") (parse "2001:db8::/64"));
    expected = 64;
  };
  testExcludeV6DeepFirst = {
    expr = cidr.toString (
      builtins.elemAt (cidr.exclude (parse "2001:db8::/128") (parse "2001:db8::/64")) 0
    );
    expected = "2001:db8::1/128";
  };
  testExcludeV6DeepLast = {
    expr = cidr.toString (
      builtins.elemAt (cidr.exclude (parse "2001:db8::/128") (parse "2001:db8::/64")) 63
    );
    expected = "2001:db8:0:0:8000::/65";
  };
  testExcludeV6NotParent = {
    expr = throws (cidr.exclude (parse "2001:dead::/128") (parse "2001:db8::/64"));
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
  testIntersectRejectsString = {
    expr = cidr.intersect (parse "10.0.0.0/24") "10.0.0.0/24";
    expectedError.msg = "^libnet\\.cidr\\.intersect: expected cidr value, got string$";
  };
  testExcludeCrossFamily = {
    expr = cidr.exclude (parse "::/0") (parse "10.0.0.0/24");
    expectedError.msg = "^libnet\\.cidr\\.exclude: family mismatch$";
  };

  # ===== make / fromAddress / accessors / direct containment =====
  testMakeOk = {
    expr = cidr.toString (cidr.make (ipv4.parse "10.0.0.0") 24);
    expected = "10.0.0.0/24";
  };
  testMakeBadPrefix = {
    expr = cidr.make (ipv4.parse "10.0.0.0") 33;
    expectedError.msg = "^libnet\\.cidr\\.make: prefix out of range \\[0, 32\\]: 33$";
  };
  testMakeNegativePrefix = {
    expr = cidr.make (ipv6.parse "::") (-1);
    expectedError.msg = "^libnet\\.cidr\\.make: prefix out of range \\[0, 128\\]: -1$";
  };
  testMakeBadAddress = {
    expr = cidr.make "10.0.0.0" 24;
    expectedError.msg = "^libnet\\.cidr\\.make: expected ipv4 or ipv6 value, got string$";
  };
  testMakeHostBits = {
    expr = cidr.make (ipv4.parse "10.0.0.5") 24;
    expectedError.msg = "^libnet\\.cidr\\.make: host bits set in \"10\\.0\\.0\\.5/24\"";
  };
  testMakeV6HostBits = {
    expr = throws (cidr.make (ipv6.parse "2001:db8::1") 64);
    expected = true;
  };
  testMakeV6 = {
    expr = cidr.toString (cidr.make (ipv6.parse "2001:db8::") 32);
    expected = "2001:db8::/32";
  };
  testMakeNonIntPrefix = {
    expr = cidr.make (ipv4.parse "10.0.0.0") "24";
    expectedError.msg = "^libnet\\.cidr\\.make: expected int, got string$";
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
    expr = cidr.fromAddress "10.0.0.5";
    expectedError.msg = "^libnet\\.cidr\\.fromAddress: expected ipv4 or ipv6 value, got string$";
  };
  testFromAddressRejectsCidr = {
    expr = cidr.fromAddress (parse "10.0.0.0/8");
    expectedError.msg = "^libnet\\.cidr\\.fromAddress: expected ipv4 or ipv6 value, got cidr value$";
  };
  testNetworkAddressField = {
    expr = ipv4.toString (parse "10.0.0.0/24").networkAddress;
    expected = "10.0.0.0";
  };
  testTopAddressV4 = {
    expr = ipv4.toString (cidr.topAddress (parse "10.0.0.0/24"));
    expected = "10.0.0.255";
  };
  testTopAddressV6 = {
    expr = ipv6.toString (cidr.topAddress (parse "2001:db8::/120"));
    expected = "2001:db8::ff";
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
  testCompareRejectsAddress = {
    expr = cidr.compare (parse "10.0.0.0/24") (ipv4.parse "10.0.0.0");
    expectedError.msg = "^libnet\\.cidr\\.compare: expected cidr value, got ipv4 value$";
  };
  testGeRejectsInterfaceAddress = {
    expr = cidr.ge (libnet.interfaceAddress.parse "10.0.0.1/24") (parse "10.0.0.0/24");
    expectedError.msg = "^libnet\\.cidr\\.ge: expected cidr value, got interfaceAddress value$";
  };
  testMaxMixedFamilies = {
    expr = cidr.toString (cidr.max (parse "::/0") (parse "10.0.0.0/8"));
    expected = "::/0";
  };
}
