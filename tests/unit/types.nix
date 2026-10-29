# The module types need `nixpkgs.lib`; without it the suite has no tests.
{
  helpers,
  lib,
  libnet,
  ...
}:
let
  inherit (helpers) throws;
  inherit (libnet) registry;
  inherit (libnet.withLib lib) types;

  # Registry ↔ type cross-check: the curated vocabulary always
  # satisfies the type that validates its value space.
  allIcmpTypesCheck =
    icmpTypes:
    builtins.all (name: types.icmpType.check icmpTypes.${name}) (builtins.attrNames icmpTypes);

  # Merge one definition through the module system, as an option would.
  merged =
    type: value:
    (lib.evalModules {
      modules = [
        {
          options.value = lib.mkOption { inherit type; };
          config = { inherit value; };
        }
      ];
    }).config.value;
in
if lib == null then
  { }
else
  {
    # ===== ipv4 =====
    testIpv4CheckOk = {
      expr = types.ipv4.check "1.2.3.4";
      expected = true;
    };
    testIpv4CheckBad = {
      expr = types.ipv4.check "bad";
      expected = false;
    };
    testIpv4CheckInt = {
      expr = types.ipv4.check 123;
      expected = false;
    };
    testIpv4MkOk = {
      expr = types.ipv4.mk "1.2.3.4";
      expected = "1.2.3.4";
    };
    testIpv4MkBad = {
      expr = throws (types.ipv4.mk "bad");
      expected = true;
    };
    testIpv4MkInt = {
      expr = throws (types.ipv4.mk 123);
      expected = true;
    };
    testIpv4Description = {
      expr = builtins.isString types.ipv4.description;
      expected = true;
    };

    # ===== ipv6 =====
    testIpv6CheckOk = {
      expr = types.ipv6.check "::1";
      expected = true;
    };
    testIpv6CheckBad = {
      expr = types.ipv6.check "bad";
      expected = false;
    };
    testIpv6MkOk = {
      expr = types.ipv6.mk "2001:db8::1";
      expected = "2001:db8::1";
    };
    testIpv6MkNotNormalized = {
      expr = types.ipv6.mk "2001:DB8::1";
      expected = "2001:DB8::1";
    };

    # ===== ip =====
    testIpCheckV4 = {
      expr = types.ip.check "1.2.3.4";
      expected = true;
    };
    testIpCheckV6 = {
      expr = types.ip.check "::1";
      expected = true;
    };
    testIpCheckBad = {
      expr = types.ip.check "bad";
      expected = false;
    };

    # ===== mac =====
    testMacCheckColon = {
      expr = types.mac.check "aa:bb:cc:dd:ee:ff";
      expected = true;
    };
    testMacCheckHyphen = {
      expr = types.mac.check "aa-bb-cc-dd-ee-ff";
      expected = true;
    };
    testMacCheckCisco = {
      expr = types.mac.check "aabb.ccdd.eeff";
      expected = true;
    };
    testMacCheckBad = {
      expr = types.mac.check "zz:zz:zz:zz:zz:zz";
      expected = false;
    };
    testMacMkOk = {
      expr = types.mac.mk "aa:bb:cc:dd:ee:ff";
      expected = "aa:bb:cc:dd:ee:ff";
    };

    # ===== cidr =====
    testCidrV4Ok = {
      expr = types.cidr.check "10.0.0.0/24";
      expected = true;
    };
    testCidrV6Ok = {
      expr = types.cidr.check "2001:db8::/32";
      expected = true;
    };
    testCidrBad = {
      expr = types.cidr.check "bad";
      expected = false;
    };
    testCidrRejectsHostBits = {
      expr = types.cidr.check "10.0.0.5/24";
      expected = false;
    };
    testCidrRejectsLeadingZeroPrefix = {
      expr = types.cidr.check "10.0.0.0/08";
      expected = false;
    };
    testCidrRejectsOverlongPrefix = {
      expr = types.cidr.check "10.0.0.0/99999999999999999999";
      expected = false;
    };
    testIpv6CidrRejectsHostBits = {
      expr = types.ipv6Cidr.check "2001:db8::1/64";
      expected = false;
    };
    testIpv4CidrV4Ok = {
      expr = types.ipv4Cidr.check "10.0.0.0/24";
      expected = true;
    };
    testIpv4CidrRejectsV6 = {
      expr = types.ipv4Cidr.check "::/0";
      expected = false;
    };
    testIpv6CidrV6Ok = {
      expr = types.ipv6Cidr.check "::/0";
      expected = true;
    };
    testIpv6CidrRejectsV4 = {
      expr = types.ipv6Cidr.check "10.0.0.0/24";
      expected = false;
    };
    # The family check runs only on a string, so a parsed value is
    # rejected rather than thrown on.
    testCidrTypesRejectParsedValue = {
      expr = map (type: type.check (libnet.cidr.parse "10.0.0.0/24")) [
        types.cidr
        types.ipv4Cidr
        types.ipv6Cidr
      ];
      expected = [
        false
        false
        false
      ];
    };
    testCidrMergesToInput = {
      expr = merged types.ipv6Cidr "2001:db8::/32";
      expected = "2001:db8::/32";
    };

    # ===== port (coerced int) =====
    testPortCheckInt = {
      expr = types.port.check 80;
      expected = true;
    };
    testPortCheckString = {
      expr = types.port.check "80";
      expected = true;
    };
    testPortCheckOutOfRange = {
      expr = types.port.check 70000;
      expected = false;
    };
    testPortCheckNegative = {
      expr = types.port.check (-1);
      expected = false;
    };
    testPortCheckInvalidString = {
      expr = builtins.any types.port.check [
        "70000"
        "-1"
        "0x50"
        ""
      ];
      expected = false;
    };
    testPortCheckLeadingZero = {
      expr = types.port.check "0080";
      expected = false;
    };
    testPortCheckOverlongString = {
      expr = types.port.check "99999999999999999999";
      expected = false;
    };
    testPortMergesStringToInt = {
      expr = merged types.port "8080";
      expected = 8080;
    };
    testPortMkInt = {
      expr = types.port.mk 80;
      expected = 80;
    };
    testPortMkString = {
      expr = types.port.mk "80";
      expected = 80;
    };
    testPortMkBadInt = {
      expr = types.port.mk 70000;
      expectedError.msg = "^libnet\\.types\\.port\\.mk: out of range \\[0, 65535\\]: 70000$";
    };
    testPortMkRejectsSet = {
      expr = types.port.mk { };
      expectedError.msg = "^libnet\\.types\\.port\\.mk: expected int or string, got set$";
    };
    testPortMkRejectsParsedValue = {
      expr = types.port.mk (libnet.port.fromInt 80);
      expectedError.msg = "^libnet\\.types\\.port\\.mk: expected int or string, got port value$";
    };
    testPortMkBadString = {
      expr = types.port.mk "abc";
      expectedError.msg = "^libnet\\.types\\.port\\.mk: invalid value \"abc\"$";
    };

    # ===== portRange =====
    testPortRangeSingle = {
      expr = types.portRange.check "80";
      expected = true;
    };
    testPortRangeRange = {
      expr = types.portRange.check "80-90";
      expected = true;
    };
    testPortRangeLeadingZero = {
      expr = types.portRange.check "080-90";
      expected = false;
    };
    testPortRangeBad = {
      expr = types.portRange.check "90-80";
      expected = false;
    };
    testPortRangeRejectsInt = {
      expr = types.portRange.check 80;
      expected = false;
    };
    testPortRangeMkRejectsParsedValue = {
      expr = types.portRange.mk (libnet.portRange.parse "80-90");
      expectedError.msg = "^libnet\\.types\\.portRange\\.mk: expected string, got portRange value$";
    };
    testPortRangeOverlong = {
      expr = types.portRange.check "80-99999999999999999999";
      expected = false;
    };

    # ===== ipEndpoint =====
    testIpEndpointV4Ok = {
      expr = types.ipEndpoint.check "1.2.3.4:80";
      expected = true;
    };
    testIpEndpointV6Ok = {
      expr = types.ipEndpoint.check "[::1]:80";
      expected = true;
    };
    testIpEndpointBad = {
      expr = types.ipEndpoint.check "::1:80";
      expected = false;
    };
    testIpEndpointNameRejected = {
      expr = types.ipEndpoint.check "nas:22";
      expected = false;
    };

    # ===== dnsEndpoint =====
    testDnsEndpointHostnameOk = {
      expr = types.dnsEndpoint.check "nas:22";
      expected = true;
    };
    testDnsEndpointDomainOk = {
      expr = types.dnsEndpoint.check "pool.ntp.org:123";
      expected = true;
    };
    testDnsEndpointIpRejected = {
      expr = types.dnsEndpoint.check "192.0.2.1:80";
      expected = false;
    };
    testDnsEndpointNumericNameRejected = {
      expr = types.dnsEndpoint.check "127.1:80";
      expected = false;
    };
    testDnsEndpointNoPort = {
      expr = types.dnsEndpoint.check "nas";
      expected = false;
    };
    testDnsEndpointMkOk = {
      expr = types.dnsEndpoint.mk "pool.ntp.org:123";
      expected = "pool.ntp.org:123";
    };
    testDnsEndpointDescription = {
      expr = builtins.isString types.dnsEndpoint.description;
      expected = true;
    };

    # ===== endpoint (union) =====
    testEndpointIpv4Ok = {
      expr = types.endpoint.check "192.0.2.1:80";
      expected = true;
    };
    testEndpointIpv6Ok = {
      expr = types.endpoint.check "[::1]:443";
      expected = true;
    };
    testEndpointHostnameOk = {
      expr = types.endpoint.check "nas:22";
      expected = true;
    };
    testEndpointDomainOk = {
      expr = types.endpoint.check "pool.ntp.org:123";
      expected = true;
    };
    testEndpointUnixOk = {
      expr = types.endpoint.check "/run/foo.sock";
      expected = true;
    };
    testEndpointBad = {
      expr = types.endpoint.check "host_name:1";
      expected = false;
    };
    testEndpointNoPort = {
      expr = types.endpoint.check "nas";
      expected = false;
    };
    testEndpointMkIp = {
      expr = types.endpoint.mk "192.0.2.1:80";
      expected = "192.0.2.1:80";
    };
    testEndpointMkName = {
      expr = types.endpoint.mk "pool.ntp.org:123";
      expected = "pool.ntp.org:123";
    };
    testEndpointMkRejectsSet = {
      expr = types.endpoint.mk { };
      expectedError.msg = "^libnet\\.types\\.endpoint\\.mk: expected string, got set$";
    };
    testEndpointDescription = {
      expr = builtins.isString types.endpoint.description;
      expected = true;
    };

    # ===== unixSocket =====
    testUnixSocketPathnameOk = {
      expr = types.unixSocket.check "/run/foo.sock";
      expected = true;
    };
    testUnixSocketAbstractOk = {
      expr = types.unixSocket.check "@foo";
      expected = true;
    };
    testUnixSocketRelativeRejected = {
      expr = types.unixSocket.check "run/foo.sock";
      expected = false;
    };
    testUnixSocketHostPortRejected = {
      expr = types.unixSocket.check "1.2.3.4:80";
      expected = false;
    };
    testUnixSocketInt = {
      expr = types.unixSocket.check 42;
      expected = false;
    };
    testUnixSocketMkOk = {
      expr = types.unixSocket.mk "/run/foo.sock";
      expected = "/run/foo.sock";
    };
    testUnixSocketMkBad = {
      expr = types.unixSocket.mk "foo.sock";
      expectedError.msg = "^libnet\\.types\\.unixSocket\\.mk: invalid value \"foo\\.sock\"$";
    };
    # One character must follow the leading `/` or `@`.
    testUnixSocketMinimum = {
      expr = map types.unixSocket.check [
        "/a"
        "@a"
        "/"
        "@"
      ];
      expected = [
        true
        true
        false
        false
      ];
    };
    # Unix socket paths are case-sensitive, so the merged value keeps case.
    testUnixSocketMergeKeepsCase = {
      expr = merged types.unixSocket "/run/Foo.sock";
      expected = "/run/Foo.sock";
    };
    testUnixSocketDescription = {
      expr = builtins.isString types.unixSocket.description;
      expected = true;
    };

    # ===== socketUrl =====
    testSocketUrlTcp = {
      expr = types.socketUrl.check "tcp://1.2.3.4:80";
      expected = true;
    };
    testSocketUrlUdpV6 = {
      expr = types.socketUrl.check "udp://[::1]:53";
      expected = true;
    };
    testSocketUrlUnix = {
      expr = types.socketUrl.check "unix:///run/foo.sock";
      expected = true;
    };
    testSocketUrlUppercaseScheme = {
      expr = types.socketUrl.check "TCP://1.2.3.4:80";
      expected = true;
    };
    testSocketUrlNoScheme = {
      expr = types.socketUrl.check "1.2.3.4:80";
      expected = false;
    };
    testSocketUrlUnknownScheme = {
      expr = types.socketUrl.check "http://1.2.3.4:80";
      expected = false;
    };
    testSocketUrlTcpPathRejected = {
      expr = types.socketUrl.check "tcp:///run/foo.sock";
      expected = false;
    };
    testSocketUrlMkOk = {
      expr = types.socketUrl.mk "tcp://1.2.3.4:80";
      expected = "tcp://1.2.3.4:80";
    };
    testSocketUrlMkBad = {
      expr = types.socketUrl.mk "ftp://x:1";
      expectedError.msg = "^libnet\\.types\\.socketUrl\\.mk: invalid value \"ftp://x:1\"$";
    };
    testSocketUrlUnixHostPortRejected = {
      expr = types.socketUrl.check "unix://1.2.3.4:80";
      expected = false;
    };
    # The merged value keeps the scheme's input spelling (ADR 0016).
    testSocketUrlMergeKeepsSpelling = {
      expr = merged types.socketUrl "TCP://1.2.3.4:80";
      expected = "TCP://1.2.3.4:80";
    };
    testSocketUrlDescription = {
      expr = builtins.isString types.socketUrl.description;
      expected = true;
    };

    # ===== bindUrl =====
    testBindUrlTcpWildcard = {
      expr = types.bindUrl.check "tcp://:8080";
      expected = true;
    };
    testBindUrlUdpV6Range = {
      expr = types.bindUrl.check "udp://[::]:8000-8100";
      expected = true;
    };
    testBindUrlUnix = {
      expr = types.bindUrl.check "unix:///run/foo.sock";
      expected = true;
    };
    testBindUrlUppercaseScheme = {
      expr = types.bindUrl.check "TCP://:80";
      expected = true;
    };
    testBindUrlNoScheme = {
      expr = types.bindUrl.check ":8080";
      expected = false;
    };
    testBindUrlUnknownScheme = {
      expr = types.bindUrl.check "http://:8080";
      expected = false;
    };
    testBindUrlTcpPathRejected = {
      expr = types.bindUrl.check "tcp:///run/foo.sock";
      expected = false;
    };
    testBindUrlMkOk = {
      expr = types.bindUrl.mk "tcp://:8080";
      expected = "tcp://:8080";
    };
    testBindUrlMkBad = {
      expr = types.bindUrl.mk "ftp://:1";
      expectedError.msg = "^libnet\\.types\\.bindUrl\\.mk: invalid value \"ftp://:1\"$";
    };
    testBindUrlUnixHostPortRejected = {
      expr = types.bindUrl.check "unix://:80";
      expected = false;
    };
    testBindUrlMergeKeepsSpelling = {
      expr = merged types.bindUrl "Udp://:53";
      expected = "Udp://:53";
    };
    testBindUrlDescription = {
      expr = builtins.isString types.bindUrl.description;
      expected = true;
    };

    # ===== secureSocketUrl =====
    testSecureSocketUrlTls = {
      expr = types.secureSocketUrl.check "tls://1.2.3.4:443";
      expected = true;
    };
    testSecureSocketUrlSslAlias = {
      expr = types.secureSocketUrl.check "ssl://1.2.3.4:443";
      expected = true;
    };
    testSecureSocketUrlQuicV6 = {
      expr = types.secureSocketUrl.check "quic://[::1]:443";
      expected = true;
    };
    testSecureSocketUrlPlaintextRejected = {
      expr = types.secureSocketUrl.check "tcp://1.2.3.4:443";
      expected = false;
    };
    testSecureSocketUrlUnixRejected = {
      expr = types.secureSocketUrl.check "unix:///run/foo.sock";
      expected = false;
    };
    testSecureSocketUrlMkOk = {
      expr = types.secureSocketUrl.mk "tls://1.2.3.4:443";
      expected = "tls://1.2.3.4:443";
    };
    testSecureSocketUrlMkBad = {
      expr = types.secureSocketUrl.mk "tcp://x:1";
      expectedError.msg = "^libnet\\.types\\.secureSocketUrl\\.mk: invalid value \"tcp://x:1\"$";
    };
    # `ssl` is an input spelling of `tls`; the merged value keeps it.
    testSecureSocketUrlMergeKeepsSpelling = {
      expr = merged types.secureSocketUrl "SSL://h:443";
      expected = "SSL://h:443";
    };
    testSecureSocketUrlDescription = {
      expr = builtins.isString types.secureSocketUrl.description;
      expected = true;
    };

    # ===== url =====
    testUrlHttpsOk = {
      expr = types.url.check "https://example.com/p?q=1#f";
      expected = true;
    };
    testUrlSchemeOk = {
      expr = types.url.check "redis://[::1]:6379";
      expected = true;
    };
    testUrlUnderscoreHost = {
      expr = types.url.check "http://my_host:8080/x";
      expected = true;
    };
    testUrlUnknownScheme = {
      expr = types.url.check "gopher://h";
      expected = false;
    };
    testUrlNoScheme = {
      expr = types.url.check "example.com/x";
      expected = false;
    };
    testUrlEmptyHost = {
      expr = types.url.check "https:///path";
      expected = false;
    };
    testUrlInt = {
      expr = types.url.check 42;
      expected = false;
    };
    testUrlPathSpaceRejected = {
      expr = types.url.check "https://example.com/a b";
      expected = false;
    };
    testUrlSecondHashRejected = {
      expr = types.url.check "https://example.com/p#a#b";
      expected = false;
    };
    testUrlMalformedPercentRejected = {
      expr = types.url.check "https://example.com/%zz";
      expected = false;
    };
    testUrlMkKeepsSpelling = {
      expr = types.url.mk "HTTPS://Example.COM/P?Q#F";
      expected = "HTTPS://Example.COM/P?Q#F";
    };
    testUrlMkOk = {
      expr = types.url.mk "https://example.com/p";
      expected = "https://example.com/p";
    };
    testUrlMkBad = {
      expr = throws (types.url.mk "gopher://h");
      expected = true;
    };
    testUrlDescription = {
      expr = builtins.isString types.url.description;
      expected = true;
    };

    # ===== urlHost =====
    testUrlHostIp = {
      expr = types.urlHost.check "1.2.3.4";
      expected = true;
    };
    testUrlHostBracketedV6 = {
      expr = types.urlHost.check "[::1]";
      expected = true;
    };
    testUrlHostRegName = {
      expr = types.urlHost.check "example.com";
      expected = true;
    };
    testUrlHostUnderscoreOk = {
      expr = types.urlHost.check "my_host";
      expected = true;
    }; # looser than host, which rejects underscores
    testUrlHostVsHost = {
      expr = types.host.check "my_host";
      expected = false;
    };
    testUrlHostBad = {
      expr = types.urlHost.check "bad host";
      expected = false;
    };
    testUrlHostInt = {
      expr = types.urlHost.check 42;
      expected = false;
    };
    testUrlHostMkOk = {
      expr = types.urlHost.mk "example.com";
      expected = "example.com";
    };
    testUrlHostMkBad = {
      expr = throws (types.urlHost.mk "bad host");
      expected = true;
    };
    testUrlHostDescription = {
      expr = builtins.isString types.urlHost.description;
      expected = true;
    };

    # ===== regName =====
    testRegNameOk = {
      expr = types.regName.check "my_host";
      expected = true;
    };
    testRegNamePercentEncoded = {
      expr = types.regName.check "a%20b";
      expected = true;
    };
    testRegNameIpv4 = {
      expr = types.regName.check "192.0.2.1";
      expected = false;
    };
    testRegNameNumericRejected = {
      expr = map types.regName.check [
        "127.1"
        "0x7f.0.0.1"
      ];
      expected = [
        false
        false
      ];
    };
    testRegNameBracketedV6 = {
      expr = types.regName.check "[::1]";
      expected = false;
    };
    testRegNameBad = {
      expr = types.regName.check "bad host";
      expected = false;
    };
    testRegNameInt = {
      expr = types.regName.check 42;
      expected = false;
    };
    testRegNameMkOk = {
      expr = types.regName.mk "my_host";
      expected = "my_host";
    };
    testRegNameMkBad = {
      expr = throws (types.regName.mk "bad host");
      expected = true;
    };
    testRegNameDescription = {
      expr = builtins.isString types.regName.description;
      expected = true;
    };

    # ===== authority =====
    testAuthorityHostOnly = {
      expr = types.authority.check "example.com";
      expected = true;
    };
    testAuthorityUserinfoPort = {
      expr = types.authority.check "user@example.com:8443";
      expected = true;
    };
    testAuthorityIpv6 = {
      expr = types.authority.check "[::1]:80";
      expected = true;
    };
    testAuthorityEmptyRejected = {
      expr = types.authority.check "";
      expected = false;
    };
    testAuthorityMultiAtRejected = {
      expr = types.authority.check "a@b@h";
      expected = false;
    };
    testAuthorityInt = {
      expr = types.authority.check 42;
      expected = false;
    };
    testAuthorityUserinfoSpaceRejected = {
      expr = types.authority.check "a b@h";
      expected = false;
    };
    testAuthorityUserinfoSlashRejected = {
      expr = types.authority.check "a/b@h";
      expected = false;
    };
    testAuthorityMkOk = {
      expr = types.authority.mk "user@h:80";
      expected = "user@h:80";
    };
    testAuthorityMkBad = {
      expr = throws (types.authority.mk "a@b@c");
      expected = true;
    };
    testAuthorityDescription = {
      expr = builtins.isString types.authority.description;
      expected = true;
    };

    # ===== proxyUrl =====
    testProxyUrlSocks5 = {
      expr = types.proxyUrl.check "socks5://127.0.0.1:1080";
      expected = true;
    };
    testProxyUrlHttpUserinfo = {
      expr = types.proxyUrl.check "http://user:pass@proxy:8080";
      expected = true;
    };
    testProxyUrlNoPortRejected = {
      expr = types.proxyUrl.check "socks5://127.0.0.1";
      expected = false;
    };
    testProxyUrlUnknownSchemeRejected = {
      expr = types.proxyUrl.check "ftp://h:1080";
      expected = false;
    };
    testProxyUrlBareSocksRejected = {
      expr = types.proxyUrl.check "socks://h:1080";
      expected = false;
    };
    testProxyUrlInt = {
      expr = types.proxyUrl.check 42;
      expected = false;
    };
    testProxyUrlMkOk = {
      expr = types.proxyUrl.mk "socks5://h:1080";
      expected = "socks5://h:1080";
    };
    testProxyUrlMkBad = {
      expr = types.proxyUrl.mk "socks5://h";
      expectedError.msg = "^libnet\\.types\\.proxyUrl\\.mk: invalid value \"socks5://h\"$";
    };
    testProxyUrlMkRejectsSet = {
      expr = types.proxyUrl.mk { };
      expectedError.msg = "^libnet\\.types\\.proxyUrl\\.mk: expected string, got set$";
    };
    testProxyUrlMergeKeepsSpelling = {
      expr = merged types.proxyUrl "Socks5://h:1080";
      expected = "Socks5://h:1080";
    };
    testProxyUrlDescription = {
      expr = builtins.isString types.proxyUrl.description;
      expected = true;
    };

    # ===== ipBindpoint =====
    testIpBindpointNoAddress = {
      expr = types.ipBindpoint.check ":80";
      expected = true;
    };
    testIpBindpointWildcard = {
      expr = types.ipBindpoint.check "*:80";
      expected = true;
    };
    testIpBindpointRange = {
      expr = types.ipBindpoint.check "1.2.3.4:80-90";
      expected = true;
    };
    testIpBindpointUnixRejected = {
      expr = types.ipBindpoint.check "/run/foo.sock";
      expected = false;
    };
    testIpBindpointMkBad = {
      expr = types.ipBindpoint.mk "::1:80";
      expectedError.msg = "^libnet\\.types\\.ipBindpoint\\.mk: invalid value \"::1:80\"$";
    };
    testIpBindpointDescription = {
      expr = builtins.isString types.ipBindpoint.description;
      expected = true;
    };

    # ===== bindpoint (union) =====
    testBindpointIp = {
      expr = types.bindpoint.check ":80";
      expected = true;
    };
    testBindpointWildcard = {
      expr = types.bindpoint.check "*:80";
      expected = true;
    };
    testBindpointRange = {
      expr = types.bindpoint.check "1.2.3.4:80-90";
      expected = true;
    };
    testBindpointUnix = {
      expr = types.bindpoint.check "/run/foo.sock";
      expected = true;
    };
    testBindpointUnixAbstract = {
      expr = types.bindpoint.check "@foo";
      expected = true;
    };
    testBindpointBad = {
      expr = types.bindpoint.check "host_name:1";
      expected = false;
    };
    testBindpointMkNameRejected = {
      expr = types.bindpoint.mk "localhost:80";
      expectedError.msg = "^libnet\\.types\\.bindpoint\\.mk: invalid value \"localhost:80\"$";
    };
    testBindpointMkUnix = {
      expr = types.bindpoint.mk "/run/foo.sock";
      expected = "/run/foo.sock";
    };
    testBindpointDescription = {
      expr = builtins.isString types.bindpoint.description;
      expected = true;
    };

    # ===== ipRange =====
    testIpRangeV4 = {
      expr = types.ipRange.check "1.2.3.4-1.2.3.10";
      expected = true;
    };
    testIpRangeV6 = {
      expr = types.ipRange.check "::1-::ff";
      expected = true;
    };
    testIpRangeBad = {
      expr = types.ipRange.check "1.2.3.4";
      expected = false;
    };
    testIpRangeRejectsReversedAndMixed = {
      expr = map types.ipRange.check [
        "1.2.3.10-1.2.3.4"
        "1.2.3.4-::1"
      ];
      expected = [
        false
        false
      ];
    };
    testIpRangeMkRejectsParsedValue = {
      expr = types.ipRange.mk (libnet.ipRange.parse "1.2.3.4-1.2.3.10");
      expectedError.msg = "^libnet\\.types\\.ipRange\\.mk: expected string, got ipRange value$";
    };

    # ===== interfaceAddress =====
    testInterfaceAddressV4 = {
      expr = types.interfaceAddress.check "10.0.0.5/24";
      expected = true;
    };
    testInterfaceAddressV6 = {
      expr = types.interfaceAddress.check "::1/64";
      expected = true;
    };
    testIpv4InterfaceAddressRejectsV6 = {
      expr = types.ipv4InterfaceAddress.check "::1/64";
      expected = false;
    };
    testIpv6InterfaceAddressRejectsV4 = {
      expr = types.ipv6InterfaceAddress.check "10.0.0.5/24";
      expected = false;
    };
    testInterfaceAddressTypesRejectParsedValue = {
      expr = map (type: type.check (libnet.interfaceAddress.parse "10.0.0.5/24")) [
        types.interfaceAddress
        types.ipv4InterfaceAddress
        types.ipv6InterfaceAddress
      ];
      expected = [
        false
        false
        false
      ];
    };
    testInterfaceAddressMergesToInput = {
      expr = merged types.ipv4InterfaceAddress "10.0.0.5/24";
      expected = "10.0.0.5/24";
    };

    # ===== interfaceName =====
    testInterfaceNameOk = {
      expr = types.interfaceName.check "eth0";
      expected = true;
    };
    testInterfaceNameMaxLength = {
      expr = types.interfaceName.check "abcdefghijklmno"; # 15 bytes
      expected = true;
    };
    testInterfaceNameEmpty = {
      expr = types.interfaceName.check "";
      expected = false;
    };
    testInterfaceNameTooLong = {
      expr = types.interfaceName.check "abcdefghijklmnop"; # 16 bytes
      expected = false;
    };
    testInterfaceNameDot = {
      expr = types.interfaceName.check ".";
      expected = false;
    };
    testInterfaceNameDotDot = {
      expr = types.interfaceName.check "..";
      expected = false;
    };
    testInterfaceNameSlash = {
      expr = types.interfaceName.check "eth/0";
      expected = false;
    };
    testInterfaceNameColon = {
      expr = types.interfaceName.check "eth:0";
      expected = false;
    };
    testInterfaceNameSpace = {
      expr = types.interfaceName.check "eth 0";
      expected = false;
    };
    testInterfaceNameInt = {
      expr = types.interfaceName.check 0;
      expected = false;
    };
    testInterfaceNameMkOk = {
      expr = types.interfaceName.mk "wg0";
      expected = "wg0";
    };
    testInterfaceNameMkBad = {
      expr = throws (types.interfaceName.mk "..");
      expected = true;
    };
    # The address-on-subnet form belongs to the `interfaceAddress` type.
    testInterfaceNameRejectsCidr = {
      expr = types.interfaceName.check "10.0.0.5/24";
      expected = false;
    };

    # ===== transport =====
    testTransportCheckTcp = {
      expr = types.transport.check "tcp";
      expected = true;
    };
    testTransportCheckUdp = {
      expr = types.transport.check "udp";
      expected = true;
    };
    testTransportCheckSctp = {
      expr = types.transport.check "sctp";
      expected = true;
    };
    testTransportCheckBad = {
      expr = types.transport.check "icmp";
      expected = false;
    };
    testTransportCheckUpper = {
      expr = types.transport.check "TCP";
      expected = false;
    };
    testTransportCheckInt = {
      expr = types.transport.check 6;
      expected = false;
    };
    testTransportMkOk = {
      expr = types.transport.mk "tcp";
      expected = "tcp";
    };
    testTransportMkBad = {
      expr = throws (types.transport.mk "icmp");
      expected = true;
    };
    testTransportDescription = {
      expr = builtins.isString types.transport.description;
      expected = true;
    };

    # ===== hostname =====
    testHostnameCheckOk = {
      expr = types.hostname.check "nas";
      expected = true;
    };
    testHostnameCheckHyphen = {
      expr = types.hostname.check "my-server";
      expected = true;
    };
    testHostnameCheckLeadingDigit = {
      expr = types.hostname.check "3com";
      expected = true;
    };
    testHostnameCheckAllDigits = {
      expr = types.hostname.check "1234";
      expected = true;
    };
    testHostnameCheckUnderscore = {
      expr = types.hostname.check "host_name";
      expected = false;
    };
    testHostnameCheckDot = {
      expr = types.hostname.check "host.example.com";
      expected = false;
    };
    testHostnameCheckEmpty = {
      expr = types.hostname.check "";
      expected = false;
    };
    testHostnameCheckInt = {
      expr = types.hostname.check 42;
      expected = false;
    };
    testHostnameMkOk = {
      expr = types.hostname.mk "MyHost";
      expected = "MyHost";
    };
    testHostnameMkBad = {
      expr = throws (types.hostname.mk "host_name");
      expected = true;
    };
    testHostnameDescription = {
      expr = builtins.isString types.hostname.description;
      expected = true;
    };

    # ===== domain =====
    testDomainCheckOk = {
      expr = types.domain.check "example.com";
      expected = true;
    };
    testDomainCheckThreeLabels = {
      expr = types.domain.check "foo.example.com";
      expected = true;
    };
    testDomainCheckMixedCase = {
      expr = types.domain.check "Example.COM";
      expected = true;
    };
    testDomainCheckSingleLabel = {
      expr = types.domain.check "example";
      expected = false;
    };
    testDomainCheckTrailingDot = {
      expr = types.domain.check "example.com.";
      expected = false;
    };
    # Reads as an IPv4 address (ADR 0021).
    testDomainCheckDottedQuad = {
      expr = types.domain.check "192.0.2.1";
      expected = false;
    };
    testDomainMkNumericThrows = {
      expr = types.domain.mk "127.1.0x1";
      expectedError.msg = "^libnet\\.types\\.domain\\.mk: invalid value \"127\\.1\\.0x1\"$";
    };
    testDomainCheckUnderscore = {
      expr = types.domain.check "host_name.com";
      expected = false;
    };
    testDomainCheckInt = {
      expr = types.domain.check 42;
      expected = false;
    };
    testDomainMkOk = {
      expr = types.domain.mk "example.com";
      expected = "example.com";
    };
    testDomainMkBad = {
      expr = throws (types.domain.mk "example");
      expected = true;
    };
    testDomainDescription = {
      expr = builtins.isString types.domain.description;
      expected = true;
    };

    # ===== dnsName =====
    testDnsNameCheckHostname = {
      expr = types.dnsName.check "nas";
      expected = true;
    };
    testDnsNameCheckDomain = {
      expr = types.dnsName.check "example.com";
      expected = true;
    };
    testDnsNameCheckIpRejected = {
      expr = types.dnsName.check "192.0.2.1";
      expected = false;
    };
    testDnsNameCheckNumericHostname = {
      expr = types.dnsName.check "2130706433";
      expected = false;
    };
    testDnsNameCheckBad = {
      expr = types.dnsName.check "host_name";
      expected = false;
    };
    testDnsNameCheckInt = {
      expr = types.dnsName.check 42;
      expected = false;
    };
    testDnsNameMkOk = {
      expr = types.dnsName.mk "pool.ntp.org";
      expected = "pool.ntp.org";
    };
    testDnsNameMkIpThrows = {
      expr = throws (types.dnsName.mk "192.0.2.1");
      expected = true;
    };
    testDnsNameDescription = {
      expr = builtins.isString types.dnsName.description;
      expected = true;
    };

    # ===== host =====
    testHostCheckIp = {
      expr = types.host.check "192.168.1.1";
      expected = true;
    };
    testHostCheckIpv6 = {
      expr = types.host.check "::1";
      expected = true;
    };
    testHostCheckHostname = {
      expr = types.host.check "nas";
      expected = true;
    };
    testHostCheckDomain = {
      expr = types.host.check "example.com";
      expected = true;
    };
    testHostCheckNumericName = {
      expr = map types.host.check [
        "010.0.0.1"
        "127.1"
        "0x7f"
      ];
      expected = [
        false
        false
        false
      ];
    };
    testHostCheckBad = {
      expr = types.host.check "host_name";
      expected = false;
    };
    testHostCheckEmpty = {
      expr = types.host.check "";
      expected = false;
    };
    testHostCheckInt = {
      expr = types.host.check 42;
      expected = false;
    };
    testHostMkIp = {
      expr = types.host.mk "192.168.1.1";
      expected = "192.168.1.1";
    };
    testHostMkHostname = {
      expr = types.host.mk "nas";
      expected = "nas";
    };
    testHostMkBad = {
      expr = throws (types.host.mk "host_name");
      expected = true;
    };
    testHostDescription = {
      expr = builtins.isString types.host.description;
      expected = true;
    };

    # ===== vlanId =====
    testVlanIdCheckTypical = {
      expr = types.vlanId.check 100;
      expected = true;
    };
    testVlanIdCheckMin = {
      expr = types.vlanId.check 1;
      expected = true;
    };
    testVlanIdCheckMax = {
      expr = types.vlanId.check 4094;
      expected = true;
    };
    testVlanIdCheckZero = {
      expr = types.vlanId.check 0;
      expected = false;
    };
    testVlanIdCheck4095 = {
      expr = types.vlanId.check 4095;
      expected = false;
    };
    testVlanIdCheckNegative = {
      expr = types.vlanId.check (-1);
      expected = false;
    };
    testVlanIdCheckString = {
      expr = types.vlanId.check "100";
      expected = true;
    };
    testVlanIdCheckRejectsLeadingZero = {
      expr = types.vlanId.check "0100";
      expected = false;
    };
    testVlanIdCheckRejectsInvalidStrings = {
      expr = builtins.any types.vlanId.check [
        "0"
        "4095"
        "-1"
        "abc"
        ""
      ];
      expected = false;
    };
    testVlanIdMergesStringToInt = {
      expr = merged types.vlanId "100";
      expected = 100;
    };
    testVlanIdMergesInt = {
      expr = merged types.vlanId 100;
      expected = 100;
    };
    testVlanIdMergeRejectsInvalidString = {
      expr = throws (merged types.vlanId "0");
      expected = true;
    };
    testVlanIdCheckRejectsOtherTypes = {
      expr = builtins.any types.vlanId.check [
        null
        true
        100.0
        [ 100 ]
        {
          _type = "vlanId";
          value = 100;
        }
      ];
      expected = false;
    };
    testVlanIdMkRejectsOtherTypes = {
      expr = builtins.all (value: throws (types.vlanId.mk value)) [
        null
        true
        100.0
        [ 100 ]
        {
          _type = "vlanId";
          value = 100;
        }
      ];
      expected = true;
    };
    testVlanIdMkOk = {
      expr = types.vlanId.mk 100;
      expected = 100;
    };
    testVlanIdMkMin = {
      expr = types.vlanId.mk 1;
      expected = 1;
    };
    testVlanIdMkMax = {
      expr = types.vlanId.mk 4094;
      expected = 4094;
    };
    testVlanIdMkZeroThrows = {
      expr = types.vlanId.mk 0;
      expectedError.msg = "^libnet\\.types\\.vlanId\\.mk: out of range \\[1, 4094\\]: 0$";
    };
    testVlanIdMk4095Throws = {
      expr = types.vlanId.mk 4095;
      expectedError.msg = "^libnet\\.types\\.vlanId\\.mk: out of range \\[1, 4094\\]: 4095$";
    };
    testVlanIdMkString = {
      expr = types.vlanId.mk "100";
      expected = 100;
    };
    testVlanIdMkInvalidStringThrows = {
      expr = types.vlanId.mk "0";
      expectedError.msg = "^libnet\\.types\\.vlanId\\.mk: invalid value \"0\"$";
    };
    testVlanIdDescription = {
      expr = builtins.isString types.vlanId.description;
      expected = true;
    };

    # ===== mtu =====
    testMtuCheckEthernet = {
      expr = types.mtu.check 1500;
      expected = true;
    };
    testMtuCheckJumbo = {
      expr = types.mtu.check 9000;
      expected = true;
    };
    testMtuCheckMin = {
      expr = types.mtu.check 68;
      expected = true;
    };
    testMtuCheckMax = {
      expr = types.mtu.check 65535;
      expected = true;
    };
    testMtuCheckBelowMin = {
      expr = types.mtu.check 67;
      expected = false;
    };
    testMtuCheckAboveMax = {
      expr = types.mtu.check 65536;
      expected = false;
    };
    testMtuCheckZero = {
      expr = types.mtu.check 0;
      expected = false;
    };
    testMtuCheckString = {
      expr = types.mtu.check "1500";
      expected = true;
    };
    testMtuCheckRejectsInvalidStrings = {
      expr = builtins.any types.mtu.check [
        "67"
        "65536"
        "-1"
        "abc"
        ""
      ];
      expected = false;
    };
    testMtuMergesStringToInt = {
      expr = merged types.mtu "1500";
      expected = 1500;
    };
    testMtuMergesInt = {
      expr = merged types.mtu 1500;
      expected = 1500;
    };
    testMtuMergeRejectsInvalidString = {
      expr = throws (merged types.mtu "67");
      expected = true;
    };
    testMtuCheckRejectsOtherTypes = {
      expr = builtins.any types.mtu.check [
        null
        true
        1500.0
        [ 1500 ]
        {
          _type = "mtu";
          value = 1500;
        }
      ];
      expected = false;
    };
    testMtuMkRejectsOtherTypes = {
      expr = builtins.all (value: throws (types.mtu.mk value)) [
        null
        true
        1500.0
        [ 1500 ]
        {
          _type = "mtu";
          value = 1500;
        }
      ];
      expected = true;
    };
    testMtuMkOk = {
      expr = types.mtu.mk 1500;
      expected = 1500;
    };
    testMtuMkMin = {
      expr = types.mtu.mk 68;
      expected = 68;
    };
    testMtuMkMax = {
      expr = types.mtu.mk 65535;
      expected = 65535;
    };
    testMtuMkBelowThrows = {
      expr = types.mtu.mk 67;
      expectedError.msg = "^libnet\\.types\\.mtu\\.mk: out of range \\[68, 65535\\]: 67$";
    };
    testMtuMkAboveThrows = {
      expr = types.mtu.mk 65536;
      expectedError.msg = "^libnet\\.types\\.mtu\\.mk: out of range \\[68, 65535\\]: 65536$";
    };
    testMtuMkString = {
      expr = types.mtu.mk "1500";
      expected = 1500;
    };
    testMtuMkInvalidStringThrows = {
      expr = types.mtu.mk "67";
      expectedError.msg = "^libnet\\.types\\.mtu\\.mk: invalid value \"67\"$";
    };
    testMtuDescription = {
      expr = builtins.isString types.mtu.description;
      expected = true;
    };

    # ===== icmpType =====
    testIcmpTypeCheckTypical = {
      expr = types.icmpType.check 8;
      expected = true;
    };
    testIcmpTypeCheckMin = {
      expr = types.icmpType.check 0;
      expected = true;
    };
    testIcmpTypeCheckMax = {
      expr = types.icmpType.check 255;
      expected = true;
    };
    testIcmpTypeCheck256 = {
      expr = types.icmpType.check 256;
      expected = false;
    };
    testIcmpTypeCheckNegative = {
      expr = types.icmpType.check (-1);
      expected = false;
    };
    testIcmpTypeCheckString = {
      expr = types.icmpType.check "8";
      expected = true;
    };
    testIcmpTypeCheckRejectsInvalidStrings = {
      expr = builtins.any types.icmpType.check [
        "256"
        "-1"
        "abc"
        ""
      ];
      expected = false;
    };
    testIcmpTypeMergesStringToInt = {
      expr = merged types.icmpType "8";
      expected = 8;
    };
    testIcmpTypeMergesInt = {
      expr = merged types.icmpType 8;
      expected = 8;
    };
    testIcmpTypeMergeRejectsInvalidString = {
      expr = throws (merged types.icmpType "256");
      expected = true;
    };
    testIcmpTypeCheckRejectsOtherTypes = {
      expr = builtins.any types.icmpType.check [
        null
        true
        8.0
        [ 8 ]
        {
          _type = "icmpType";
          value = 8;
        }
      ];
      expected = false;
    };
    testIcmpTypeMkRejectsOtherTypes = {
      expr = builtins.all (value: throws (types.icmpType.mk value)) [
        null
        true
        8.0
        [ 8 ]
        {
          _type = "icmpType";
          value = 8;
        }
      ];
      expected = true;
    };
    testIcmpTypeMkOk = {
      expr = types.icmpType.mk 8;
      expected = 8;
    };
    testIcmpTypeMkMin = {
      expr = types.icmpType.mk 0;
      expected = 0;
    };
    testIcmpTypeMkMax = {
      expr = types.icmpType.mk 255;
      expected = 255;
    };
    testIcmpTypeMk256Throws = {
      expr = types.icmpType.mk 256;
      expectedError.msg = "^libnet\\.types\\.icmpType\\.mk: out of range \\[0, 255\\]: 256$";
    };
    testIcmpTypeMkNegativeThrows = {
      expr = types.icmpType.mk (-1);
      expectedError.msg = "^libnet\\.types\\.icmpType\\.mk: out of range \\[0, 255\\]: -1$";
    };
    testIcmpTypeMkString = {
      expr = types.icmpType.mk "8";
      expected = 8;
    };
    testIcmpTypeMkInvalidStringThrows = {
      expr = types.icmpType.mk "256";
      expectedError.msg = "^libnet\\.types\\.icmpType\\.mk: invalid value \"256\"$";
    };
    testIcmpTypeDescription = {
      expr = builtins.isString types.icmpType.description;
      expected = true;
    };
    testIcmpTypeRegistryV4 = {
      expr = allIcmpTypesCheck registry.icmpTypes.ipv4;
      expected = true;
    };
    testIcmpTypeRegistryV6 = {
      expr = allIcmpTypesCheck registry.icmpTypes.ipv6;
      expected = true;
    };

    # ===== .mk smart constructors =====
    # `mk` returns its input as written, without normalizing it.
    testMkPreservesCase = {
      expr = types.mac.mk "AA:BB:CC:DD:EE:FF";
      expected = "AA:BB:CC:DD:EE:FF";
    };
    # Parsing folds the case of names (ADR 0020), but string types merge
    # to the definition as written (ADR 0016).
    testMergeKeepsNameSpelling = {
      expr = map ({ type, value }: merged types.${type} value) [
        {
          type = "hostname";
          value = "MyHost";
        }
        {
          type = "domain";
          value = "Example.COM";
        }
        {
          type = "dnsName";
          value = "Pool.NTP.org";
        }
        {
          type = "host";
          value = "NAS";
        }
        {
          type = "regName";
          value = "My_Host%2f";
        }
        {
          type = "urlHost";
          value = "Example.COM";
        }
        {
          type = "interfaceName";
          value = "Eth0";
        }
        {
          type = "url";
          value = "https://Example.COM/Path";
        }
      ];
      expected = [
        "MyHost"
        "Example.COM"
        "Pool.NTP.org"
        "NAS"
        "My_Host%2f"
        "Example.COM"
        "Eth0"
        "https://Example.COM/Path"
      ];
    };
    testInterfaceNameCheckByte160 = {
      expr = types.interfaceName.check "wlà0";
      expected = false;
    };
    testMkCidrThrowsBad = {
      expr = throws (types.cidr.mk "bad");
      expected = true;
    };
    testMkCidrWrongFamily = {
      expr = throws (types.ipv4Cidr.mk "::/0");
      expected = true;
    };
  }
