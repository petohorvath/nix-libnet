{ harness }:
let
  proxyUrl = import ../lib/proxy-url.nix;
  authority = import ../lib/authority.nix;
  port = import ../lib/port.nix;
  inherit (harness) throws;
  parse = proxyUrl.parse;
in
{
  # ===== Parse & toString =====
  testParseSocks5 = {
    expr = proxyUrl.toString (parse "socks5://127.0.0.1:1080");
    expected = "socks5://127.0.0.1:1080";
  };
  testParseHttp = {
    expr = proxyUrl.toString (parse "http://proxy.corp:8080");
    expected = "http://proxy.corp:8080";
  };
  testParseHttps = {
    expr = proxyUrl.toString (parse "https://proxy:8443");
    expected = "https://proxy:8443";
  };
  testParseSocks4a = {
    expr = proxyUrl.toString (parse "socks4a://h:1080");
    expected = "socks4a://h:1080";
  };
  testParseSocks5h = {
    expr = proxyUrl.toString (parse "socks5h://h:1080");
    expected = "socks5h://h:1080";
  };
  testParseUserinfo = {
    expr = proxyUrl.toString (parse "socks5://user:pass@10.0.0.1:1080");
    expected = "socks5://user:pass@10.0.0.1:1080";
  };
  testParseIpv6 = {
    expr = proxyUrl.toString (parse "socks5://[::1]:1080");
    expected = "socks5://[::1]:1080";
  };
  testParseSchemeCaseInsensitive = {
    expr = proxyUrl.toString (parse "SOCKS5://h:1080");
    expected = "socks5://h:1080";
  };
  testParseTagged = {
    expr = (parse "socks5://h:1080")._type;
    expected = "proxyUrl";
  };
  testParseSchemeAccessor = {
    expr = proxyUrl.scheme (parse "socks5://h:1080");
    expected = "socks5";
  };
  testParseAuthorityKind = {
    expr = (proxyUrl.authority (parse "socks5://h:1080"))._type;
    expected = "authority";
  };
  testParseAuthorityHostIp = {
    expr = (authority.host (proxyUrl.authority (parse "socks5://1.2.3.4:1080"))).kind;
    expected = "ip";
  };
  testParseAuthorityPort = {
    expr = port.toInt (authority.port (proxyUrl.authority (parse "socks5://h:1080")));
    expected = 1080;
  };

  # ===== Reject =====
  testRejectNoScheme = {
    expr = throws (parse "127.0.0.1:1080");
    expected = true;
  };
  testRejectUnknownScheme = {
    expr = throws (parse "ftp://h:1080");
    expected = true;
  };
  testRejectBareSocks = {
    expr = throws (parse "socks://h:1080");
    expected = true;
  };
  testRejectNoPort = {
    expr = throws (parse "socks5://127.0.0.1");
    expected = true;
  };
  testRejectEmptyHost = {
    expr = throws (parse "socks5://:1080");
    expected = true;
  };
  testRejectMultipleAt = {
    expr = throws (parse "socks5://a@b@h:1080");
    expected = true;
  };
  testRejectPath = {
    expr = throws (parse "http://h:8080/pac");
    expected = true;
  };
  testRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (proxyUrl.parse 42);
    expected = true;
  };

  testTryParseOk = {
    expr = (proxyUrl.tryParse "socks5://h:1080").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (proxyUrl.tryParse "socks5://h").success;
    expected = false;
  };
  testTryParseBadError = {
    expr = builtins.isString (proxyUrl.tryParse "socks5://h").error;
    expected = true;
  };

  # ===== make =====
  testMakeOk = {
    expr = proxyUrl.toString (
      proxyUrl.make "socks5" (
        authority.make {
          host = "10.0.0.1";
          port = 1080;
        }
      )
    );
    expected = "socks5://10.0.0.1:1080";
  };
  testMakeUserinfo = {
    expr = proxyUrl.toString (
      proxyUrl.make "http" (
        authority.make {
          host = "h";
          userinfo = "u:p";
          port = 8080;
        }
      )
    );
    expected = "http://u:p@h:8080";
  };
  testMakeSchemeCase = {
    expr = proxyUrl.toString (
      proxyUrl.make "SOCKS5" (
        authority.make {
          host = "h";
          port = 1080;
        }
      )
    );
    expected = "socks5://h:1080";
  };
  testMakeUnknownSchemeThrows = {
    expr = throws (
      proxyUrl.make "ftp" (
        authority.make {
          host = "h";
          port = 1080;
        }
      )
    );
    expected = true;
  };
  testMakeNoPortThrows = {
    expr = throws (proxyUrl.make "socks5" (authority.make { host = "h"; }));
    expected = true;
  };
  testMakeNonAuthorityThrows = {
    expr = throws (proxyUrl.make "socks5" "h:1080");
    expected = true;
  };
  testMakeNonStringSchemeThrows = {
    expr = throws (
      proxyUrl.make 42 (
        authority.make {
          host = "h";
          port = 1080;
        }
      )
    );
    expected = true;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = proxyUrl.is (parse "socks5://h:1080");
    expected = true;
  };
  testIsString = {
    expr = proxyUrl.is "socks5://h:1080";
    expected = false;
  };
  testIsValidOk = {
    expr = proxyUrl.isValid "http://proxy:8080";
    expected = true;
  };
  testIsValidBad = {
    expr = proxyUrl.isValid "ftp://h:1";
    expected = false;
  };
  testIsValidNoPort = {
    expr = proxyUrl.isValid "socks5://h";
    expected = false;
  };
  testIsSecureHttps = {
    expr = proxyUrl.isSecure (parse "https://h:443");
    expected = true;
  };
  testIsSecureHttp = {
    expr = proxyUrl.isSecure (parse "http://h:8080");
    expected = false;
  };
  testIsSecureSocks5 = {
    expr = proxyUrl.isSecure (parse "socks5://h:1080");
    expected = false;
  };
  testIsSecureSocks5h = {
    expr = proxyUrl.isSecure (parse "socks5h://h:1080");
    expected = false;
  };

  # ===== Comparison =====
  testEqSame = {
    expr = proxyUrl.eq (parse "socks5://h:1080") (parse "socks5://h:1080");
    expected = true;
  };
  testEqDifferentScheme = {
    expr = proxyUrl.eq (parse "socks5://h:1080") (parse "socks5h://h:1080");
    expected = false;
  };
  testEqDifferentAuthority = {
    expr = proxyUrl.eq (parse "socks5://h:1080") (parse "socks5://h:1081");
    expected = false;
  };
  testEqUserinfoMatters = {
    expr = proxyUrl.eq (parse "socks5://u@h:1080") (parse "socks5://h:1080");
    expected = false;
  };
  testEqHostCaseInsensitive = {
    expr = proxyUrl.eq (parse "socks5://Example.COM:1080") (parse "socks5://example.com:1080");
    expected = true;
  };
  testCompareHttpBeforeSocks5 = {
    expr = proxyUrl.compare (parse "http://h:1") (parse "socks5://h:1");
    expected = -1;
  };
  testCompareSocks4BeforeSocks4a = {
    expr = proxyUrl.compare (parse "socks4://h:1") (parse "socks4a://h:1");
    expected = -1;
  };
  testCompareWithinSchemeByAuthority = {
    expr = proxyUrl.compare (parse "socks5://h:1080") (parse "socks5://h:1081");
    expected = -1;
  };
  testCompareEq = {
    expr = proxyUrl.compare (parse "socks5://h:1080") (parse "socks5://h:1080");
    expected = 0;
  };
  testLt = {
    expr = proxyUrl.lt (parse "http://h:1") (parse "socks5://h:1");
    expected = true;
  };
  testLe = {
    expr = proxyUrl.le (parse "socks5://h:1080") (parse "socks5://h:1080");
    expected = true;
  };
  testGt = {
    expr = proxyUrl.gt (parse "socks5://h:1") (parse "http://h:1");
    expected = true;
  };
  testGe = {
    expr = proxyUrl.ge (parse "socks5://h:1080") (parse "socks5://h:1080");
    expected = true;
  };
  testMin = {
    expr = proxyUrl.toString (proxyUrl.min (parse "socks5://h:1") (parse "http://h:1"));
    expected = "http://h:1";
  };
  testMax = {
    expr = proxyUrl.toString (proxyUrl.max (parse "socks5://h:1") (parse "http://h:1"));
    expected = "socks5://h:1";
  };

  # ===== Constant =====
  testSchemesList = {
    expr = proxyUrl.schemes;
    expected = [
      "http"
      "https"
      "socks4"
      "socks4a"
      "socks5"
      "socks5h"
    ];
  };
}
