{ helpers, libnet, ... }:
let
  inherit (libnet)
    authority
    ipv4
    port
    urlHost
    ;
  inherit (helpers) throws;
  inherit (authority) parse;
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
    expr = (authority.host (parse "my_host")).value;
    expected = "my_host";
  };
  testParseHostFoldsCase = {
    expr = authority.toString (parse "U@Example.COM:8080");
    expected = "U@example.com:8080";
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
    expr = (authority.host (parse "h")).value;
    expected = "h";
  };
  testAccessorHostIpv4 = {
    expr = authority.host (parse "1.2.3.4");
    expected = ipv4.parse "1.2.3.4";
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
    expr = parse ":80";
    expectedError.msg = "^libnet\\.authority\\.parse: empty host$";
  };
  # A host failure keeps the detail of `urlHost`, under `authority.parse`.
  testRejectHostKeepsDetail = {
    expr = map (text: (authority.tryParse text).error) [
      "u@127.1:80"
      "bad host"
      "[::1"
      "[zz]:80"
      "::1"
    ];
    expected = map (text: "libnet.authority.parse: " + text) [
      "must have 4 octets, got 2: \"127.1\""
      "invalid registered name \"bad host\""
      "malformed authority \"[::1\""
      "invalid IPv6 literal \"[zz]\""
      "malformed authority \"::1\""
    ];
  };
  testRejectHostAgreesWithUrlHost = {
    expr = (authority.tryParse "0x7f.0.0.1:80").error;
    expected =
      builtins.replaceStrings [ "libnet.urlHost.parse: " ] [ "libnet.authority.parse: " ]
        (urlHost.tryParse "0x7f.0.0.1").error;
  };
  testRejectBadPort = {
    expr = throws (parse "h:99999");
    expected = true;
  };
  # RFC 3986 allows leading zeros in a port; libnet rejects them so the
  # text round-trips (ADR 0013).
  testRejectPortLeadingZero = {
    expr = throws (parse "h:0080");
    expected = true;
  };
  testTryParseOverlongPort = {
    expr = (authority.tryParse "h:99999999999999999999").success;
    expected = false;
  };
  testRejectMultipleAt = {
    expr = throws (parse "a@b@h");
    expected = true;
  };
  testRejectSpace = {
    expr = parse "bad host";
    expectedError.msg = "^libnet\\.authority\\.parse: invalid registered name \"bad host\"$";
  };
  testRejectNotString = {
    expr = authority.parse 42;
    expectedError.msg = "^libnet\\.authority\\.parse: expected string, got int$";
  };

  # ===== Userinfo grammar =====
  # userinfo = *( unreserved / pct-encoded / sub-delims / ":" ), stored
  # as written except that percent-encoding hex digits are uppercased
  # (RFC 3986 §6.2.2.1); nothing is percent-decoded.
  testUserinfoEveryAllowedCharacter = {
    expr = authority.userinfo (parse "AZaz09-._~!$&'()*+,;=:%2f%2F@h");
    expected = "AZaz09-._~!$&'()*+,;=:%2F%2F";
  };
  testUserinfoUppercasesOnlyPercentEncodings = {
    expr = authority.toString (parse "aB%3a%c3%A9%41:x@h");
    expected = "aB%3A%C3%A9%41:x@h";
  };
  testUserinfoEmpty = {
    expr = authority.toString (parse "@h");
    expected = "@h";
  };
  testUserinfoRoundTrips = {
    expr = authority.toString (parse "User:P%41ss@h:80");
    expected = "User:P%41ss@h:80";
  };
  testRejectUserinfoSpace = {
    expr = parse "a b@h";
    expectedError.msg = "^libnet\\.authority\\.parse: invalid userinfo \"a b\"$";
  };
  testRejectUserinfoOutsideGrammar = {
    expr = builtins.filter (userinfo: authority.isValid "${userinfo}@h") [
      "a/b"
      "a?b"
      "a#b"
      "a\"b"
      "a<b"
      "a>b"
      "a\nb"
      "a[b"
      "a]b"
      "a\\b"
      "a^b"
      "a`b"
      "a{b"
      "a|b"
      "a}b"
      "a\tb"
      "é"
    ];
    expected = [ ];
  };
  testRejectUserinfoMalformedPercent = {
    expr = builtins.filter (userinfo: authority.isValid "${userinfo}@h") [
      "%zz"
      "%2"
      "%"
      "a%g0"
    ];
    expected = [ ];
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
    expr = authority.toString (authority.make { host = urlHost.parse "example.com"; });
    expected = "example.com";
  };
  testMakeHostPort = {
    expr = authority.toString (
      authority.make {
        host = urlHost.parse "h";
        port = port.fromInt 8080;
      }
    );
    expected = "h:8080";
  };
  testMakeUserinfo = {
    expr = authority.toString (
      authority.make {
        host = urlHost.parse "h";
        userinfo = "tok";
      }
    );
    expected = "tok@h";
  };
  testMakeFull = {
    expr = authority.toString (
      authority.make {
        host = urlHost.parse "h";
        userinfo = "u:pw";
        port = port.fromInt 443;
      }
    );
    expected = "u:pw@h:443";
  };
  testMakeIpv6 = {
    expr = authority.toString (
      authority.make {
        host = urlHost.parse "[::1]";
        port = port.fromInt 80;
      }
    );
    expected = "[::1]:80";
  };
  testMakeBadHostString = {
    expr = authority.make { host = "example.com"; };
    expectedError.msg = "^libnet\\.authority\\.make: expected ip or regName value, got string$";
  };
  # `make` runs the checks `parse` runs, so its result reparses to itself.
  testMakeRoundTrips = {
    expr =
      let
        made = authority.make {
          host = urlHost.parse "h";
          userinfo = "U:p%41ss";
          port = port.fromInt 8080;
        };
      in
      parse (authority.toString made) == made;
    expected = true;
  };
  testMakeUppercasesPercentEncodings = {
    expr = authority.userinfo (
      authority.make {
        host = urlHost.parse "h";
        userinfo = "a%2fB%c3";
      }
    );
    expected = "a%2FB%C3";
  };
  testMakeEqualsParse = {
    expr =
      authority.make {
        host = urlHost.parse "Example.COM";
        userinfo = "u";
        port = port.fromInt 443;
      } == parse "u@example.com:443";
    expected = true;
  };
  testMakeRejectsUserinfoSlash = {
    expr = authority.make {
      host = urlHost.parse "h";
      userinfo = "a/b";
    };
    expectedError.msg = "^libnet\\.authority\\.make: invalid userinfo \"a/b\"$";
  };
  testMakeRejectsUserinfoAt = {
    expr = authority.make {
      host = urlHost.parse "h";
      userinfo = "a@b";
    };
    expectedError.msg = "^libnet\\.authority\\.make: invalid userinfo \"a@b\"$";
  };
  testMakeRejectsUserinfoNonString = {
    expr = authority.make {
      host = urlHost.parse "h";
      userinfo = 1;
    };
    expectedError.msg = "^libnet\\.authority\\.make: expected string or null, got int$";
  };
  testMakeRejectsNonSet = {
    expr = authority.make "h";
    expectedError.msg = "^libnet\\.authority\\.make: expected set, got string$";
  };
  testMakeRejectsMissingHost = {
    expr = authority.make { userinfo = "u"; };
    expectedError.msg = "^libnet\\.authority\\.make: missing attribute \"host\"$";
  };
  testMakeRejectsUnknownAttribute = {
    expr = authority.make {
      host = urlHost.parse "h";
      path = "/";
    };
    expectedError.msg = "^libnet\\.authority\\.make: unexpected attribute \"path\"$";
  };
  testMakeIpv4Host = {
    expr = authority.toString (
      authority.make {
        host = ipv4.parse "1.2.3.4";
        port = port.fromInt 80;
      }
    );
    expected = "1.2.3.4:80";
  };
  testMakeBadHostDomain = {
    expr = throws (authority.make { host = libnet.domain.parse "example.com"; });
    expected = true;
  };
  testMakeBadPortInt = {
    expr = authority.make {
      host = urlHost.parse "h";
      port = 80;
    };
    expectedError.msg = "^libnet\\.authority\\.make: expected port value or null, got int$";
  };
  testMakeBadPortString = {
    expr = throws (
      authority.make {
        host = urlHost.parse "h";
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
  testEqUserinfoPercentEncodingCase = {
    expr = [
      (authority.eq (parse "u%2f@h") (parse "u%2F@h"))
      (authority.compare (parse "u%2f@h") (parse "u%2F@h"))
    ];
    expected = [
      true
      0
    ];
  };
  testEqUserinfoCaseSensitive = {
    expr = authority.eq (parse "u@h") (parse "U@h");
    expected = false;
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
