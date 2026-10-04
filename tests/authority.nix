{ harness }:
let
  authority = import ../lib/authority.nix;
  port = import ../lib/port.nix;
  inherit (harness) throws;
  parse = authority.parse;
in
{
  # ===== Parse & toString =====
  testParseHostOnly = {
    expr = authority.toString (parse "example.com");
    expected = "example.com";
  };
  testParseHostPort = {
    expr = authority.toString (parse "example.com:8443");
    expected = "example.com:8443";
  };
  testParseUserinfo = {
    expr = authority.toString (parse "user@example.com:8443");
    expected = "user@example.com:8443";
  };
  testParseUserinfoNoPort = {
    expr = authority.toString (parse "user@example.com");
    expected = "user@example.com";
  };
  testParseIpv4 = {
    expr = authority.toString (parse "1.2.3.4:80");
    expected = "1.2.3.4:80";
  };
  testParseIpv6 = {
    expr = authority.toString (parse "[::1]:80");
    expected = "[::1]:80";
  };
  testParseIpv6NoPort = {
    expr = authority.toString (parse "[::1]");
    expected = "[::1]";
  };
  testParseTagged = {
    expr = (parse "example.com")._type;
    expected = "authority";
  };
  testParseCredentialsUserinfo = {
    expr = authority.userinfo (parse "u:pw@h");
    expected = "u:pw";
  };
  testParseUnderscoreHost = {
    expr = (authority.host (parse "my_host")).name;
    expected = "my_host";
  };
  testParseHostCasePreserved = {
    expr = (authority.host (parse "Example.COM")).name;
    expected = "Example.COM";
  };

  # ===== Accessors =====
  testAccessorUserinfo = {
    expr = authority.userinfo (parse "tok@h");
    expected = "tok";
  };
  testAccessorUserinfoNull = {
    expr = authority.userinfo (parse "h");
    expected = null;
  };
  testAccessorHostName = {
    expr = (authority.host (parse "h")).name;
    expected = "h";
  };
  testAccessorHostKindIp = {
    expr = (authority.host (parse "1.2.3.4")).kind;
    expected = "ip";
  };
  testAccessorPort = {
    expr = port.toInt (authority.port (parse "h:8080"));
    expected = 8080;
  };
  testAccessorPortNull = {
    expr = authority.port (parse "h");
    expected = null;
  };

  # ===== Reject =====
  testRejectEmptyHost = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectPortOnly = {
    expr = throws (parse ":80");
    expected = true;
  };
  testRejectBadPort = {
    expr = throws (parse "h:99999");
    expected = true;
  };
  testRejectMultipleAt = {
    expr = throws (parse "a@b@h");
    expected = true;
  };
  testRejectSpace = {
    expr = throws (parse "bad host");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (authority.parse 42);
    expected = true;
  };

  testTryParseOk = {
    expr = (authority.tryParse "h:80").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (authority.tryParse "a@b@c").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = builtins.isString (authority.tryParse "").error;
    expected = true;
  };

  # ===== make =====
  testMakeHost = {
    expr = authority.toString (authority.make { host = "example.com"; });
    expected = "example.com";
  };
  testMakeHostPort = {
    expr = authority.toString (
      authority.make {
        host = "h";
        port = 8080;
      }
    );
    expected = "h:8080";
  };
  testMakeUserinfo = {
    expr = authority.toString (
      authority.make {
        host = "h";
        userinfo = "tok";
      }
    );
    expected = "tok@h";
  };
  testMakeFull = {
    expr = authority.toString (
      authority.make {
        host = "h";
        userinfo = "u:pw";
        port = 443;
      }
    );
    expected = "u:pw@h:443";
  };
  testMakeIpv6 = {
    expr = authority.toString (
      authority.make {
        host = "[::1]";
        port = 80;
      }
    );
    expected = "[::1]:80";
  };
  testMakeBadHost = {
    expr = throws (authority.make { host = "bad host"; });
    expected = true;
  };
  testMakeBadPort = {
    expr = throws (
      authority.make {
        host = "h";
        port = "80";
      }
    );
    expected = true;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = authority.is (parse "h");
    expected = true;
  };
  testIsString = {
    expr = authority.is "h";
    expected = false;
  };
  testIsValidOk = {
    expr = authority.isValid "user@h:80";
    expected = true;
  };
  testIsValidBad = {
    expr = authority.isValid "a@b@c";
    expected = false;
  };
  testIsValidEmpty = {
    expr = authority.isValid "";
    expected = false;
  };

  # ===== Comparison =====
  # Unlike `url`, userinfo is part of identity and there is no default
  # port (a null port differs from any explicit one).
  testEqSame = {
    expr = authority.eq (parse "h:80") (parse "h:80");
    expected = true;
  };
  testEqUserinfoMatters = {
    expr = authority.eq (parse "u@h") (parse "h");
    expected = false;
  };
  testEqUserinfoSame = {
    expr = authority.eq (parse "u@h") (parse "u@h");
    expected = true;
  };
  testEqHostCaseInsensitive = {
    expr = authority.eq (parse "Example.COM:80") (parse "example.com:80");
    expected = true;
  };
  testEqPortNullVsExplicit = {
    expr = authority.eq (parse "h") (parse "h:80");
    expected = false;
  };
  testEqDifferentPort = {
    expr = authority.eq (parse "h:80") (parse "h:81");
    expected = false;
  };
  testCompareHost = {
    expr = authority.compare (parse "a.com") (parse "b.com");
    expected = -1;
  };
  testComparePort = {
    expr = authority.compare (parse "h:80") (parse "h:81");
    expected = -1;
  };
  testComparePortNullFirst = {
    expr = authority.compare (parse "h") (parse "h:80");
    expected = -1;
  };
  testCompareUserinfoTiebreak = {
    expr = authority.compare (parse "a@h") (parse "b@h");
    expected = -1;
  };
  testCompareEq = {
    expr = authority.compare (parse "h:80") (parse "h:80");
    expected = 0;
  };
  testLt = {
    expr = authority.lt (parse "h:80") (parse "h:81");
    expected = true;
  };
  testLe = {
    expr = authority.le (parse "h:80") (parse "h:80");
    expected = true;
  };
  testGt = {
    expr = authority.gt (parse "h:81") (parse "h:80");
    expected = true;
  };
  testGe = {
    expr = authority.ge (parse "h:80") (parse "h:80");
    expected = true;
  };
  testMin = {
    expr = authority.toString (authority.min (parse "h:80") (parse "h:81"));
    expected = "h:80";
  };
  testMax = {
    expr = authority.toString (authority.max (parse "h:80") (parse "h:81"));
    expected = "h:81";
  };
}
