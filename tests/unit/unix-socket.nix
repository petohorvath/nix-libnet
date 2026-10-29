{ helpers, libnet, ... }:
let
  inherit (libnet) unixSocket;
  inherit (helpers) throws;
  inherit (unixSocket) parse;

  # 107-char pathname (max): "/" + 106 chars
  pathMax = "/" + builtins.concatStringsSep "" (builtins.genList (_: "a") 106);
  # 108-char pathname (one over)
  pathOver = "/" + builtins.concatStringsSep "" (builtins.genList (_: "a") 107);
  # 108-char abstract name (max): "@" + 107 chars, and one over
  abstractMax = "@" + builtins.concatStringsSep "" (builtins.genList (_: "a") 107);
  abstractOver = "@" + builtins.concatStringsSep "" (builtins.genList (_: "a") 108);
in
{
  # ===== Parse: pathname =====
  testParseSimple = {
    expr = (parse "/run/foo.sock").value;
    expected = "/run/foo.sock";
  };
  testParsePostgres = {
    expr = (parse "/run/postgresql/.s.PGSQL.5432").value;
    expected = "/run/postgresql/.s.PGSQL.5432";
  };
  testParseStoresValue = {
    expr = parse "/run/foo.sock";
    expected = {
      _type = "unixSocket";
      value = "/run/foo.sock";
    };
  };
  testParseTagged = {
    expr = (parse "/run/foo.sock")._type;
    expected = "unixSocket";
  };
  testParseMaxLength = {
    expr = (parse pathMax).value;
    expected = pathMax;
  };

  # At least one character follows the leading `/`.
  testParseMinLength = {
    expr = (parse "/a").value;
    expected = "/a";
  };

  # ===== Parse: abstract =====
  testParseAbstract = {
    expr = (parse "@foo").value;
    expected = "@foo";
  };
  testParseAbstractMinLength = {
    expr = (parse "@a").value;
    expected = "@a";
  };
  testParseAbstractMaxLength = {
    expr = (parse abstractMax).value;
    expected = abstractMax;
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
    expr = parse "/";
    expectedError.msg = "^libnet\\.unixSocket\\.parse: invalid socket \"/\" ";
  };
  testRejectAtOnly = {
    expr = parse "@";
    expectedError.msg = "^libnet\\.unixSocket\\.parse: invalid socket \"@\" ";
  };
  testRejectTooLong = {
    expr = throws (parse pathOver);
    expected = true;
  };
  testRejectAbstractTooLong = {
    expr = throws (parse abstractOver);
    expected = true;
  };
  testRejectNotString = {
    expr = unixSocket.parse 42;
    expectedError.msg = "^libnet\\.unixSocket\\.parse: expected string, got int$";
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
    expr = (unixSocket.tryParse "foo").error;
    expected = "libnet.unixSocket.parse: invalid socket \"foo\" (expected an absolute path '/...' (<=107 bytes) or an abstract name '@...' (<=108 bytes))";
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
  # `toString` returns the path; a scalar's `value` field has no accessor.
  testPathAccessorRemoved = {
    expr = unixSocket ? path;
    expected = false;
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
    expr = (unixSocket.min (parse "/run/b.sock") (parse "/run/a.sock")).value;
    expected = "/run/a.sock";
  };
  testCompareNamesItself = {
    expr = unixSocket.ge (parse "/a") { value = "/a"; };
    expectedError.msg = "^libnet\\.unixSocket\\.ge: expected unixSocket value, got set$";
  };
  testMinSortsPartially = {
    expr = map (unixSocket.min (parse "/run/b.sock")) [
      (parse "/run/a.sock")
      (parse "/run/c.sock")
    ];
    expected = [
      (parse "/run/a.sock")
      (parse "/run/b.sock")
    ];
  };
  testMaxPick = {
    expr = (unixSocket.max (parse "/run/b.sock") (parse "/run/a.sock")).value;
    expected = "/run/b.sock";
  };
}
