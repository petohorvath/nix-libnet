{ harness }:
let
  portRange = import ../lib/port-range.nix;
  port = import ../lib/port.nix;
  inherit (harness) throws;
  parse = portRange.parse;
in
{
  # ===== Parse =====
  testParseSingle = {
    expr = portRange.toString (parse "8080");
    expected = "8080";
  };
  testParseHyphen = {
    expr = portRange.toString (parse "5500-6000");
    expected = "5500-6000";
  };
  testParseColon = {
    expr = portRange.toString (parse "5500:6000");
    expected = "5500-6000";
  }; # canonical is hyphen
  testParseEqualBounds = {
    expr = portRange.toString (parse "80-80");
    expected = "80";
  }; # singleton canonical

  testRejectReversed = {
    expr = throws (parse "6000-5500");
    expected = true;
  };
  testRejectNegative = {
    expr = throws (parse "-1-10");
    expected = true;
  };
  testRejectAboveMax = {
    expr = throws (parse "0-65536");
    expected = true;
  };
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };

  # ===== tryParse =====
  testTryParseOk = {
    expr = (portRange.tryParse "80-90").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (portRange.tryParse "nope").success;
    expected = false;
  };

  # ===== Formatting =====
  testToStringColon = {
    expr = portRange.toStringColon (parse "5500-6000");
    expected = "5500:6000";
  };
  testToStringColonSingle = {
    expr = portRange.toStringColon (parse "80");
    expected = "80";
  };

  # ===== make / fromPort =====
  testMakeOk = {
    expr = portRange.toString (portRange.make 100 200);
    expected = "100-200";
  };
  testMakeSingle = {
    expr = portRange.toString (portRange.make 80 80);
    expected = "80";
  };
  testMakeReversed = {
    expr = throws (portRange.make 200 100);
    expected = true;
  };
  testMakeAboveMax = {
    expr = throws (portRange.make 0 65536);
    expected = true;
  };
  testMakeNonInt = {
    expr = throws (portRange.make "80" 100);
    expected = true;
  };
  testFromPortOk = {
    expr = portRange.toString (portRange.fromPort (port.fromInt 80));
    expected = "80";
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = portRange.is (parse "80");
    expected = true;
  };
  testIsString = {
    expr = portRange.is "80";
    expected = false;
  };
  testIsValidOk = {
    expr = portRange.isValid "80-90";
    expected = true;
  };
  testIsSingletonYes = {
    expr = portRange.isSingleton (parse "80");
    expected = true;
  };
  testIsSingletonNo = {
    expr = portRange.isSingleton (parse "80-90");
    expected = false;
  };

  # ===== Accessors =====
  testFromValue = {
    expr = portRange.from (parse "80-90");
    expected = port.fromInt 80;
  };
  testToValue = {
    expr = portRange.to (parse "80-90");
    expected = port.fromInt 90;
  };
  testFromIsPort = {
    expr = port.is (portRange.from (parse "80-90"));
    expected = true;
  };
  testToIsPort = {
    expr = port.is (portRange.to (parse "80-90"));
    expected = true;
  };
  testSizeSingle = {
    expr = portRange.size (parse "80");
    expected = 1;
  };
  testSizeRange = {
    expr = portRange.size (parse "80-90");
    expected = 11;
  };
  testSizeFull = {
    expr = portRange.size (parse "0-65535");
    expected = 65536;
  };

  # ===== Containment =====
  testContainsInside = {
    expr = portRange.contains (parse "80-90") (port.fromInt 85);
    expected = true;
  };
  testContainsFrom = {
    expr = portRange.contains (parse "80-90") (port.fromInt 80);
    expected = true;
  };
  testContainsTo = {
    expr = portRange.contains (parse "80-90") (port.fromInt 90);
    expected = true;
  };
  testContainsOutside = {
    expr = portRange.contains (parse "80-90") (port.fromInt 91);
    expected = false;
  };
  testContainsNonPort = {
    expr = portRange.contains (parse "80-90") 85;
    expected = false;
  };
  testOverlapsYes = {
    expr = portRange.overlaps (parse "80-90") (parse "85-95");
    expected = true;
  };
  testOverlapsTouch = {
    expr = portRange.overlaps (parse "80-90") (parse "90-100");
    expected = true;
  };
  testOverlapsNo = {
    expr = portRange.overlaps (parse "80-90") (parse "91-100");
    expected = false;
  };
  testSubrangeYes = {
    expr = portRange.isSubrangeOf (parse "82-88") (parse "80-90");
    expected = true;
  };
  testSubrangeNo = {
    expr = portRange.isSubrangeOf (parse "80-90") (parse "82-88");
    expected = false;
  };
  testSuperrangeYes = {
    expr = portRange.isSuperrangeOf (parse "80-90") (parse "82-88");
    expected = true;
  };

  # ===== isAdjacent =====
  testAdjacentYes = {
    expr = portRange.isAdjacent (parse "80-90") (parse "91-100");
    expected = true;
  };
  testAdjacentReversed = {
    expr = portRange.isAdjacent (parse "91-100") (parse "80-90");
    expected = true;
  };
  testAdjacentGap = {
    expr = portRange.isAdjacent (parse "80-90") (parse "92-100");
    expected = false;
  };
  testAdjacentOverlap = {
    expr = portRange.isAdjacent (parse "80-90") (parse "85-95");
    expected = false;
  };
  testAdjacentSingletons = {
    expr = portRange.isAdjacent (parse "80") (parse "81");
    expected = true;
  };
  testAdjacentAtMax = {
    expr = portRange.isAdjacent (parse "0-65534") (parse "65535");
    expected = true;
  };

  # ===== Merge =====
  testMergeAdjacent = {
    expr = portRange.toString (portRange.merge (parse "80-90") (parse "91-100"));
    expected = "80-100";
  };
  testMergeOverlap = {
    expr = portRange.toString (portRange.merge (parse "80-90") (parse "85-100"));
    expected = "80-100";
  };
  testMergeContained = {
    expr = portRange.toString (portRange.merge (parse "80-100") (parse "85-90"));
    expected = "80-100";
  };
  testMergeDisjoint = {
    expr = portRange.merge (parse "80-90") (parse "100-110");
    expected = null;
  };

  # ===== Enumeration =====
  testPortsSmall = {
    expr = map port.toInt (portRange.ports (parse "80-83"));
    expected = [
      80
      81
      82
      83
    ];
  };
  testPortsSingle = {
    expr = map port.toInt (portRange.ports (parse "80"));
    expected = [ 80 ];
  };
  testPorts4096Ok = {
    expr = builtins.length (portRange.ports (parse "0-4095"));
    expected = 4096;
  };
  testPorts4097Throws = {
    expr = throws (portRange.ports (parse "0-4096"));
    expected = true;
  };
  testPortsUnbounded = {
    expr = builtins.length (portRange.portsUnbounded (parse "0-4096"));
    expected = 4097;
  };
  testPortAtFirst = {
    expr = port.toInt (portRange.portAt 0 (parse "80-83"));
    expected = 80;
  };
  testPortAtMid = {
    expr = port.toInt (portRange.portAt 2 (parse "80-83"));
    expected = 82;
  };
  testPortAtNegative = {
    expr = port.toInt (portRange.portAt (-1) (parse "80-83"));
    expected = 83;
  };
  testPortAtOutOfBounds = {
    expr = throws (portRange.portAt 4 (parse "80-83"));
    expected = true;
  };

  # ===== Comparison helpers =====
  testLt = {
    expr = portRange.lt (parse "80-90") (parse "80-100");
    expected = true;
  };
  testLe = {
    expr = portRange.le (parse "80-90") (parse "80-100");
    expected = true;
  };
  testGt = {
    expr = portRange.gt (parse "80-100") (parse "80-90");
    expected = true;
  };
  testGe = {
    expr = portRange.ge (parse "80-100") (parse "80-90");
    expected = true;
  };
  testMin = {
    expr = portRange.toString (portRange.min (parse "80-90") (parse "80-100"));
    expected = "80-90";
  };
  testMax = {
    expr = portRange.toString (portRange.max (parse "80-90") (parse "80-100"));
    expected = "80-100";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = portRange.eq (parse "80-90") (parse "80-90");
    expected = true;
  };
  testEqDifferent = {
    expr = portRange.eq (parse "80-90") (parse "80-91");
    expected = false;
  };
  testCompareOrdersByFrom = {
    expr = portRange.compare (parse "80-100") (parse "81-82");
    expected = -1;
  };
  testCompareTieBreaksOnTo = {
    expr = portRange.compare (parse "80-90") (parse "80-100");
    expected = -1;
  };
  testCompareEq = {
    expr = portRange.compare (parse "80-90") (parse "80-90");
    expected = 0;
  };
}
