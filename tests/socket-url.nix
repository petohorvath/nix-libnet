{ harness }:
let
  socketUrl = import ../lib/socket-url.nix;
  transport = import ../lib/transport.nix;
  endpoint = import ../lib/endpoint.nix;
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
  inherit (socketUrl) parse;
in
{
  # ===== Parse: IP schemes =====
  testParseTcpIpv4 = {
    expr = socketUrl.toString (parse "tcp://1.2.3.4:80");
    expected = "tcp://1.2.3.4:80";
  };
  testParseUdpIpv6 = {
    expr = socketUrl.toString (parse "udp://[::1]:53");
    expected = "udp://[::1]:53";
  };
  testParseSctpDns = {
    expr = socketUrl.toString (parse "sctp://pool.ntp.org:9999");
    expected = "sctp://pool.ntp.org:9999";
  };
  testParseTagged = {
    expr = (parse "tcp://1.2.3.4:80")._type;
    expected = "socketUrl";
  };
  testParseTransport = {
    expr = transport.toString (socketUrl.transport (parse "tcp://1.2.3.4:80"));
    expected = "tcp";
  };
  testParseEndpointKind = {
    expr = (socketUrl.endpoint (parse "tcp://1.2.3.4:80"))._type;
    expected = "ipEndpoint";
  };
  testParseDnsEndpointKind = {
    expr = (socketUrl.endpoint (parse "tcp://pool.ntp.org:123"))._type;
    expected = "dnsEndpoint";
  };

  # ===== Parse: unix scheme =====
  testParseUnixPathname = {
    expr = socketUrl.toString (parse "unix:///run/foo.sock");
    expected = "unix:///run/foo.sock";
  };
  testParseUnixAbstract = {
    expr = socketUrl.toString (parse "unix://@foo");
    expected = "unix://@foo";
  };
  testParseUnixTransportNull = {
    expr = socketUrl.transport (parse "unix:///run/foo.sock");
    expected = null;
  };
  testParseUnixEndpointKind = {
    expr = (socketUrl.endpoint (parse "unix:///run/foo.sock"))._type;
    expected = "unixSocket";
  };

  # ===== Reject =====
  testRejectNoScheme = {
    expr = throws (parse "1.2.3.4:80");
    expected = true;
  };
  testRejectUnknownScheme = {
    expr = throws (parse "http://1.2.3.4:80");
    expected = true;
  };
  testRejectIcmpScheme = {
    expr = throws (parse "icmp://1.2.3.4:80");
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
  testRejectBadEndpoint = {
    expr = throws (parse "tcp://host_name:1");
    expected = true;
  };
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (socketUrl.parse 42);
    expected = true;
  };

  testTryParseOk = {
    expr = (socketUrl.tryParse "tcp://1.2.3.4:80").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (socketUrl.tryParse "1.2.3.4:80").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = builtins.isString (socketUrl.tryParse "http://x:1").error;
    expected = true;
  };

  # ===== make =====
  testMakeIp = {
    expr = socketUrl.toString (socketUrl.make (transport.parse "tcp") (endpoint.parse "1.2.3.4:80"));
    expected = "tcp://1.2.3.4:80";
  };
  testMakeUnix = {
    expr = socketUrl.toString (socketUrl.make null (unixSocket.parse "/run/foo.sock"));
    expected = "unix:///run/foo.sock";
  };
  testMakeUnixWithTransportThrows = {
    expr = throws (socketUrl.make (transport.parse "tcp") (unixSocket.parse "/run/foo.sock"));
    expected = true;
  };
  testMakeIpWithoutTransportThrows = {
    expr = throws (socketUrl.make null (endpoint.parse "1.2.3.4:80"));
    expected = true;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = socketUrl.is (parse "tcp://1.2.3.4:80");
    expected = true;
  };
  testIsString = {
    expr = socketUrl.is "tcp://1.2.3.4:80";
    expected = false;
  };
  testIsValidIp = {
    expr = socketUrl.isValid "udp://[::]:53";
    expected = true;
  };
  testIsValidUnix = {
    expr = socketUrl.isValid "unix:///run/foo.sock";
    expected = true;
  };
  testIsValidBad = {
    expr = socketUrl.isValid "ftp://x:1";
    expected = false;
  };
  testIsUnixYes = {
    expr = socketUrl.isUnix (parse "unix:///run/foo.sock");
    expected = true;
  };
  testIsUnixNo = {
    expr = socketUrl.isUnix (parse "tcp://1.2.3.4:80");
    expected = false;
  };

  # ===== Comparison helpers =====
  testLtBefore = {
    expr = socketUrl.lt (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81");
    expected = true;
  };
  testLeBefore = {
    expr = socketUrl.le (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81");
    expected = true;
  };
  testGtAfter = {
    expr = socketUrl.gt (parse "tcp://1.2.3.4:81") (parse "tcp://1.2.3.4:80");
    expected = true;
  };
  testGeAfter = {
    expr = socketUrl.ge (parse "tcp://1.2.3.4:81") (parse "tcp://1.2.3.4:80");
    expected = true;
  };
  testMinPicksLesser = {
    expr = socketUrl.toString (socketUrl.min (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81"));
    expected = "tcp://1.2.3.4:80";
  };
  testMaxPicksGreater = {
    expr = socketUrl.toString (socketUrl.max (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81"));
    expected = "tcp://1.2.3.4:81";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = socketUrl.eq (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:80");
    expected = true;
  };
  testEqDifferentTransport = {
    expr = socketUrl.eq (parse "tcp://1.2.3.4:80") (parse "udp://1.2.3.4:80");
    expected = false;
  };
  testEqDifferentEndpoint = {
    expr = socketUrl.eq (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81");
    expected = false;
  };
  testEqDnsCaseInsensitive = {
    expr = socketUrl.eq (parse "tcp://Pool.NTP.org:123") (parse "tcp://pool.ntp.org:123");
    expected = true;
  };
  testEqSameUnix = {
    expr = socketUrl.eq (parse "unix:///run/foo.sock") (parse "unix:///run/foo.sock");
    expected = true;
  };
  testEqCrossFamily = {
    expr = socketUrl.eq (parse "tcp://1.2.3.4:80") (parse "unix:///run/foo.sock");
    expected = false;
  };
  testCompareTcpBeforeUdp = {
    expr = socketUrl.compare (parse "tcp://1.2.3.4:80") (parse "udp://1.2.3.4:80");
    expected = -1;
  };
  testCompareIpBeforeUnix = {
    expr = socketUrl.compare (parse "sctp://1.2.3.4:80") (parse "unix:///run/foo.sock");
    expected = -1;
  };
  testCompareWithinTransportByEndpoint = {
    expr = socketUrl.compare (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:81");
    expected = -1;
  };
  testCompareEqual = {
    expr = socketUrl.compare (parse "tcp://1.2.3.4:80") (parse "tcp://1.2.3.4:80");
    expected = 0;
  };

  # ===== Constant =====
  testSchemesList = {
    expr = socketUrl.schemes;
    expected = [
      "tcp"
      "udp"
      "sctp"
      "unix"
    ];
  };
}
