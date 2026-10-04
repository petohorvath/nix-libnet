{ harness }:
let
  ipRange = import ../lib/ip-range.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  cidr = import ../lib/cidr.nix;
  inherit (harness) throws;
  parse = ipRange.parse;
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
    expr = throws (ipRange.size (parse "::-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"));
    expected = true;
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
    expr = throws (ipRange.addresses (parse "1.0.0.0-2.0.0.0"));
    expected = true;
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
    expr = throws (ipRange.addressAt 3 (parse "1.2.3.4-1.2.3.6"));
    expected = true;
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
    expr = throws (ipRange.make (ipv4.parse "1.2.3.10") (ipv4.parse "1.2.3.4"));
    expected = true;
  };
  testMakeMixed = {
    expr = throws (ipRange.make (ipv4.parse "1.2.3.4") (ipv6.parse "::1"));
    expected = true;
  };
  testFromAddressOk = {
    expr = ipRange.toString (ipRange.fromAddress (ipv4.parse "1.2.3.4"));
    expected = "1.2.3.4-1.2.3.4";
  };
  testFromAddressBad = {
    expr = throws (ipRange.fromAddress "1.2.3.4");
    expected = true;
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
    expr = ipRange.isAdjacent (parse "255.255.255.254-255.255.255.255") (parse "1.0.0.0-2.0.0.0");
    expected = false;
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
}
