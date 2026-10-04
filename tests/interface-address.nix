{ harness }:
let
  interfaceAddress = import ../lib/interface-address.nix;
  cidr = import ../lib/cidr.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  inherit (harness) throws;
  parse = interfaceAddress.parse;
in
{
  # ===== Parse =====
  testParseV4 = {
    expr = interfaceAddress.toString (parse "192.168.1.5/24");
    expected = "192.168.1.5/24";
  };
  testParseV4ZeroHost = {
    expr = interfaceAddress.toString (parse "192.168.1.0/24");
    expected = "192.168.1.0/24";
  };
  testParseV6 = {
    expr = interfaceAddress.toString (parse "2001:db8::5/64");
    expected = "2001:db8::5/64";
  };
  testParseV4Prefix32 = {
    expr = interfaceAddress.toString (parse "1.2.3.4/32");
    expected = "1.2.3.4/32";
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
  testRejectBadPrefix = {
    expr = throws (parse "10.0.0.0/a");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (parse 42);
    expected = true;
  };

  # A bare ifname is not an interfaceAddress (it has no `/prefix`).
  testParseBareNameThrows = {
    expr = throws (parse "eth0");
    expected = true;
  };
  testIsValidBareNameFalse = {
    expr = interfaceAddress.isValid "eth0";
    expected = false;
  };

  # ===== tryParse =====
  testTryParseOk = {
    expr = (interfaceAddress.tryParse "10.0.0.1/24").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (interfaceAddress.tryParse "nope").success;
    expected = false;
  };

  # ===== Preserves host bits (distinguishes from cidr) =====
  testParsePreservesHost = {
    expr = (parse "192.168.1.5/24").address.value;
    expected = (ipv4.parse "192.168.1.5").value;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = interfaceAddress.is (parse "192.168.1.5/24");
    expected = true;
  };
  testIsCidrValue = {
    expr = interfaceAddress.is (cidr.parse "192.168.1.0/24");
    expected = false;
  };
  testIsString = {
    expr = interfaceAddress.is "192.168.1.5/24";
    expected = false;
  };
  testIsIpv4V4 = {
    expr = interfaceAddress.isIpv4 (parse "192.168.1.5/24");
    expected = true;
  };
  testIsIpv6V6 = {
    expr = interfaceAddress.isIpv6 (parse "::1/64");
    expected = true;
  };
  testIsValidOk = {
    expr = interfaceAddress.isValid "192.168.1.5/24";
    expected = true;
  };

  # ===== Accessors =====
  testPrefixV4 = {
    expr = interfaceAddress.prefix (parse "192.168.1.5/24");
    expected = 24;
  };
  testAddressAccessor = {
    expr = (interfaceAddress.address (parse "192.168.1.5/24")).value;
    expected = (ipv4.parse "192.168.1.5").value;
  };
  testVersionV4 = {
    expr = interfaceAddress.version (parse "192.168.1.5/24");
    expected = 4;
  };
  testVersionV6 = {
    expr = interfaceAddress.version (parse "::1/64");
    expected = 6;
  };

  # ===== Derived =====
  testNetworkV4 = {
    expr = cidr.toString (interfaceAddress.network (parse "192.168.1.5/24"));
    expected = "192.168.1.0/24";
  };
  testNetworkV6 = {
    expr = cidr.toString (interfaceAddress.network (parse "2001:db8::5/64"));
    expected = "2001:db8::/64";
  };
  testNetmaskV4 = {
    expr = ipv4.toString (interfaceAddress.netmask (parse "192.168.1.5/24"));
    expected = "255.255.255.0";
  };
  testHostmaskV4 = {
    expr = ipv4.toString (interfaceAddress.hostmask (parse "192.168.1.5/24"));
    expected = "0.0.0.255";
  };
  testBroadcastV4 = {
    expr = ipv4.toString (interfaceAddress.broadcast (parse "192.168.1.5/24"));
    expected = "192.168.1.255";
  };
  testBroadcastV6Throws = {
    expr = throws (interfaceAddress.broadcast (parse "::1/64"));
    expected = true;
  };

  # ===== Conversions =====
  # toCidr preserves host bits; network returns the canonical block.
  testToCidrPreservesHost = {
    expr = cidr.toString (interfaceAddress.toCidr (parse "192.168.1.5/24"));
    expected = "192.168.1.5/24";
  };
  testToCidrV6PreservesHost = {
    expr = cidr.toString (interfaceAddress.toCidr (parse "2001:db8::5/64"));
    expected = "2001:db8::5/64";
  };
  testNetworkVsToCidr = {
    expr = cidr.toString (interfaceAddress.network (parse "192.168.1.5/24"));
    expected = "192.168.1.0/24";
  };
  testToRange = {
    expr = (interfaceAddress.toRange (parse "192.168.1.5/24")).to.value;
    expected = (ipv4.parse "192.168.1.255").value;
  };

  # ===== Constructors =====
  testMakeOk = {
    expr = interfaceAddress.toString (interfaceAddress.make (ipv4.parse "10.0.0.1") 24);
    expected = "10.0.0.1/24";
  };
  testMakeBadPrefixThrows = {
    expr = throws (interfaceAddress.make (ipv4.parse "10.0.0.1") 33);
    expected = true;
  };
  testMakeNonIpThrows = {
    expr = throws (interfaceAddress.make "10.0.0.1" 24);
    expected = true;
  };

  # ===== fromAddress =====
  testFromAddressV4 = {
    expr = interfaceAddress.toString (interfaceAddress.fromAddress (ipv4.parse "10.0.0.1"));
    expected = "10.0.0.1/32";
  };
  testFromAddressV6 = {
    expr = interfaceAddress.toString (interfaceAddress.fromAddress (ipv6.parse "2001:db8::1"));
    expected = "2001:db8::1/128";
  };
  testFromAddressNonIpThrows = {
    expr = throws (interfaceAddress.fromAddress "10.0.0.1");
    expected = true;
  };

  # ===== fromAddressAndNetwork =====
  testFromAddressAndNetworkOk = {
    expr = interfaceAddress.toString (
      interfaceAddress.fromAddressAndNetwork (ipv4.parse "192.168.1.5") (cidr.parse "192.168.1.0/24")
    );
    expected = "192.168.1.5/24";
  };
  testFromAddressAndNetworkOutside = {
    expr = throws (
      interfaceAddress.fromAddressAndNetwork (ipv4.parse "10.0.0.1") (cidr.parse "192.168.1.0/24")
    );
    expected = true;
  };
  testFromAddressAndNetworkMixedFamilies = {
    expr = throws (
      interfaceAddress.fromAddressAndNetwork (ipv4.parse "192.168.1.5") (cidr.parse "::/0")
    );
    expected = true;
  };

  # ===== Distinction from CIDR =====
  # interfaceAddress vs cidr with same text representation must NOT be equal.
  testTypeDiffersFromCidr = {
    expr = (parse "192.168.1.5/24")._type != (cidr.parse "192.168.1.5/24")._type;
    expected = true;
  };
  testTypeTag = {
    expr = (parse "192.168.1.5/24")._type;
    expected = "interfaceAddress";
  };

  # ===== Comparison helpers =====
  testLt = {
    expr = interfaceAddress.lt (parse "10.0.0.1/24") (parse "10.0.0.2/24");
    expected = true;
  };
  testLe = {
    expr = interfaceAddress.le (parse "10.0.0.1/24") (parse "10.0.0.2/24");
    expected = true;
  };
  testGt = {
    expr = interfaceAddress.gt (parse "10.0.0.2/24") (parse "10.0.0.1/24");
    expected = true;
  };
  testGe = {
    expr = interfaceAddress.ge (parse "10.0.0.2/24") (parse "10.0.0.1/24");
    expected = true;
  };
  testMin = {
    expr = interfaceAddress.toString (interfaceAddress.min (parse "10.0.0.1/24") (parse "10.0.0.2/24"));
    expected = "10.0.0.1/24";
  };
  testMax = {
    expr = interfaceAddress.toString (interfaceAddress.max (parse "10.0.0.1/24") (parse "10.0.0.2/24"));
    expected = "10.0.0.2/24";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = interfaceAddress.eq (parse "10.0.0.1/24") (parse "10.0.0.1/24");
    expected = true;
  };
  testEqDifferentAddress = {
    expr = interfaceAddress.eq (parse "10.0.0.1/24") (parse "10.0.0.2/24");
    expected = false;
  };
  testEqDifferentPrefix = {
    expr = interfaceAddress.eq (parse "10.0.0.1/24") (parse "10.0.0.1/25");
    expected = false;
  };
  testCompareCrossFamily = {
    expr = interfaceAddress.compare (parse "10.0.0.1/24") (parse "::1/64");
    expected = -1;
  };
  testCompareSame = {
    expr = interfaceAddress.compare (parse "10.0.0.1/24") (parse "10.0.0.1/24");
    expected = 0;
  };
  testCompareByAddress = {
    expr = interfaceAddress.compare (parse "10.0.0.1/24") (parse "10.0.0.2/24");
    expected = -1;
  };
  testCompareByPrefix = {
    expr = interfaceAddress.compare (parse "10.0.0.1/24") (parse "10.0.0.1/25");
    expected = -1;
  };

  # ===== Forwarded predicates (apply to the address) =====
  testForwardedLoopbackV4 = {
    expr = interfaceAddress.isLoopback (parse "127.0.0.1/8");
    expected = true;
  };
  testForwardedLoopbackV6 = {
    expr = interfaceAddress.isLoopback (parse "::1/128");
    expected = true;
  };
  testForwardedLoopbackNo = {
    expr = interfaceAddress.isLoopback (parse "8.8.8.8/32");
    expected = false;
  };
  testForwardedUnspecifiedV6 = {
    expr = interfaceAddress.isUnspecified (parse "::/128");
    expected = true;
  };
  testForwardedUnspecifiedNo = {
    expr = interfaceAddress.isUnspecified (parse "192.0.2.1/24");
    expected = false;
  };
  testForwardedLinkLocalV6 = {
    expr = interfaceAddress.isLinkLocal (parse "fe80::1/64");
    expected = true;
  };
  testForwardedMulticastV4 = {
    expr = interfaceAddress.isMulticast (parse "224.0.0.1/32");
    expected = true;
  };
  testForwardedDocumentationV4 = {
    expr = interfaceAddress.isDocumentation (parse "192.0.2.1/24");
    expected = true;
  };
  testForwardedGlobalV4 = {
    expr = interfaceAddress.isGlobal (parse "8.8.8.8/32");
    expected = true;
  };
  testForwardedBogonV4 = {
    expr = interfaceAddress.isBogon (parse "10.0.0.1/24");
    expected = true;
  };
  testForwardedBogonV6 = {
    expr = interfaceAddress.isBogon (parse "fc00::1/64");
    expected = true;
  };
  testForwardedToArpaV4 = {
    expr = interfaceAddress.toArpa (parse "1.2.3.4/32");
    expected = "4.3.2.1.in-addr.arpa";
  };
  testForwardedToArpaV6 = {
    expr = interfaceAddress.toArpa (parse "::1/128");
    expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa";
  };

  # ===== Round-trip =====
  testRoundTrip = {
    expr = interfaceAddress.toString (parse "192.168.1.5/24");
    expected = "192.168.1.5/24";
  };
}
