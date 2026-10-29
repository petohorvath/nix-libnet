{ helpers, libnet, ... }:
let
  inherit (libnet) transport;
  inherit (helpers) throws;
  inherit (transport) parse;
in
{
  # ===== Parse =====
  testParseTcp = {
    expr = (parse "tcp").value;
    expected = "tcp";
  };
  testParseUdp = {
    expr = (parse "udp").value;
    expected = "udp";
  };
  testParseSctp = {
    expr = (parse "sctp").value;
    expected = "sctp";
  };
  testParseTagged = {
    expr = (parse "tcp")._type;
    expected = "transport";
  };

  testRejectUppercase = {
    expr = throws (parse "TCP");
    expected = true;
  };
  testRejectMixedCase = {
    expr = throws (parse "Tcp");
    expected = true;
  };
  testRejectUnknown = {
    expr = throws (parse "icmp");
    expected = true;
  };
  testRejectQuic = {
    expr = throws (parse "quic");
    expected = true;
  };
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectWhitespace = {
    expr = throws (parse " tcp");
    expected = true;
  };
  testRejectTrailing = {
    expr = throws (parse "tcp ");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (transport.parse 6);
    expected = true;
  };

  testTryParseOk = {
    expr = (transport.tryParse "tcp").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (transport.tryParse "icmp").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = builtins.isString (transport.tryParse "icmp").error;
    expected = true;
  };
  testTryParseNotString = {
    expr = (transport.tryParse 6).success;
    expected = false;
  };
  testTryParseNotStringError = {
    expr = (transport.tryParse 6).error;
    expected = "libnet.transport.parse: expected string, got int";
  };
  testParseNotStringNamesParse = {
    expr = transport.parse { };
    expectedError.msg = "^libnet\\.transport\\.parse: expected string, got set$";
  };
  testParseUnknownNamesParse = {
    expr = transport.parse "TCP";
    expectedError.msg = "^libnet\\.transport\\.parse: unknown protocol \"TCP\"";
  };
  testToStringWrongKind = {
    expr = transport.toString (libnet.port.fromInt 80);
    expectedError.msg = "^libnet\\.transport\\.toString: expected transport value, got port value$";
  };
  testIsTcpWrongKind = {
    expr = transport.isTcp "tcp";
    expectedError.msg = "^libnet\\.transport\\.isTcp: expected transport value, got string$";
  };
  testLtNamesLt = {
    expr = transport.lt transport.tcp 6;
    expectedError.msg = "^libnet\\.transport\\.lt: expected transport value, got int$";
  };

  # ===== Round-trip =====
  testRoundTripTcp = {
    expr = transport.toString (parse "tcp");
    expected = "tcp";
  };
  testRoundTripUdp = {
    expr = transport.toString (parse "udp");
    expected = "udp";
  };
  testRoundTripSctp = {
    expr = transport.toString (parse "sctp");
    expected = "sctp";
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = transport.is (parse "tcp");
    expected = true;
  };
  testIsString = {
    expr = transport.is "tcp";
    expected = false;
  };
  testIsUntagged = {
    expr = transport.is { value = "tcp"; };
    expected = false;
  };
  testIsValidTcp = {
    expr = transport.isValid "tcp";
    expected = true;
  };
  testIsValidUdp = {
    expr = transport.isValid "udp";
    expected = true;
  };
  testIsValidSctp = {
    expr = transport.isValid "sctp";
    expected = true;
  };
  testIsValidBad = {
    expr = transport.isValid "icmp";
    expected = false;
  };
  testIsValidNotString = {
    expr = transport.isValid 6;
    expected = false;
  };

  testIsTcpTcp = {
    expr = transport.isTcp (parse "tcp");
    expected = true;
  };
  testIsTcpUdp = {
    expr = transport.isTcp (parse "udp");
    expected = false;
  };
  testIsTcpSctp = {
    expr = transport.isTcp (parse "sctp");
    expected = false;
  };
  testIsUdpUdp = {
    expr = transport.isUdp (parse "udp");
    expected = true;
  };
  testIsUdpTcp = {
    expr = transport.isUdp (parse "tcp");
    expected = false;
  };
  testIsUdpSctp = {
    expr = transport.isUdp (parse "sctp");
    expected = false;
  };
  testIsSctpSctp = {
    expr = transport.isSctp (parse "sctp");
    expected = true;
  };
  testIsSctpTcp = {
    expr = transport.isSctp (parse "tcp");
    expected = false;
  };
  testIsSctpUdp = {
    expr = transport.isSctp (parse "udp");
    expected = false;
  };

  # ===== Equality =====
  testEqSameTcp = {
    expr = transport.eq (parse "tcp") (parse "tcp");
    expected = true;
  };
  testEqSameUdp = {
    expr = transport.eq (parse "udp") (parse "udp");
    expected = true;
  };
  testEqTcpUdp = {
    expr = transport.eq (parse "tcp") (parse "udp");
    expected = false;
  };
  testEqTcpSctp = {
    expr = transport.eq (parse "tcp") (parse "sctp");
    expected = false;
  };

  # ===== Ordering (by name: sctp < tcp < udp) =====
  testCompareSctpTcp = {
    expr = transport.compare (parse "sctp") (parse "tcp");
    expected = -1;
  };
  testCompareTcpUdp = {
    expr = transport.compare (parse "tcp") (parse "udp");
    expected = -1;
  };
  testCompareUdpSctp = {
    expr = transport.compare (parse "udp") (parse "sctp");
    expected = 1;
  };
  testCompareSame = {
    expr = transport.compare (parse "tcp") (parse "tcp");
    expected = 0;
  };
  testLt = {
    expr = transport.lt (parse "sctp") (parse "udp");
    expected = true;
  };
  testLtSame = {
    expr = transport.lt (parse "tcp") (parse "tcp");
    expected = false;
  };
  testLe = {
    expr = transport.le (parse "tcp") (parse "tcp");
    expected = true;
  };
  testGt = {
    expr = transport.gt (parse "udp") (parse "tcp");
    expected = true;
  };
  testGe = {
    expr = transport.ge (parse "sctp") (parse "tcp");
    expected = false;
  };
  testMin = {
    expr = transport.toString (transport.min (parse "udp") (parse "sctp"));
    expected = "sctp";
  };
  testMax = {
    expr = transport.toString (transport.max (parse "udp") (parse "sctp"));
    expected = "udp";
  };
  testSortByCompare = {
    expr = map transport.toString (
      builtins.sort transport.lt [
        transport.udp
        transport.tcp
        transport.sctp
      ]
    );
    expected = [
      "sctp"
      "tcp"
      "udp"
    ];
  };

  # ===== Constants =====
  testConstantTcp = {
    expr = transport.eq transport.tcp (parse "tcp");
    expected = true;
  };
  testConstantUdp = {
    expr = transport.eq transport.udp (parse "udp");
    expected = true;
  };
  testConstantSctp = {
    expr = transport.eq transport.sctp (parse "sctp");
    expected = true;
  };
  testConstantTcpTagged = {
    expr = transport.is transport.tcp;
    expected = true;
  };
  testValuesSortedTransports = {
    expr = transport.values;
    expected = [
      transport.sctp
      transport.tcp
      transport.udp
    ];
  };
  testValuesTagged = {
    expr = builtins.all transport.is transport.values;
    expected = true;
  };
}
