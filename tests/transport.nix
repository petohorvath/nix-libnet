{ harness }:
let
  transport = import ../lib/transport.nix;
  inherit (harness) throws;
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
  testValuesList = {
    expr = transport.values;
    expected = [
      "tcp"
      "udp"
      "sctp"
    ];
  };
}
