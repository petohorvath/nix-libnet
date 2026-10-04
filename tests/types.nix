{ harness, lib }:
let
  types = ((import ../.).withLib lib).types;
  registry = import ../lib/registry.nix;
  inherit (harness) throws;

  # Registry ↔ type cross-check: the curated vocabulary always
  # satisfies the type that validates its value space.
  allIcmpTypesCheck =
    icmpTypes:
    builtins.all (name: types.icmpType.check icmpTypes.${name}) (builtins.attrNames icmpTypes);
in
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
  testPortMkInt = {
    expr = types.port.mk 80;
    expected = 80;
  };
  testPortMkString = {
    expr = types.port.mk "80";
    expected = 80;
  };
  testPortMkBadInt = {
    expr = throws (types.port.mk 70000);
    expected = true;
  };
  testPortMkBadString = {
    expr = throws (types.port.mk "abc");
    expected = true;
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
  testPortRangeBad = {
    expr = types.portRange.check "90-80";
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
    expr = throws (types.unixSocket.mk "foo.sock");
    expected = true;
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
    expr = throws (types.socketUrl.mk "ftp://x:1");
    expected = true;
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
    expr = throws (types.bindUrl.mk "ftp://:1");
    expected = true;
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
    expr = throws (types.secureSocketUrl.mk "tcp://x:1");
    expected = true;
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
    expr = throws (types.proxyUrl.mk "socks5://h");
    expected = true;
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
    expected = false;
  };
  testVlanIdCheckRejectsNonInts = {
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
  testVlanIdMkRejectsNonInts = {
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
    expr = throws (types.vlanId.mk 0);
    expected = true;
  };
  testVlanIdMk4095Throws = {
    expr = throws (types.vlanId.mk 4095);
    expected = true;
  };
  testVlanIdMkStringThrows = {
    expr = throws (types.vlanId.mk "100");
    expected = true;
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
    expected = false;
  };
  testMtuCheckRejectsNonInts = {
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
  testMtuMkRejectsNonInts = {
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
    expr = throws (types.mtu.mk 67);
    expected = true;
  };
  testMtuMkAboveThrows = {
    expr = throws (types.mtu.mk 65536);
    expected = true;
  };
  testMtuMkStringThrows = {
    expr = throws (types.mtu.mk "1500");
    expected = true;
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
    expected = false;
  };
  testIcmpTypeCheckRejectsNonInts = {
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
  testIcmpTypeMkRejectsNonInts = {
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
    expr = throws (types.icmpType.mk 256);
    expected = true;
  };
  testIcmpTypeMkNegativeThrows = {
    expr = throws (types.icmpType.mk (-1));
    expected = true;
  };
  testIcmpTypeMkStringThrows = {
    expr = throws (types.icmpType.mk "8");
    expected = true;
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
  testMkCidrThrowsBad = {
    expr = throws (types.cidr.mk "bad");
    expected = true;
  };
  testMkCidrWrongFamily = {
    expr = throws (types.ipv4Cidr.mk "::/0");
    expected = true;
  };
}
