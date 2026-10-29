{ helpers, libnet, ... }:
let
  inherit (libnet) bindpoint ipBindpoint unixSocket;
  inherit (helpers) throws;
  inherit (bindpoint) parse;
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
  # A member's failure keeps its detail under the union's name.
  testRejectBadPortNamesUnion = {
    expr = parse ":99999";
    expectedError.msg = "^libnet\\.bindpoint\\.parse: invalid port field \"99999\"$";
  };
  testRejectSlashOnlyNamesUnion = {
    expr = parse "/";
    expectedError.msg = "^libnet\\.bindpoint\\.parse: invalid socket \"/\" ";
  };
  testRejectNameNamesUnion = {
    expr = parse "x";
    expectedError.msg = "^libnet\\.bindpoint\\.parse: missing ':port' in \"x\"$";
  };
  testTryParseBadNamesUnion = {
    expr = (bindpoint.tryParse "localhost:80").error;
    expected = "libnet.bindpoint.parse: invalid IPv4 in \"localhost:80\"";
  };
  testRejectNotString = {
    expr = bindpoint.parse 42;
    expectedError.msg = "^libnet\\.bindpoint\\.parse: expected string, got int$";
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
  testCompareNamesItself = {
    expr = bindpoint.lt (parse ":80") (libnet.ipEndpoint.parse "192.0.2.1:80");
    expectedError.msg = "^libnet\\.bindpoint\\.lt: expected ipBindpoint or unixSocket value, got ipEndpoint value$";
  };
  testToStringNamesItself = {
    expr = bindpoint.toString { };
    expectedError.msg = "^libnet\\.bindpoint\\.toString: expected ipBindpoint or unixSocket value, got set$";
  };
  testMemberPredicatesAcceptAnyValue = {
    expr = map (predicate: predicate ":80") [
      bindpoint.isIpBindpoint
      bindpoint.isUnixSocket
    ];
    expected = [
      false
      false
    ];
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
