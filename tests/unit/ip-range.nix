{ helpers, libnet, ... }:
let
  inherit (libnet)
    cidr
    ipRange
    ipv4
    ipv6
    ;
  inherit (helpers) throws;
  inherit (ipRange) parse;
in
{
  # ===== Parse =====
  testParseV4 = {
    expr = ipRange.toString (parse "1.2.3.4-1.2.3.10");
    expected = "1.2.3.4-1.2.3.10";
  };
  testParseV4Singleton = {
    expr = ipRange.toString (parse "1.2.3.4-1.2.3.4");
    expected = "1.2.3.4-1.2.3.4";
  };
  testParseV6 = {
    expr = ipRange.toString (parse "2001:db8::1-2001:db8::ff");
    expected = "2001:db8::1-2001:db8::ff";
  };
  testRejectMixedFamilies = {
    expr = throws (parse "1.2.3.4-::1");
    expected = true;
  };
  testRejectReversed = {
    expr = throws (parse "1.2.3.10-1.2.3.4");
    expected = true;
  };
  testRejectNoDash = {
    expr = throws (parse "1.2.3.4");
    expected = true;
  };
  testRejectBadFrom = {
    expr = throws (parse "bad-1.2.3.4");
    expected = true;
  };

  # ===== tryParse =====
  testTryParseOk = {
    expr = (ipRange.tryParse "1.2.3.4-1.2.3.10").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (ipRange.tryParse "bad").success;
    expected = false;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = ipRange.is (parse "1.2.3.4-1.2.3.10");
    expected = true;
  };
  testIsString = {
    expr = ipRange.is "1.2.3.4-1.2.3.10";
    expected = false;
  };
  testIsIpv4V4 = {
    expr = ipRange.isIpv4 (parse "1.2.3.4-1.2.3.10");
    expected = true;
  };
  testIsIpv6V6 = {
    expr = ipRange.isIpv6 (parse "::1-::ff");
    expected = true;
  };
  testIsSingletonYes = {
    expr = ipRange.isSingleton (parse "1.2.3.4-1.2.3.4");
    expected = true;
  };
  testIsSingletonNo = {
    expr = ipRange.isSingleton (parse "1.2.3.4-1.2.3.5");
    expected = false;
  };

  # ===== Size =====
  testSizeV4 = {
    expr = ipRange.size (parse "1.2.3.4-1.2.3.10");
    expected = 7;
  };
  testSizeV4Singleton = {
    expr = ipRange.size (parse "1.2.3.4-1.2.3.4");
    expected = 1;
  };
  testSizeV6 = {
    expr = ipRange.size (parse "::1-::10");
    expected = 16;
  };
  testSizeV6Overflow = {
    expr = ipRange.size (parse "::-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff");
    expectedError.msg = "^libnet\\.ipRange\\.size: range too large for a Nix integer \\(2\\^63 or more addresses\\)$";
  };
  # 2^63 addresses: the difference fits a Nix integer, but adding one
  # does not.
  testSizeV6Exactly2To63Throws = {
    expr = ipRange.size (parse "::-::7fff:ffff:ffff:ffff");
    expectedError.msg = "^libnet\\.ipRange\\.size: range too large for a Nix integer \\(2\\^63 or more addresses\\)$";
  };
  testSizeV6Below2To63 = {
    expr = ipRange.size (parse "::-::7fff:ffff:ffff:fffe");
    expected = 9223372036854775807;
  };
  testSizeV6Exactly2To63HighWords = {
    expr = ipRange.size (parse "1::8000:0:0:0-1::ffff:ffff:ffff:ffff");
    expectedError.msg = "^libnet\\.ipRange\\.size: range too large for a Nix integer \\(2\\^63 or more addresses\\)$";
  };
  testSizeV4Full = {
    expr = ipRange.size (parse "0.0.0.0-255.255.255.255");
    expected = 4294967296;
  };
  testSizeRejectsCidr = {
    expr = ipRange.size (cidr.parse "10.0.0.0/8");
    expectedError.msg = "^libnet\\.ipRange\\.size: expected ipRange value, got cidr value$";
  };

  # ===== Containment =====
  testContainsInside = {
    expr = ipRange.contains (parse "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.5");
    expected = true;
  };
  testContainsFrom = {
    expr = ipRange.contains (parse "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.4");
    expected = true;
  };
  testContainsTo = {
    expr = ipRange.contains (parse "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.10");
    expected = true;
  };
  testContainsBelowFrom = {
    expr = ipRange.contains (parse "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.3");
    expected = false;
  };
  testContainsAboveTo = {
    expr = ipRange.contains (parse "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.11");
    expected = false;
  };
  testContainsRejectsCidr = {
    expr = ipRange.contains (parse "1.2.3.4-1.2.3.10") (cidr.parse "1.2.3.4/32");
    expectedError.msg = "^libnet\\.ipRange\\.contains: expected ipv4 or ipv6 value, got cidr value$";
  };
  testContainsRejectsString = {
    expr = ipRange.contains (parse "1.2.3.4-1.2.3.10") "1.2.3.5";
    expectedError.msg = "^libnet\\.ipRange\\.contains: expected ipv4 or ipv6 value, got string$";
  };
  testContainsRejectsCidrAsRange = {
    expr = ipRange.contains (cidr.parse "1.2.3.0/24") (ipv4.parse "1.2.3.5");
    expectedError.msg = "^libnet\\.ipRange\\.contains: expected ipRange value, got cidr value$";
  };
  testContainsCrossFamily = {
    expr = ipRange.contains (parse "1.2.3.4-1.2.3.10") (ipv6.parse "::1");
    expected = false;
  };

  # ===== Overlaps / subrange =====
  testOverlapsYes = {
    expr = ipRange.overlaps (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.8-1.2.3.15");
    expected = true;
  };
  testOverlapsNo = {
    expr = ipRange.overlaps (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.11-1.2.3.20");
    expected = false;
  };
  testOverlapsSame = {
    expr = ipRange.overlaps (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.4-1.2.3.10");
    expected = true;
  };
  testOverlapsCrossFamily = {
    expr = ipRange.overlaps (parse "1.2.3.4-1.2.3.10") (parse "::1-::ff");
    expected = false;
  };
  testIsSubrangeYes = {
    expr = ipRange.isSubrangeOf (parse "1.2.3.5-1.2.3.8") (parse "1.2.3.4-1.2.3.10");
    expected = true;
  };
  testIsSubrangeNo = {
    expr = ipRange.isSubrangeOf (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.5-1.2.3.8");
    expected = false;
  };
  testIsSuperrangeYes = {
    expr = ipRange.isSuperrangeOf (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.5-1.2.3.8");
    expected = true;
  };

  # ===== Merge =====
  testMergeOverlap = {
    expr = ipRange.toString (ipRange.merge (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.8-1.2.3.15"));
    expected = "1.2.3.4-1.2.3.15";
  };
  testMergeAdjacent = {
    expr = ipRange.toString (ipRange.merge (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.11-1.2.3.15"));
    expected = "1.2.3.4-1.2.3.15";
  };
  testMergeDisjoint = {
    expr = ipRange.merge (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.20-1.2.3.30");
    expected = null;
  };
  testMergeCrossFamily = {
    expr = ipRange.merge (parse "1.2.3.4-1.2.3.10") (parse "::1-::ff");
    expected = null;
  };
  testMergeContained = {
    expr = ipRange.toString (ipRange.merge (parse "1.2.3.0-1.2.3.255") (parse "1.2.3.10-1.2.3.50"));
    expected = "1.2.3.0-1.2.3.255";
  };

  # ===== Enumeration =====
  testAddressesSmall = {
    expr = map ipv4.toString (ipRange.addresses (parse "1.2.3.4-1.2.3.6"));
    expected = [
      "1.2.3.4"
      "1.2.3.5"
      "1.2.3.6"
    ];
  };
  testAddressesTooLarge = {
    expr = ipRange.addresses (parse "1.0.0.0-2.0.0.0");
    expectedError.msg = "^libnet\\.ipRange\\.addresses: range too large \\(16777217 > 2\\^16\\); use addressAt or addressesUnbounded$";
  };
  testAddressesAtLimit = {
    expr = builtins.length (ipRange.addresses (parse "10.0.0.0-10.0.255.255"));
    expected = 65536;
  };
  testAddressesAboveLimit = {
    expr = ipRange.addresses (parse "10.0.0.0-10.1.0.0");
    expectedError.msg = "^libnet\\.ipRange\\.addresses: range too large \\(65537 > 2\\^16\\)";
  };
  testAddressesV6Exactly2To63NamesAddresses = {
    expr = ipRange.addresses (parse "::-::7fff:ffff:ffff:ffff");
    expectedError.msg = "^libnet\\.ipRange\\.addresses: range too large \\(2\\^63 or more > 2\\^16\\); use addressAt$";
  };
  testAddressesV6HugeNamesAddresses = {
    expr = ipRange.addresses (parse "::-ffff::");
    expectedError.msg = "^libnet\\.ipRange\\.addresses: range too large \\(2\\^63 or more > 2\\^16\\); use addressAt$";
  };
  testAddressesUnboundedV6HugeNamesItself = {
    expr = ipRange.addressesUnbounded (parse "::-ffff::");
    expectedError.msg = "^libnet\\.ipRange\\.addressesUnbounded: range too large for a Nix integer \\(2\\^63 or more addresses\\)$";
  };
  testAddressAtFirst = {
    expr = ipv4.toString (ipRange.addressAt 0 (parse "1.2.3.4-1.2.3.6"));
    expected = "1.2.3.4";
  };
  testAddressAtNegative = {
    expr = ipv4.toString (ipRange.addressAt (-1) (parse "1.2.3.4-1.2.3.6"));
    expected = "1.2.3.6";
  };
  testAddressAtV6 = {
    expr = ipv6.toString (ipRange.addressAt 2 (parse "::1-::5"));
    expected = "::3";
  };
  testAddressAtOutOfBounds = {
    expr = ipRange.addressAt 3 (parse "1.2.3.4-1.2.3.6");
    expectedError.msg = "^libnet\\.ipRange\\.addressAt: index out of range \\[0, 3\\): 3$";
  };
  testAddressAtNegativeOutOfBounds = {
    expr = ipRange.addressAt (-4) (parse "1.2.3.4-1.2.3.6");
    expectedError.msg = "^libnet\\.ipRange\\.addressAt: index out of range \\[0, 3\\): -4$";
  };
  testAddressAtRejectsFloat = {
    expr = ipRange.addressAt 0.0 (parse "1.2.3.4-1.2.3.6");
    expectedError.msg = "^libnet\\.ipRange\\.addressAt: expected int, got float$";
  };
  # Exactly 2^63 addresses, so the Int range reaches both ends.
  testAddressAtV6Exactly2To63Ends = {
    expr = map (n: ipv6.toString (ipRange.addressAt n (parse "1::8000:0:0:0-1::ffff:ffff:ffff:ffff"))) [
      0
      (-1)
      9223372036854775807
      (-9223372036854775807 - 1)
    ];
    expected = [
      "1::8000:0:0:0"
      "1::ffff:ffff:ffff:ffff"
      "1::ffff:ffff:ffff:ffff"
      "1::8000:0:0:0"
    ];
  };
  # Nearly 2^128 addresses: positive indexes count from `from` and
  # negative ones back from `to`.
  testAddressAtV6Huge = {
    expr =
      map (n: ipv6.toString (ipRange.addressAt n (parse "::5-ffff:ffff:ffff:ffff:ffff:ffff:ffff:fffe")))
        [
          1
          (-1)
          (-2)
          (-9223372036854775807 - 1)
        ];
    expected = [
      "::6"
      "ffff:ffff:ffff:ffff:ffff:ffff:ffff:fffe"
      "ffff:ffff:ffff:ffff:ffff:ffff:ffff:fffd"
      "ffff:ffff:ffff:ffff:7fff:ffff:ffff:ffff"
    ];
  };
  testAddressAtV6Below2To63Ends = {
    expr = map (n: ipv6.toString (ipRange.addressAt n (parse "::-::7fff:ffff:ffff:fffe"))) [
      0
      (-1)
      9223372036854775806
    ];
    expected = [
      "::"
      "::7fff:ffff:ffff:fffe"
      "::7fff:ffff:ffff:fffe"
    ];
  };

  # ===== toCidrs =====
  testToCidrsAligned = {
    expr = map cidr.toString (ipRange.toCidrs (parse "10.0.0.0-10.0.0.255"));
    expected = [ "10.0.0.0/24" ];
  };
  testToCidrsUnaligned = {
    expr = map cidr.toString (ipRange.toCidrs (parse "10.0.0.1-10.0.0.6"));
    expected = [
      "10.0.0.1/32"
      "10.0.0.2/31"
      "10.0.0.4/31"
      "10.0.0.6/32"
    ];
  };
  testToCidrsSingle = {
    expr = map cidr.toString (ipRange.toCidrs (parse "1.2.3.4-1.2.3.4"));
    expected = [ "1.2.3.4/32" ];
  };
  testToCidrsV6 = {
    expr = map cidr.toString (ipRange.toCidrs (parse "2001:db8::-2001:db8::ff"));
    expected = [ "2001:db8::/120" ];
  };
  testToCidrsAtMax = {
    expr = map cidr.toString (ipRange.toCidrs (parse "255.255.255.254-255.255.255.255"));
    expected = [ "255.255.255.254/31" ];
  };

  testFromCidrV4 = {
    expr = ipRange.toString (ipRange.fromCidr (cidr.parse "10.0.0.0/24"));
    expected = "10.0.0.0-10.0.0.255";
  };
  testFromCidrV6 = {
    expr = ipRange.toString (ipRange.fromCidr (cidr.parse "2001:db8::/120"));
    expected = "2001:db8::-2001:db8::ff";
  };

  # ===== isValid / make / fromAddress / version / accessors =====
  testIsValidOk = {
    expr = ipRange.isValid "1.2.3.4-1.2.3.10";
    expected = true;
  };
  testIsValidBad = {
    expr = ipRange.isValid "nope";
    expected = false;
  };
  testMakeOk = {
    expr = ipRange.toString (ipRange.make (ipv4.parse "1.2.3.4") (ipv4.parse "1.2.3.10"));
    expected = "1.2.3.4-1.2.3.10";
  };
  testMakeReversed = {
    expr = ipRange.make (ipv4.parse "1.2.3.10") (ipv4.parse "1.2.3.4");
    expectedError.msg = "^libnet\\.ipRange\\.make: from > to: 1\\.2\\.3\\.10-1\\.2\\.3\\.4$";
  };
  testMakeMixed = {
    expr = ipRange.make (ipv4.parse "1.2.3.4") (ipv6.parse "::1");
    expectedError.msg = "^libnet\\.ipRange\\.make: mixed families$";
  };
  testMakeRejectsCidr = {
    expr = ipRange.make (cidr.parse "1.2.3.0/24") (ipv4.parse "1.2.3.4");
    expectedError.msg = "^libnet\\.ipRange\\.make: expected ipv4 or ipv6 value, got cidr value$";
  };
  testMakeRejectsStringTo = {
    expr = ipRange.make (ipv4.parse "1.2.3.4") "1.2.3.5";
    expectedError.msg = "^libnet\\.ipRange\\.make: expected ipv4 or ipv6 value, got string$";
  };
  testFromAddressOk = {
    expr = ipRange.toString (ipRange.fromAddress (ipv4.parse "1.2.3.4"));
    expected = "1.2.3.4-1.2.3.4";
  };
  testFromAddressBad = {
    expr = ipRange.fromAddress "1.2.3.4";
    expectedError.msg = "^libnet\\.ipRange\\.fromAddress: expected ipv4 or ipv6 value, got string$";
  };
  testVersionV4 = {
    expr = ipRange.version (parse "1.2.3.4-1.2.3.10");
    expected = 4;
  };
  testVersionV6 = {
    expr = ipRange.version (parse "::1-::ff");
    expected = 6;
  };
  testFromAccessor = {
    expr = ipv4.toString (ipRange.from (parse "1.2.3.4-1.2.3.10"));
    expected = "1.2.3.4";
  };
  testToAccessor = {
    expr = ipv4.toString (ipRange.to (parse "1.2.3.4-1.2.3.10"));
    expected = "1.2.3.10";
  };
  testIsAdjacentYes = {
    expr = ipRange.isAdjacent (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.11-1.2.3.15");
    expected = true;
  };
  testIsAdjacentReversed = {
    expr = ipRange.isAdjacent (parse "1.2.3.11-1.2.3.15") (parse "1.2.3.4-1.2.3.10");
    expected = true;
  };
  testIsAdjacentGap = {
    expr = ipRange.isAdjacent (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.12-1.2.3.15");
    expected = false;
  };
  testIsAdjacentOverlap = {
    expr = ipRange.isAdjacent (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.8-1.2.3.15");
    expected = false;
  };
  testIsAdjacentCrossFamily = {
    expr = ipRange.isAdjacent (parse "1.2.3.4-1.2.3.10") (parse "::1-::ff");
    expected = false;
  };
  testIsAdjacentAtMax = {
    expr = ipRange.isAdjacent (parse "255.255.255.254-255.255.255.255") (
      parse "255.255.255.252-255.255.255.253"
    );
    expected = true;
  };
  testIsAdjacentAtMaxReversed = {
    expr = ipRange.isAdjacent (parse "255.255.255.252-255.255.255.253") (
      parse "255.255.255.254-255.255.255.255"
    );
    expected = true;
  };
  # The top address has no upward neighbour; it does not wrap to zero.
  testIsAdjacentTopDoesNotWrap = {
    expr = map (pair: ipRange.isAdjacent (parse pair.a) (parse pair.b)) [
      {
        a = "255.255.255.255-255.255.255.255";
        b = "0.0.0.0-0.0.0.1";
      }
      {
        a = "::-::1";
        b = "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff";
      }
    ];
    expected = [
      false
      false
    ];
  };
  testIsAdjacentAtMaxV6 = {
    expr = ipRange.isAdjacent (parse "ffff:ffff:ffff:ffff:ffff:ffff:ffff:fffe-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff") (
      parse "ffff:ffff:ffff:ffff:ffff:ffff:ffff:fffc-ffff:ffff:ffff:ffff:ffff:ffff:ffff:fffd"
    );
    expected = true;
  };
  testAddressesUnboundedLength = {
    expr = builtins.length (ipRange.addressesUnbounded (parse "1.0.0.0-1.0.255.255"));
    expected = 65536;
  };
  testAddressesUnboundedV6 = {
    expr = map ipv6.toString (ipRange.addressesUnbounded (parse "::1-::3"));
    expected = [
      "::1"
      "::2"
      "::3"
    ];
  };

  # ===== Comparison helpers =====
  testLt = {
    expr = ipRange.lt (parse "1.0.0.0-1.0.0.10") (parse "2.0.0.0-2.0.0.10");
    expected = true;
  };
  testLe = {
    expr = ipRange.le (parse "1.0.0.0-1.0.0.10") (parse "2.0.0.0-2.0.0.10");
    expected = true;
  };
  testGt = {
    expr = ipRange.gt (parse "2.0.0.0-2.0.0.10") (parse "1.0.0.0-1.0.0.10");
    expected = true;
  };
  testGe = {
    expr = ipRange.ge (parse "2.0.0.0-2.0.0.10") (parse "1.0.0.0-1.0.0.10");
    expected = true;
  };
  testMin = {
    expr = ipRange.toString (ipRange.min (parse "1.0.0.0-1.0.0.10") (parse "2.0.0.0-2.0.0.10"));
    expected = "1.0.0.0-1.0.0.10";
  };
  testMax = {
    expr = ipRange.toString (ipRange.max (parse "1.0.0.0-1.0.0.10") (parse "2.0.0.0-2.0.0.10"));
    expected = "2.0.0.0-2.0.0.10";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = ipRange.eq (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.4-1.2.3.10");
    expected = true;
  };
  testEqDifferent = {
    expr = ipRange.eq (parse "1.2.3.4-1.2.3.10") (parse "1.2.3.4-1.2.3.11");
    expected = false;
  };
  testCompareLt = {
    expr = ipRange.compare (parse "1.0.0.0-1.0.0.10") (parse "2.0.0.0-2.0.0.10");
    expected = -1;
  };
  testCompareV4V6 = {
    expr = ipRange.compare (parse "1.2.3.4-1.2.3.10") (parse "::1-::ff");
    expected = -1;
  };
  testCompareV6V4 = {
    expr = ipRange.compare (parse "::1-::ff") (parse "1.2.3.4-1.2.3.10");
    expected = 1;
  };
  testCompareRejectsAddress = {
    expr = ipRange.compare (parse "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.4");
    expectedError.msg = "^libnet\\.ipRange\\.compare: expected ipRange value, got ipv4 value$";
  };
  testMaxRejectsPortRange = {
    expr = ipRange.max (libnet.portRange.parse "80-90") (parse "1.2.3.4-1.2.3.10");
    expectedError.msg = "^libnet\\.ipRange\\.max: expected ipRange value, got portRange value$";
  };
  testMergeRejectsCidr = {
    expr = ipRange.merge (parse "1.2.3.4-1.2.3.10") (cidr.parse "1.2.3.0/24");
    expectedError.msg = "^libnet\\.ipRange\\.merge: expected ipRange value, got cidr value$";
  };
  testIsSuperrangeOfNamesItself = {
    expr = ipRange.isSuperrangeOf (parse "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.5");
    expectedError.msg = "^libnet\\.ipRange\\.isSuperrangeOf: expected ipRange value, got ipv4 value$";
  };
  testToCidrsRejectsCidr = {
    expr = ipRange.toCidrs (cidr.parse "10.0.0.0/24");
    expectedError.msg = "^libnet\\.ipRange\\.toCidrs: expected ipRange value, got cidr value$";
  };
  testFromCidrRejectsRange = {
    expr = ipRange.fromCidr (parse "10.0.0.0-10.0.0.255");
    expectedError.msg = "^libnet\\.ipRange\\.fromCidr: expected cidr value, got ipRange value$";
  };
  # The address's failure keeps its detail under ipRange.parse alone.
  testParseBadAddressNamesIpRangeParseOnce = {
    expr =
      let
        inherit (ipRange.tryParse "300.0.0.0-1.2.3.4") error;
      in
      [
        (builtins.match "libnet[.]ipRange[.]parse: .*" error != null)
        (builtins.match ".*libnet[.]ipv4.*" error == null)
      ];
    expected = [
      true
      true
    ];
  };
}
