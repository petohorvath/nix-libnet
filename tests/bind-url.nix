{ harness }:
let
  bindUrl = import ../lib/bind-url.nix;
  transport = import ../lib/transport.nix;
  bindpoint = import ../lib/bindpoint.nix;
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
  inherit (bindUrl) parse;
in
{
  # ===== Parse: IP schemes =====
  testParseTcpWildcard = {
    expr = bindUrl.toString (parse "tcp://:8080");
    expected = "tcp://:8080";
  };
  testParseUdpExplicitAny = {
    expr = bindUrl.toString (parse "udp://0.0.0.0:53");
    expected = "udp://0.0.0.0:53";
  };
  testParseTcpV6Range = {
    expr = bindUrl.toString (parse "tcp://[::]:8000-8100");
    expected = "tcp://[::]:8000-8100";
  };
  testParseSctpV4 = {
    expr = bindUrl.toString (parse "sctp://1.2.3.4:80");
    expected = "sctp://1.2.3.4:80";
  };
  testParseWildcardNormalizes = {
    expr = bindUrl.toString (parse "tcp://*:8080");
    expected = "tcp://:8080";
  };
  testParseTagged = {
    expr = (parse "tcp://:8080")._type;
    expected = "bindUrl";
  };
  testParseTransport = {
    expr = transport.toString (bindUrl.transport (parse "tcp://:8080"));
    expected = "tcp";
  };
  testParseBindpointKind = {
    expr = (bindUrl.bindpoint (parse "tcp://:8080"))._type;
    expected = "ipBindpoint";
  };

  # ===== Parse: unix scheme =====
  testParseUnixPathname = {
    expr = bindUrl.toString (parse "unix:///run/foo.sock");
    expected = "unix:///run/foo.sock";
  };
  testParseUnixAbstract = {
    expr = bindUrl.toString (parse "unix://@foo");
    expected = "unix://@foo";
  };
  testParseUnixTransportNull = {
    expr = bindUrl.transport (parse "unix:///run/foo.sock");
    expected = null;
  };
  testParseUnixBindpointKind = {
    expr = (bindUrl.bindpoint (parse "unix:///run/foo.sock"))._type;
    expected = "unixSocket";
  };

  # ===== Reject =====
  testRejectNoScheme = {
    expr = throws (parse ":8080");
    expected = true;
  };
  testRejectUnknownScheme = {
    expr = throws (parse "http://:8080");
    expected = true;
  };
  testRejectTcpPath = {
    expr = throws (parse "tcp:///run/foo.sock");
    expected = true;
  };
  testRejectUnixHostPort = {
    expr = throws (parse "unix://1.2.3.4:80");
    expected = true;
  };
  testRejectBadBindpoint = {
    expr = throws (parse "tcp://:99999");
    expected = true;
  };
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (bindUrl.parse 42);
    expected = true;
  };

  testTryParseOk = {
    expr = (bindUrl.tryParse "tcp://:8080").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (bindUrl.tryParse ":8080").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = builtins.isString (bindUrl.tryParse "http://:8080").error;
    expected = true;
  };

  # ===== make =====
  testMakeIp = {
    expr = bindUrl.toString (bindUrl.make (transport.parse "tcp") (bindpoint.parse ":8080"));
    expected = "tcp://:8080";
  };
  testMakeRange = {
    expr = bindUrl.toString (bindUrl.make (transport.parse "udp") (bindpoint.parse "[::]:8000-8100"));
    expected = "udp://[::]:8000-8100";
  };
  testMakeUnix = {
    expr = bindUrl.toString (bindUrl.make null (unixSocket.parse "/run/foo.sock"));
    expected = "unix:///run/foo.sock";
  };
  testMakeUnixWithTransportThrows = {
    expr = throws (bindUrl.make (transport.parse "tcp") (unixSocket.parse "/run/foo.sock"));
    expected = true;
  };
  testMakeIpWithoutTransportThrows = {
    expr = throws (bindUrl.make null (bindpoint.parse ":8080"));
    expected = true;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = bindUrl.is (parse "tcp://:8080");
    expected = true;
  };
  testIsString = {
    expr = bindUrl.is "tcp://:8080";
    expected = false;
  };
  testIsValidIp = {
    expr = bindUrl.isValid "udp://[::]:53";
    expected = true;
  };
  testIsValidUnix = {
    expr = bindUrl.isValid "unix:///run/foo.sock";
    expected = true;
  };
  testIsValidBad = {
    expr = bindUrl.isValid "ftp://:1";
    expected = false;
  };
  testIsUnixYes = {
    expr = bindUrl.isUnix (parse "unix:///run/foo.sock");
    expected = true;
  };
  testIsUnixNo = {
    expr = bindUrl.isUnix (parse "tcp://:8080");
    expected = false;
  };

  # ===== Comparison helpers =====
  testLtBefore = {
    expr = bindUrl.lt (parse "tcp://:8080") (parse "tcp://:8081");
    expected = true;
  };
  testLeBefore = {
    expr = bindUrl.le (parse "tcp://:8080") (parse "tcp://:8081");
    expected = true;
  };
  testGtAfter = {
    expr = bindUrl.gt (parse "tcp://:8081") (parse "tcp://:8080");
    expected = true;
  };
  testGeAfter = {
    expr = bindUrl.ge (parse "tcp://:8081") (parse "tcp://:8080");
    expected = true;
  };
  testMinPicksLesser = {
    expr = bindUrl.toString (bindUrl.min (parse "tcp://:8080") (parse "tcp://:8081"));
    expected = "tcp://:8080";
  };
  testMaxPicksGreater = {
    expr = bindUrl.toString (bindUrl.max (parse "tcp://:8080") (parse "tcp://:8081"));
    expected = "tcp://:8081";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = bindUrl.eq (parse "tcp://:8080") (parse "tcp://:8080");
    expected = true;
  };
  testEqDifferentTransport = {
    expr = bindUrl.eq (parse "tcp://:8080") (parse "udp://:8080");
    expected = false;
  };
  testEqDifferentBindpoint = {
    expr = bindUrl.eq (parse "tcp://:8080") (parse "tcp://:8081");
    expected = false;
  };
  testEqSameUnix = {
    expr = bindUrl.eq (parse "unix:///run/foo.sock") (parse "unix:///run/foo.sock");
    expected = true;
  };
  testEqCrossFamily = {
    expr = bindUrl.eq (parse "tcp://:8080") (parse "unix:///run/foo.sock");
    expected = false;
  };
  testCompareTcpBeforeUdp = {
    expr = bindUrl.compare (parse "tcp://:8080") (parse "udp://:8080");
    expected = -1;
  };
  testCompareIpBeforeUnix = {
    expr = bindUrl.compare (parse "sctp://:8080") (parse "unix:///run/foo.sock");
    expected = -1;
  };
  testCompareWithinTransportByBindpoint = {
    expr = bindUrl.compare (parse "tcp://:8080") (parse "tcp://:8081");
    expected = -1;
  };
  testCompareEqual = {
    expr = bindUrl.compare (parse "tcp://:8080") (parse "tcp://:8080");
    expected = 0;
  };

  # ===== Constant =====
  testSchemesList = {
    expr = bindUrl.schemes;
    expected = [
      "tcp"
      "udp"
      "sctp"
      "unix"
    ];
  };
}
