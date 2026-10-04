{ harness }:
let
  bindpoint = import ../lib/bindpoint.nix;
  ipBindpoint = import ../lib/ip-bindpoint.nix;
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
  parse = bindpoint.parse;
in
{
  # ===== Dispatch =====
  testParseIpTagged = {
    expr = (parse "0.0.0.0:8080")._type;
    expected = "ipBindpoint";
  };
  testParseWildcardTagged = {
    expr = (parse ":8080")._type;
    expected = "ipBindpoint";
  };
  testParseRangeTagged = {
    expr = (parse "1.2.3.4:8000-8100")._type;
    expected = "ipBindpoint";
  };
  testParseUnixTagged = {
    expr = (parse "/run/foo.sock")._type;
    expected = "unixSocket";
  };
  testParseUnixAbstract = {
    expr = (parse "@foo")._type;
    expected = "unixSocket";
  };
  testParseIpRoundTrip = {
    expr = bindpoint.toString (parse "1.2.3.4:8000-8100");
    expected = "1.2.3.4:8000-8100";
  };
  testParseUnixRoundTrip = {
    expr = bindpoint.toString (parse "/run/foo.sock");
    expected = "/run/foo.sock";
  };

  # ===== Reject =====
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectBadPort = {
    expr = throws (parse ":99999");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (bindpoint.parse 42);
    expected = true;
  };

  testTryParseOkIp = {
    expr = (bindpoint.tryParse ":80").success;
    expected = true;
  };
  testTryParseOkUnix = {
    expr = (bindpoint.tryParse "/run/foo.sock").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (bindpoint.tryParse "host_name:1").success;
    expected = false;
  };

  # ===== Predicates =====
  testIsIp = {
    expr = bindpoint.is (parse ":8080");
    expected = true;
  };
  testIsUnix = {
    expr = bindpoint.is (parse "/run/foo.sock");
    expected = true;
  };
  testIsString = {
    expr = bindpoint.is ":8080";
    expected = false;
  };
  testIsIpBindpointYes = {
    expr = bindpoint.isIpBindpoint (parse ":8080");
    expected = true;
  };
  testIsIpBindpointNo = {
    expr = bindpoint.isIpBindpoint (parse "/run/foo.sock");
    expected = false;
  };
  testIsUnixSocketYes = {
    expr = bindpoint.isUnixSocket (parse "/run/foo.sock");
    expected = true;
  };
  testIsUnixSocketNo = {
    expr = bindpoint.isUnixSocket (parse ":8080");
    expected = false;
  };
  testIsValidIp = {
    expr = bindpoint.isValid ":8080";
    expected = true;
  };
  testIsValidUnix = {
    expr = bindpoint.isValid "/run/foo.sock";
    expected = true;
  };
  testIsValidBad = {
    expr = bindpoint.isValid "host_name:1";
    expected = false;
  };

  # ===== Comparison helpers =====
  testCompareLt = {
    expr = bindpoint.lt (parse ":8080") (parse ":8081");
    expected = true;
  };
  testCompareLe = {
    expr = bindpoint.le (parse ":8080") (parse ":8081");
    expected = true;
  };
  testCompareGt = {
    expr = bindpoint.gt (parse ":8081") (parse ":8080");
    expected = true;
  };
  testCompareGe = {
    expr = bindpoint.ge (parse ":8081") (parse ":8080");
    expected = true;
  };
  testCompareMax = {
    expr = bindpoint.toString (bindpoint.max (parse ":8080") (parse ":8081"));
    expected = ":8081";
  };

  # ===== Comparison =====
  testEqSameIp = {
    expr = bindpoint.eq (parse ":8080") (parse ":8080");
    expected = true;
  };
  testEqSameUnix = {
    expr = bindpoint.eq (parse "/run/foo.sock") (parse "/run/foo.sock");
    expected = true;
  };
  testEqCrossKind = {
    expr = bindpoint.eq (parse ":8080") (parse "/run/foo.sock");
    expected = false;
  };
  testCompareIpBeforeUnix = {
    expr = bindpoint.compare (parse ":8080") (parse "/run/foo.sock");
    expected = -1;
  };
  testCompareUnixAfterIp = {
    expr = bindpoint.compare (parse "/run/foo.sock") (parse ":8080");
    expected = 1;
  };
  testMinPicksIp = {
    expr = (bindpoint.min (parse "/run/foo.sock") (parse ":8080"))._type;
    expected = "ipBindpoint";
  };

  # Sanity: union recognises values from each member module
  testIsFromIpModule = {
    expr = bindpoint.is (ipBindpoint.parse ":8080");
    expected = true;
  };
  testIsFromUnixModule = {
    expr = bindpoint.is (unixSocket.parse "/run/foo.sock");
    expected = true;
  };
}
