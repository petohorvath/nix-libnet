{ harness }:
let
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
  inherit (unixSocket) parse;

  # 107-char pathname (max): "/" + 106 chars
  pathMax = "/" + builtins.concatStringsSep "" (builtins.genList (_: "a") 106);
  # 108-char pathname (one over)
  pathOver = "/" + builtins.concatStringsSep "" (builtins.genList (_: "a") 107);
in
{
  # ===== Parse: pathname =====
  testParseSimple = {
    expr = (parse "/run/foo.sock").path;
    expected = "/run/foo.sock";
  };
  testParsePostgres = {
    expr = (parse "/run/postgresql/.s.PGSQL.5432").path;
    expected = "/run/postgresql/.s.PGSQL.5432";
  };
  testParseTagged = {
    expr = (parse "/run/foo.sock")._type;
    expected = "unixSocket";
  };
  testParseMaxLength = {
    expr = (parse pathMax).path;
    expected = pathMax;
  };

  # ===== Parse: abstract =====
  testParseAbstract = {
    expr = (parse "@foo").path;
    expected = "@foo";
  };
  testParseAbstractTagged = {
    expr = (parse "@my-service")._type;
    expected = "unixSocket";
  };

  # ===== Reject =====
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectRelative = {
    expr = throws (parse "run/foo.sock");
    expected = true;
  };
  testRejectBareName = {
    expr = throws (parse "foo.sock");
    expected = true;
  };
  testRejectHostPort = {
    expr = throws (parse "1.2.3.4:80");
    expected = true;
  };
  testRejectSlashOnly = {
    expr = throws (parse "/");
    expected = true;
  };
  testRejectAtOnly = {
    expr = throws (parse "@");
    expected = true;
  };
  testRejectTooLong = {
    expr = throws (parse pathOver);
    expected = true;
  };
  testRejectNotString = {
    expr = throws (unixSocket.parse 42);
    expected = true;
  };

  testTryParseOk = {
    expr = (unixSocket.tryParse "/run/foo.sock").success;
    expected = true;
  };
  testTryParseAbstract = {
    expr = (unixSocket.tryParse "@foo").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (unixSocket.tryParse "foo.sock").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = builtins.isString (unixSocket.tryParse "foo").error;
    expected = true;
  };

  # ===== toString / accessor =====
  testToStringPathname = {
    expr = unixSocket.toString (parse "/run/foo.sock");
    expected = "/run/foo.sock";
  };
  testToStringAbstract = {
    expr = unixSocket.toString (parse "@foo");
    expected = "@foo";
  };
  testPathAccessor = {
    expr = unixSocket.path (parse "/run/foo.sock");
    expected = "/run/foo.sock";
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = unixSocket.is (parse "/run/foo.sock");
    expected = true;
  };
  testIsString = {
    expr = unixSocket.is "/run/foo.sock";
    expected = false;
  };
  testIsUntagged = {
    expr = unixSocket.is { path = "/run/foo.sock"; };
    expected = false;
  };
  testIsValidPathname = {
    expr = unixSocket.isValid "/run/foo.sock";
    expected = true;
  };
  testIsValidAbstract = {
    expr = unixSocket.isValid "@foo";
    expected = true;
  };
  testIsValidBad = {
    expr = unixSocket.isValid "foo.sock";
    expected = false;
  };
  testIsPathnameYes = {
    expr = unixSocket.isPathname (parse "/run/foo.sock");
    expected = true;
  };
  testIsPathnameNo = {
    expr = unixSocket.isPathname (parse "@foo");
    expected = false;
  };
  testIsAbstractYes = {
    expr = unixSocket.isAbstract (parse "@foo");
    expected = true;
  };
  testIsAbstractNo = {
    expr = unixSocket.isAbstract (parse "/run/foo.sock");
    expected = false;
  };

  # ===== Comparison helpers =====
  testLtBefore = {
    expr = unixSocket.lt (parse "/a") (parse "/b");
    expected = true;
  };
  testLeBefore = {
    expr = unixSocket.le (parse "/a") (parse "/b");
    expected = true;
  };
  testGtAfter = {
    expr = unixSocket.gt (parse "/b") (parse "/a");
    expected = true;
  };
  testGeAfter = {
    expr = unixSocket.ge (parse "/b") (parse "/a");
    expected = true;
  };

  # ===== Comparison =====
  testEqSame = {
    expr = unixSocket.eq (parse "/run/foo.sock") (parse "/run/foo.sock");
    expected = true;
  };
  testEqCaseSensitive = {
    expr = unixSocket.eq (parse "/run/Foo.sock") (parse "/run/foo.sock");
    expected = false;
  };
  testEqDifferent = {
    expr = unixSocket.eq (parse "/run/a.sock") (parse "/run/b.sock");
    expected = false;
  };
  testCompareLt = {
    expr = unixSocket.compare (parse "/run/a.sock") (parse "/run/b.sock");
    expected = -1;
  };
  testCompareGt = {
    expr = unixSocket.compare (parse "/run/b.sock") (parse "/run/a.sock");
    expected = 1;
  };
  testCompareEq = {
    expr = unixSocket.compare (parse "/run/a.sock") (parse "/run/a.sock");
    expected = 0;
  };
  testMinPick = {
    expr = (unixSocket.min (parse "/run/b.sock") (parse "/run/a.sock")).path;
    expected = "/run/a.sock";
  };
  testMaxPick = {
    expr = (unixSocket.max (parse "/run/b.sock") (parse "/run/a.sock")).path;
    expected = "/run/b.sock";
  };

  # ===== Constant =====
  testSunPathMax = {
    expr = unixSocket.sunPathMax;
    expected = 108;
  };
}
