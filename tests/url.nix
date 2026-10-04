{ harness }:
let
  url = import ../lib/url.nix;
  port = import ../lib/port.nix;
  ipEndpoint = import ../lib/ip-endpoint.nix;
  dnsEndpoint = import ../lib/dns-endpoint.nix;
  registry = import ../lib/registry.nix;
  inherit (harness) throws;
  parse = url.parse;
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

  # ===== Host kinds =====
  testHostIpv4 = {
    expr = (parse "http://1.2.3.4/x").host.kind;
    expected = "ip";
  };
  testHostIpv6RoundTrip = {
    expr = url.toString (parse "http://[::1]:80/x");
    expected = "http://[::1]:80/x";
  };
  testHostRegName = {
    expr = (parse "http://example.com").host.kind;
    expected = "regName";
  };
  testHostUnderscore = {
    expr = (parse "http://my_host/x").host.name;
    expected = "my_host";
  };
  testHostPreservesCase = {
    expr = (parse "http://Example.COM").host.name;
    expected = "Example.COM";
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
    expr = (parse "https://tok@h").userinfo;
    expected = "tok";
  };
  testComponentUserinfoNull = {
    expr = (parse "https://h").userinfo;
    expected = null;
  };
  testComponentUserinfoCredentials = {
    expr = (parse "https://u:pw@h").userinfo;
    expected = "u:pw";
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
  testRejectMultipleAt = {
    expr = throws (parse "https://a@b@h");
    expected = true;
  };
  testRejectNotString = {
    expr = throws (url.parse 42);
    expected = true;
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
    expr = (url.host (parse "http://h")).name;
    expected = "h";
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
    expected = 443;
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
    expected = 22;
  };
  testSchemeRedisPort = {
    expr = url.defaultPort (parse "redis://h");
    expected = 6379;
  };
  testSchemePostgresPort = {
    expr = url.defaultPort (parse "postgres://h");
    expected = 5432;
  };
  testSchemeCoapUdp = {
    expr = (url.transport (parse "coap://h")).value;
    expected = "udp";
  };
  # Schemes that borrow another service's port (url.nix: ws → http,
  # wss → https, sftp → ssh) must resolve to that specific port.
  testSchemeWsBorrowsHttp = {
    expr = url.defaultPort (parse "ws://h");
    expected = 80;
  };
  testSchemeWssBorrowsHttps = {
    expr = url.defaultPort (parse "wss://h");
    expected = 443;
  };
  testSchemeSftpBorrowsSsh = {
    expr = url.defaultPort (parse "sftp://h");
    expected = 22;
  };
  testSchemesCount = {
    expr = builtins.length (builtins.attrNames url.schemes);
    expected = 30;
  };
  testSchemesSourcedFromRegistryPorts = {
    expr =
      let
        ports = registry.ports;
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
  testToEndpointRegNameThrows = {
    expr = throws (url.toEndpoint (parse "http://my_host/x"));
    expected = true;
  };

  # ===== make =====
  testMakeOk = {
    expr = url.toString (
      url.make {
        scheme = "https";
        host = "example.com";
        path = "/p";
      }
    );
    expected = "https://example.com/p";
  };
  testMakePort = {
    expr = url.toString (
      url.make {
        scheme = "http";
        host = "h";
        port = 8080;
      }
    );
    expected = "http://h:8080";
  };
  testMakeUserinfo = {
    expr = url.toString (
      url.make {
        scheme = "https";
        host = "h";
        userinfo = "tok";
      }
    );
    expected = "https://tok@h";
  };
  testMakeBadScheme = {
    expr = throws (
      url.make {
        scheme = "gopher";
        host = "h";
      }
    );
    expected = true;
  };
  testMakeBadHost = {
    expr = throws (
      url.make {
        scheme = "http";
        host = "bad host";
      }
    );
    expected = true;
  };
  testMakeBadPath = {
    expr = throws (
      url.make {
        scheme = "http";
        host = "h";
        path = "noslash";
      }
    );
    expected = true;
  };
  testMakeEmptyPathOk = {
    expr = url.toString (
      url.make {
        scheme = "http";
        host = "h";
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
  testEqDifferentPath = {
    expr = url.eq (parse "https://h/a") (parse "https://h/b");
    expected = false;
  };
  testEqDifferentScheme = {
    expr = url.eq (parse "http://h") (parse "https://h");
    expected = false;
  };
  # userinfo is not part of URL identity (see authority.nix): two URLs
  # differing only in credentials compare equal.
  testEqIgnoresUserinfo = {
    expr = url.eq (parse "https://alice@h/p") (parse "https://bob@h/p");
    expected = true;
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
  testCompareIgnoresUserinfo = {
    expr = url.compare (parse "https://alice@h/p") (parse "https://bob@h/p");
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
