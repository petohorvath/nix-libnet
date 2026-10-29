{ helpers, libnet, ... }:
let
  inherit (libnet)
    authority
    dnsEndpoint
    ipEndpoint
    ipv4
    port
    registry
    url
    urlHost
    ;
  inherit (helpers) throws;
  inherit (url) parse;
in
{
  # ===== Parse: schemes & basics =====
  testParseHttps = {
    expr = url.toString (parse "https://example.com");
    expected = "https://example.com";
  };
  testParseHttpPort = {
    expr = url.toString (parse "http://example.com:8080");
    expected = "http://example.com:8080";
  };
  testParseFull = {
    expr = url.toString (parse "https://user@example.com:8443/a/b?x=1&y=2#frag");
    expected = "https://user@example.com:8443/a/b?x=1&y=2#frag";
  };
  testParseTagged = {
    expr = (parse "https://example.com")._type;
    expected = "url";
  };
  testParseSchemeLowercased = {
    expr = (parse "HTTPS://example.com").scheme;
    expected = "https";
  };
  testParseStoresNestedAuthority = {
    expr = parse "https://u@Example.com:8443/p?q#f";
    expected = {
      _type = "url";
      scheme = "https";
      authority = authority.parse "u@Example.com:8443";
      path = "/p";
      query = "q";
      fragment = "f";
    };
  };

  # ===== Host kinds =====
  testHostIpv4 = {
    expr = url.host (parse "http://1.2.3.4/x");
    expected = ipv4.parse "1.2.3.4";
  };
  testHostIpv6RoundTrip = {
    expr = url.toString (parse "http://[::1]:80/x");
    expected = "http://[::1]:80/x";
  };
  testHostRegName = {
    expr = (url.host (parse "http://example.com"))._type;
    expected = "regName";
  };
  testHostUnderscore = {
    expr = urlHost.toString (url.host (parse "http://my_host/x"));
    expected = "my_host";
  };
  testHostFoldsCase = {
    expr = urlHost.toString (url.host (parse "http://Example.COM"));
    expected = "example.com";
  };
  # The host folds; userinfo, path, query and fragment keep their case.
  testToStringFoldsOnlyHost = {
    expr = url.toString (parse "https://User@Example.COM/Path?Q=V#Frag");
    expected = "https://User@example.com/Path?Q=V#Frag";
  };

  # ===== Components (stored raw) =====
  testComponentPath = {
    expr = (parse "https://h/a%20b").path;
    expected = "/a%20b";
  };
  testComponentQueryRaw = {
    expr = (parse "https://h/?x=%26").query;
    expected = "x=%26";
  };
  testComponentFragment = {
    expr = (parse "https://h/#sec").fragment;
    expected = "sec";
  };
  testComponentNoPath = {
    expr = (parse "https://h").path;
    expected = "";
  };
  testComponentQueryNull = {
    expr = (parse "https://h/p").query;
    expected = null;
  };
  testComponentFragmentNull = {
    expr = (parse "https://h/p").fragment;
    expected = null;
  };
  testComponentUserinfo = {
    expr = url.userinfo (parse "https://tok@h");
    expected = "tok";
  };
  testComponentUserinfoNull = {
    expr = url.userinfo (parse "https://h");
    expected = null;
  };
  testComponentUserinfoCredentials = {
    expr = url.userinfo (parse "https://u:pw@h");
    expected = "u:pw";
  };

  # ===== Component grammars =====
  # RFC 3986 §3.3-3.5: path segments of pchar, query and fragment of
  # pchar / "/" / "?". Components stay verbatim, so valid text
  # round-trips with its case and percent-encoding as written.
  testComponentsEveryAllowedCharacter = {
    expr = url.toString (parse "https://h/AZaz09-._~!$&'()*+,;=:@%2f/?/?:@%2F#/?:@%aB");
    expected = "https://h/AZaz09-._~!$&'()*+,;=:@%2f/?/?:@%2F#/?:@%aB";
  };
  testComponentsEmptySegmentsQueryFragment = {
    expr = url.toString (parse "https://h//a//?#");
    expected = "https://h//a//?#";
  };
  testComponentsEmptyQueryAndFragmentStored = {
    expr =
      let
        value = parse "https://h?#";
      in
      [
        value.query
        value.fragment
      ];
    expected = [
      ""
      ""
    ];
  };
  testRejectPathSpace = {
    expr = parse "https://h/a b";
    expectedError.msg = "^libnet\\.url\\.parse: invalid path \"/a b\"$";
  };
  testRejectQueryOutsideGrammar = {
    expr = parse "https://h/p?a b";
    expectedError.msg = "^libnet\\.url\\.parse: invalid query \"a b\"$";
  };
  testRejectSecondHash = {
    expr = parse "https://h/p#a#b";
    expectedError.msg = "^libnet\\.url\\.parse: invalid fragment \"a#b\"$";
  };
  testRejectComponentsOutsideGrammar = {
    expr = builtins.filter url.isValid (
      builtins.concatMap
        (character: [
          "https://h/${character}"
          "https://h/?${character}"
          "https://h/#${character}"
        ])
        [
          " "
          "\""
          "<"
          ">"
          "\n"
          "\t"
          "["
          "]"
          "\\"
          "^"
          "`"
          "{"
          "|"
          "}"
          "é"
        ]
    );
    expected = [ ];
  };
  testRejectComponentsMalformedPercent = {
    expr = builtins.filter url.isValid (
      builtins.concatMap
        (escape: [
          "https://h/${escape}"
          "https://h/?${escape}"
          "https://h/#${escape}"
        ])
        [
          "%zz"
          "%2"
          "%"
          "%g0"
        ]
    );
    expected = [ ];
  };
  testRejectUserinfoNamesParse = {
    expr = parse "https://a b@h";
    expectedError.msg = "^libnet\\.url\\.parse: invalid userinfo \"a b\"$";
  };

  # ===== Reject =====
  testRejectNoScheme = {
    expr = throws (parse "example.com/x");
    expected = true;
  };
  testRejectUnknownScheme = {
    expr = throws (parse "gopher://h");
    expected = true;
  };
  testRejectEmptyHost = {
    expr = throws (parse "https:///path");
    expected = true;
  };
  testRejectBadPort = {
    expr = throws (parse "https://h:99999");
    expected = true;
  };
  testRejectPortLeadingZero = {
    expr = throws (parse "https://h:0443");
    expected = true;
  };
  testRejectMultipleAt = {
    expr = throws (parse "https://a@b@h");
    expected = true;
  };
  # Text that reads as IPv4 is not a registered name (ADR 0021).
  testRejectShortQuadHost = {
    expr = parse "http://127.1/";
    expectedError.msg = "^libnet\\.url\\.parse: invalid host \"127\\.1\"$";
  };
  testRejectHexQuadHost = {
    expr = parse "http://0x7f.0.0.1/";
    expectedError.msg = "^libnet\\.url\\.parse: invalid host \"0x7f\\.0\\.0\\.1\"$";
  };
  testRejectNumericHost = {
    expr = map url.isValid [
      "http://2130706433/"
      "http://010.0.0.1/"
      "https://a.0x/x"
    ];
    expected = [
      false
      false
      false
    ];
  };
  testRejectNotString = {
    expr = url.parse 42;
    expectedError.msg = "^libnet\\.url\\.parse: expected string, got int$";
  };
  # An authority failure names `url.parse` and keeps the detail.
  testRejectEmptyAuthorityNamesParse = {
    expr = url.parse "http://";
    expectedError.msg = "^libnet\\.url\\.parse: invalid host \"\"$";
  };
  testTryParseAuthorityErrorNamesParse = {
    expr = (url.tryParse "http://a@b@h").error;
    expected = "libnet.url.parse: malformed userinfo (multiple '@')";
  };

  testTryParseOk = {
    expr = (url.tryParse "https://h").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (url.tryParse "nope").success;
    expected = false;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = url.is (parse "https://h");
    expected = true;
  };
  testIsString = {
    expr = url.is "https://h";
    expected = false;
  };
  testIsValidOk = {
    expr = url.isValid "wss://h:9000/ws";
    expected = true;
  };
  testIsValidBad = {
    expr = url.isValid "h://x";
    expected = false;
  };
  testIsSecureHttps = {
    expr = url.isSecure (parse "https://h");
    expected = true;
  };
  testIsSecureHttp = {
    expr = url.isSecure (parse "http://h");
    expected = false;
  };

  # ===== Accessors =====
  testAccessorScheme = {
    expr = url.scheme (parse "ftp://h");
    expected = "ftp";
  };
  testAccessorHostName = {
    expr = url.host (parse "http://h");
    expected = urlHost.parse "h";
  };
  testAccessorAuthority = {
    expr = authority.toString (url.authority (parse "http://u@h:81/p?q#f"));
    expected = "u@h:81";
  };
  testAccessorAuthorityNoPort = {
    expr = authority.port (url.authority (parse "http://h"));
    expected = null;
  };
  testAccessorPortExplicit = {
    expr = port.toInt (url.port (parse "http://h:8080"));
    expected = 8080;
  };
  testAccessorPortNull = {
    expr = url.port (parse "http://h");
    expected = null;
  };
  testAccessorDefaultPort = {
    expr = url.defaultPort (parse "https://h");
    expected = port.fromInt 443;
  };
  testAccessorDefaultPortCheck = {
    expr = map (u: port.eq (url.effectivePort u) (url.defaultPort u)) [
      (parse "https://h")
      (parse "https://h:443")
      (parse "https://h:8443")
    ];
    expected = [
      true
      true
      false
    ];
  };
  testAccessorEffectivePortDefault = {
    expr = port.toInt (url.effectivePort (parse "https://h"));
    expected = 443;
  };
  testAccessorEffectivePortExplicit = {
    expr = port.toInt (url.effectivePort (parse "https://h:8443"));
    expected = 8443;
  };
  testAccessorTransportTcp = {
    expr = (url.transport (parse "https://h")).value;
    expected = "tcp";
  };
  testAccessorTransportUdp = {
    expr = (url.transport (parse "coap://h")).value;
    expected = "udp";
  };

  # ===== Scheme registry =====
  testSchemeSshPort = {
    expr = url.defaultPort (parse "ssh://h");
    expected = port.fromInt 22;
  };
  testSchemeRedisPort = {
    expr = url.defaultPort (parse "redis://h");
    expected = port.fromInt 6379;
  };
  testSchemePostgresPort = {
    expr = url.defaultPort (parse "postgres://h");
    expected = port.fromInt 5432;
  };
  testSchemeCoapUdp = {
    expr = (url.transport (parse "coap://h")).value;
    expected = "udp";
  };
  # Schemes that borrow another service's port (url.nix: ws → http,
  # wss → https, sftp → ssh) must resolve to that specific port.
  testSchemeWsBorrowsHttp = {
    expr = url.defaultPort (parse "ws://h");
    expected = port.fromInt 80;
  };
  testSchemeWssBorrowsHttps = {
    expr = url.defaultPort (parse "wss://h");
    expected = port.fromInt 443;
  };
  testSchemeSftpBorrowsSsh = {
    expr = url.defaultPort (parse "sftp://h");
    expected = port.fromInt 22;
  };
  testSchemesCount = {
    expr = builtins.length (builtins.attrNames url.schemes);
    expected = 30;
  };
  testSchemesSourcedFromRegistryPorts = {
    expr =
      let
        inherit (registry) ports;
        allPorts = builtins.attrValues ports.tcp ++ builtins.attrValues ports.udp;
      in
      builtins.all (scheme: builtins.elem scheme.defaultPort allPorts) (builtins.attrValues url.schemes);
    expected = true;
  };

  # ===== toEndpoint =====
  testToEndpointIpv4 = {
    expr = ipEndpoint.toString (url.toEndpoint (parse "http://1.2.3.4/x"));
    expected = "1.2.3.4:80";
  };
  testToEndpointIpv6 = {
    expr = ipEndpoint.toString (url.toEndpoint (parse "https://[::1]/x"));
    expected = "[::1]:443";
  };
  testToEndpointDns = {
    expr = dnsEndpoint.toString (url.toEndpoint (parse "https://example.com"));
    expected = "example.com:443";
  };
  testToEndpointExplicitPort = {
    expr = ipEndpoint.toString (url.toEndpoint (parse "http://1.2.3.4:8080"));
    expected = "1.2.3.4:8080";
  };
  testToEndpointHexLikeName = {
    expr = dnsEndpoint.toString (url.toEndpoint (parse "http://0x7g.example/"));
    expected = "0x7g.example:80";
  };
  testToEndpointRegNameThrows = {
    expr = throws (url.toEndpoint (parse "http://my_host/x"));
    expected = true;
  };

  # ===== make =====
  testMakeOk = {
    expr = url.toString (
      url.make {
        scheme = "https";
        authority = authority.parse "example.com";
        path = "/p";
      }
    );
    expected = "https://example.com/p";
  };
  testMakeAuthorityParts = {
    expr = url.toString (
      url.make {
        scheme = "http";
        authority = authority.make {
          host = ipv4.parse "1.2.3.4";
          userinfo = "tok";
          port = port.fromInt 8080;
        };
      }
    );
    expected = "http://tok@1.2.3.4:8080";
  };
  testMakeEqualsParse = {
    expr =
      url.make {
        scheme = "https";
        authority = authority.parse "u@h:8443";
        path = "/p";
        query = "q=1";
        fragment = "f";
      } == parse "https://u@h:8443/p?q=1#f";
    expected = true;
  };
  testMakeQueryFragment = {
    expr = url.toString (
      url.make {
        scheme = "https";
        authority = authority.parse "[::1]";
        path = "/p";
        query = "q=1";
        fragment = "f";
      }
    );
    expected = "https://[::1]/p?q=1#f";
  };
  testMakeSchemeCaseInsensitive = {
    expr = url.scheme (
      url.make {
        scheme = "HTTPS";
        authority = authority.parse "h";
      }
    );
    expected = "https";
  };
  testMakeBadScheme = {
    expr = url.make {
      scheme = "gopher";
      authority = authority.parse "h";
    };
    expectedError.msg = "^libnet\\.url\\.make: unknown scheme \"gopher\"$";
  };
  testMakeBadSchemeNonString = {
    expr = url.make {
      scheme = null;
      authority = authority.parse "h";
    };
    expectedError.msg = "^libnet\\.url\\.make: expected string, got null$";
  };
  testMakeBadAuthorityString = {
    expr = url.make {
      scheme = "http";
      authority = "h";
    };
    expectedError.msg = "^libnet\\.url\\.make: expected authority value, got string$";
  };
  testMakeBadAuthorityUrlHost = {
    expr = url.make {
      scheme = "http";
      authority = urlHost.parse "h";
    };
    expectedError.msg = "^libnet\\.url\\.make: expected authority value, got regName value$";
  };
  testMakeBadPath = {
    expr = url.make {
      scheme = "http";
      authority = authority.parse "h";
      path = "noslash";
    };
    expectedError.msg = "^libnet\\.url\\.make: invalid path \"noslash\"$";
  };
  # `make` runs the checks `parse` runs, so it cannot build text that
  # reparses differently, such as a path or query holding a fragment.
  testMakeRejectsPathHash = {
    expr = url.make {
      scheme = "http";
      authority = authority.parse "h";
      path = "/a#b";
    };
    expectedError.msg = "^libnet\\.url\\.make: invalid path \"/a#b\"$";
  };
  testMakeRejectsPathQuestionMark = {
    expr = url.make {
      scheme = "http";
      authority = authority.parse "h";
      path = "/a?b";
    };
    expectedError.msg = "^libnet\\.url\\.make: invalid path \"/a\\?b\"$";
  };
  testMakeRejectsQueryHash = {
    expr = url.make {
      scheme = "http";
      authority = authority.parse "h";
      query = "a#b";
    };
    expectedError.msg = "^libnet\\.url\\.make: invalid query \"a#b\"$";
  };
  testMakeRejectsFragmentSpace = {
    expr = url.make {
      scheme = "http";
      authority = authority.parse "h";
      fragment = "a b";
    };
    expectedError.msg = "^libnet\\.url\\.make: invalid fragment \"a b\"$";
  };
  testMakeRejectsNonStringComponents = {
    expr =
      map
        (
          component:
          throws (
            url.make (
              {
                scheme = "http";
                authority = authority.parse "h";
              }
              // component
            )
          )
        )
        [
          { path = null; }
          { path = 1; }
          { query = 1; }
          { fragment = [ ]; }
        ];
    expected = [
      true
      true
      true
      true
    ];
  };
  testMakeRejectsNonStringQueryMessage = {
    expr = url.make {
      scheme = "http";
      authority = authority.parse "h";
      query = 1;
    };
    expectedError.msg = "^libnet\\.url\\.make: expected string or null, got int$";
  };
  testMakeRejectsNonSet = {
    expr = url.make "https://h";
    expectedError.msg = "^libnet\\.url\\.make: expected set, got string$";
  };
  testMakeRejectsMissingAuthority = {
    expr = url.make { scheme = "http"; };
    expectedError.msg = "^libnet\\.url\\.make: missing attribute \"authority\"$";
  };
  testMakeRejectsUnexpectedAttribute = {
    expr = url.make {
      scheme = "http";
      authority = authority.parse "h";
      host = "h";
    };
    expectedError.msg = "^libnet\\.url\\.make: unexpected attribute \"host\"$";
  };
  testMakeRoundTrips = {
    expr =
      let
        made = url.make {
          scheme = "HTTPS";
          authority = authority.parse "U@h:8443";
          path = "//A%2f";
          query = "/?q=%41";
          fragment = "";
        };
      in
      parse (url.toString made) == made;
    expected = true;
  };
  testMakeEmptyPathOk = {
    expr = url.toString (
      url.make {
        scheme = "http";
        authority = authority.parse "h";
      }
    );
    expected = "http://h";
  };

  # ===== Comparison =====
  testEqSame = {
    expr = url.eq (parse "https://h/p") (parse "https://h/p");
    expected = true;
  };
  testEqHostCaseInsensitive = {
    expr = url.eq (parse "https://Example.COM") (parse "https://example.com");
    expected = true;
  };
  testEqDefaultVsExplicitPort = {
    expr = url.eq (parse "https://h") (parse "https://h:443");
    expected = true;
  };
  # RFC 3986 §6.2.3: an empty path is equivalent to `/`.
  testEqEmptyPathEqualsSlash = {
    expr = url.eq (parse "http://h") (parse "http://h/");
    expected = true;
  };
  testEqEmptyPathWithQuery = {
    expr = url.eq (parse "http://h?q") (parse "http://h/?q");
    expected = true;
  };
  testEqEmptyPathDiffersFromDoubleSlash = {
    expr = url.eq (parse "http://h") (parse "http://h//");
    expected = false;
  };
  testCompareEmptyPathEqualsSlash = {
    expr = url.compare (parse "http://h/") (parse "http://h");
    expected = 0;
  };
  testCompareEmptyPathAsSlash = {
    expr = url.compare (parse "http://h/?") (parse "http://h");
    expected = 1;
  };
  testToStringKeepsEmptyPath = {
    expr = map (text: url.toString (parse text)) [
      "http://h"
      "http://h/"
    ];
    expected = [
      "http://h"
      "http://h/"
    ];
  };
  testEqDifferentPath = {
    expr = url.eq (parse "https://h/a") (parse "https://h/b");
    expected = false;
  };
  testEqDifferentScheme = {
    expr = url.eq (parse "http://h") (parse "https://h");
    expected = false;
  };
  testEqCountsUserinfo = {
    expr = url.eq (parse "https://alice@h/p") (parse "https://bob@h/p");
    expected = false;
  };
  testEqUserinfoVsNone = {
    expr = url.eq (parse "https://alice@h/p") (parse "https://h/p");
    expected = false;
  };
  testEqSameUserinfoDefaultPort = {
    expr = url.eq (parse "https://alice@h/p") (parse "https://alice@h:443/p");
    expected = true;
  };
  testEqDifferentQuery = {
    expr = url.eq (parse "https://h/p?a") (parse "https://h/p");
    expected = false;
  };
  testEqDifferentFragment = {
    expr = url.eq (parse "https://h/p#a") (parse "https://h/p#b");
    expected = false;
  };
  testCompareScheme = {
    expr = url.compare (parse "http://h") (parse "https://h");
    expected = -1;
  };
  testCompareHost = {
    expr = url.compare (parse "https://a.com") (parse "https://b.com");
    expected = -1;
  };
  testComparePort = {
    expr = url.compare (parse "http://h:80") (parse "http://h:81");
    expected = -1;
  };
  testComparePath = {
    expr = url.compare (parse "https://h/a") (parse "https://h/b");
    expected = -1;
  };
  testCompareEq = {
    expr = url.compare (parse "https://h") (parse "https://h");
    expected = 0;
  };
  testCompareUserinfo = {
    expr = url.compare (parse "https://alice@h/p") (parse "https://bob@h/p");
    expected = -1;
  };
  testCompareUserinfoNullFirst = {
    expr = url.compare (parse "https://h/p") (parse "https://alice@h/p");
    expected = -1;
  };
  # Userinfo ranks after the effective port and before the path.
  testCompareUserinfoAfterPort = {
    expr = url.compare (parse "https://bob@h") (parse "https://alice@h:444");
    expected = -1;
  };
  testCompareUserinfoBeforePath = {
    expr = url.compare (parse "https://h/z") (parse "https://alice@h/a");
    expected = -1;
  };
  testCompareDefaultPortEqual = {
    expr = url.compare (parse "https://alice@h") (parse "https://alice@h:443");
    expected = 0;
  };
  testLt = {
    expr = url.lt (parse "http://h") (parse "https://h");
    expected = true;
  };
  testLe = {
    expr = url.le (parse "http://h") (parse "https://h");
    expected = true;
  };
  testGt = {
    expr = url.gt (parse "https://h") (parse "http://h");
    expected = true;
  };
  testGe = {
    expr = url.ge (parse "https://h") (parse "http://h");
    expected = true;
  };
  testMin = {
    expr = url.toString (url.min (parse "http://h") (parse "https://h"));
    expected = "http://h";
  };
  testMax = {
    expr = url.toString (url.max (parse "http://h") (parse "https://h"));
    expected = "https://h";
  };
}
