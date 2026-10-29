{ helpers, libnet, ... }:
let
  inherit (libnet)
    cidr
    interfaceAddress
    ipv4
    ipv6
    ;
  inherit (helpers) throws;
  inherit (interfaceAddress) parse;
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

  testRejectLeadingZeroPrefix = {
    expr = map (input: (interfaceAddress.tryParse input).success) [
      "10.0.0.1/08"
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
    expr = (interfaceAddress.tryParse "10.0.0.1/08").error;
    expected = "libnet.interfaceAddress.parse: invalid prefix \"08\"";
  };
  testTryParseOverlongPrefix = {
    expr = map (input: (interfaceAddress.tryParse input).success) [
      "10.0.0.1/99999999999999999999"
      "::/99999999999999999999"
    ];
    expected = [
      false
      false
    ];
  };
  testTryParseOverlongPrefixError = {
    expr = (interfaceAddress.tryParse "10.0.0.1/99999999999999999999").error;
    expected = "libnet.interfaceAddress.parse: prefix /99999999999999999999 out of range";
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
  testCidrV4 = {
    expr = cidr.toString (interfaceAddress.cidr (parse "192.168.1.5/24"));
    expected = "192.168.1.0/24";
  };
  testCidrV6 = {
    expr = cidr.toString (interfaceAddress.cidr (parse "2001:db8::5/64"));
    expected = "2001:db8::/64";
  };
  testCidrV4Prefix0 = {
    expr = cidr.toString (interfaceAddress.cidr (parse "10.1.2.3/0"));
    expected = "0.0.0.0/0";
  };
  testCidrV4Prefix32 = {
    expr = cidr.toString (interfaceAddress.cidr (parse "10.1.2.3/32"));
    expected = "10.1.2.3/32";
  };
  testCidrV6Prefix0 = {
    expr = cidr.toString (interfaceAddress.cidr (parse "2001:db8::5/0"));
    expected = "::/0";
  };
  testCidrV6Prefix128 = {
    expr = cidr.toString (interfaceAddress.cidr (parse "2001:db8::5/128"));
    expected = "2001:db8::5/128";
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
    expr = interfaceAddress.broadcast (parse "::1/64");
    expectedError.msg = "^libnet\\.interfaceAddress\\.broadcast: IPv6 has no broadcast$";
  };
  testNetmaskV6 = {
    expr = ipv6.toString (interfaceAddress.netmask (parse "2001:db8::5/64"));
    expected = "ffff:ffff:ffff:ffff::";
  };
  testHostmaskV6 = {
    expr = ipv6.toString (interfaceAddress.hostmask (parse "2001:db8::5/120"));
    expected = "::ff";
  };
  testNetmaskRejectsCidr = {
    expr = interfaceAddress.netmask (cidr.parse "192.168.1.0/24");
    expectedError.msg = "^libnet\\.interfaceAddress\\.netmask: expected interfaceAddress value, got cidr value$";
  };
  testCidrRejectsAddress = {
    expr = interfaceAddress.cidr (ipv4.parse "192.168.1.5");
    expectedError.msg = "^libnet\\.interfaceAddress\\.cidr: expected interfaceAddress value, got ipv4 value$";
  };

  # ===== Removed =====
  # `ipRange.fromCidr (interfaceAddress.cidr ia)` replaces `toRange`.
  testRemovedFunctions = {
    expr = builtins.filter (name: interfaceAddress ? ${name}) [ "toRange" ];
    expected = [ ];
  };

  # ===== Constructors =====
  testMakeOk = {
    expr = interfaceAddress.toString (interfaceAddress.make (ipv4.parse "10.0.0.1") 24);
    expected = "10.0.0.1/24";
  };
  testMakeBadPrefixThrows = {
    expr = interfaceAddress.make (ipv4.parse "10.0.0.1") 33;
    expectedError.msg = "^libnet\\.interfaceAddress\\.make: prefix out of range \\[0, 32\\]: 33$";
  };
  testMakeV6Prefix128 = {
    expr = interfaceAddress.toString (interfaceAddress.make (ipv6.parse "::1") 128);
    expected = "::1/128";
  };
  testMakeV6Prefix129Throws = {
    expr = interfaceAddress.make (ipv6.parse "::1") 129;
    expectedError.msg = "^libnet\\.interfaceAddress\\.make: prefix out of range \\[0, 128\\]: 129$";
  };
  testMakeNonIpThrows = {
    expr = interfaceAddress.make "10.0.0.1" 24;
    expectedError.msg = "^libnet\\.interfaceAddress\\.make: expected ipv4 or ipv6 value, got string$";
  };
  testMakeFloatPrefixThrows = {
    expr = interfaceAddress.make (ipv4.parse "10.0.0.1") 24.0;
    expectedError.msg = "^libnet\\.interfaceAddress\\.make: expected int, got float$";
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
    expr = interfaceAddress.fromAddress "10.0.0.1";
    expectedError.msg = "^libnet\\.interfaceAddress\\.fromAddress: expected ipv4 or ipv6 value, got string$";
  };

  # ===== fromCidrAndAddress =====
  testFromCidrAndAddressOk = {
    expr = interfaceAddress.toString (
      interfaceAddress.fromCidrAndAddress (cidr.parse "192.168.1.0/24") (ipv4.parse "192.168.1.5")
    );
    expected = "192.168.1.5/24";
  };
  testFromCidrAndAddressV6 = {
    expr = interfaceAddress.toString (
      interfaceAddress.fromCidrAndAddress (cidr.parse "2001:db8::/64") (ipv6.parse "2001:db8::5")
    );
    expected = "2001:db8::5/64";
  };
  testFromCidrAndAddressPartial = {
    expr = map interfaceAddress.toString (
      map (interfaceAddress.fromCidrAndAddress (cidr.parse "10.0.0.0/24")) (
        map ipv4.parse [
          "10.0.0.1"
          "10.0.0.2"
        ]
      )
    );
    expected = [
      "10.0.0.1/24"
      "10.0.0.2/24"
    ];
  };
  testFromCidrAndAddressOutside = {
    expr = interfaceAddress.fromCidrAndAddress (cidr.parse "192.168.1.0/24") (ipv4.parse "10.0.0.1");
    expectedError.msg = "^libnet\\.interfaceAddress\\.fromCidrAndAddress: address not in cidr$";
  };
  testFromCidrAndAddressMixedFamilies = {
    expr = interfaceAddress.fromCidrAndAddress (cidr.parse "::/0") (ipv4.parse "192.168.1.5");
    expectedError.msg = "^libnet\\.interfaceAddress\\.fromCidrAndAddress: family mismatch$";
  };
  testFromCidrAndAddressNonCidr = {
    expr = interfaceAddress.fromCidrAndAddress "192.168.1.0/24" (ipv4.parse "192.168.1.5");
    expectedError.msg = "^libnet\\.interfaceAddress\\.fromCidrAndAddress: expected cidr value, got string$";
  };
  testFromCidrAndAddressNonAddress = {
    expr = interfaceAddress.fromCidrAndAddress (cidr.parse "192.168.1.0/24") "192.168.1.5";
    expectedError.msg = "^libnet\\.interfaceAddress\\.fromCidrAndAddress: expected ipv4 or ipv6 value, got string$";
  };

  # ===== Distinction from CIDR =====
  # interfaceAddress vs cidr with same text representation must NOT be equal.
  testTypeDiffersFromCidr = {
    expr = (parse "192.168.1.0/24")._type != (cidr.parse "192.168.1.0/24")._type;
    expected = true;
  };
  # Host bits are valid only in an interface address.
  testHostBitsRejectedByCidr = {
    expr = [
      (interfaceAddress.isValid "192.168.1.5/24")
      (cidr.isValid "192.168.1.5/24")
    ];
    expected = [
      true
      false
    ];
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

  testForwardedRejectsAddress = {
    expr = interfaceAddress.isLoopback (ipv4.parse "127.0.0.1");
    expectedError.msg = "^libnet\\.interfaceAddress\\.isLoopback: expected interfaceAddress value, got ipv4 value$";
  };
  testToArpaRejectsCidr = {
    expr = interfaceAddress.toArpa (cidr.parse "10.0.0.0/8");
    expectedError.msg = "^libnet\\.interfaceAddress\\.toArpa: expected interfaceAddress value, got cidr value$";
  };
  testCompareRejectsCidr = {
    expr = interfaceAddress.compare (parse "10.0.0.1/24") (cidr.parse "10.0.0.0/24");
    expectedError.msg = "^libnet\\.interfaceAddress\\.compare: expected interfaceAddress value, got cidr value$";
  };
  testMinRejectsString = {
    expr = interfaceAddress.min "10.0.0.1/24" (parse "10.0.0.1/24");
    expectedError.msg = "^libnet\\.interfaceAddress\\.min: expected interfaceAddress value, got string$";
  };
  # The address's failure keeps its detail under interfaceAddress.parse
  # alone.
  testParseBadAddressNamesParseOnce = {
    expr =
      let
        inherit (interfaceAddress.tryParse "300.0.0.1/24") error;
      in
      [
        (builtins.match "libnet[.]interfaceAddress[.]parse: .*" error != null)
        (builtins.match ".*libnet[.]ipv4.*" error == null)
      ];
    expected = [
      true
      true
    ];
  };

  # ===== Round-trip =====
  testRoundTrip = {
    expr = interfaceAddress.toString (parse "192.168.1.5/24");
    expected = "192.168.1.5/24";
  };
}
