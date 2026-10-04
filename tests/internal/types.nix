{ harness }:
let
  types = import ../../lib/internal/types.nix;
  inherit (harness) throws;

  # Minimal tagged fixtures — only _type matters for this module.
  ipv4 = {
    _type = "ipv4";
    value = 0;
  };
  ipv6 = {
    _type = "ipv6";
    words = [
      0
      0
      0
      0
    ];
  };
  mac = {
    _type = "mac";
    value = 0;
  };
  cidr = {
    _type = "cidr";
    address = ipv4;
    prefix = 24;
  };
  port = {
    _type = "port";
    value = 80;
  };
  portRange = {
    _type = "portRange";
    from = port;
    to = port;
  };
  ipEndpoint = {
    _type = "ipEndpoint";
    address = ipv4;
    inherit port;
  };
  dnsEndpoint = {
    _type = "dnsEndpoint";
    address = {
      _type = "domain";
      value = "example.com";
    };
    inherit port;
  };
  ipBindpoint = {
    _type = "ipBindpoint";
    address = ipv4;
    inherit portRange;
  };
  ipRange = {
    _type = "ipRange";
    from = ipv4;
    to = ipv4;
  };
  interfaceAddress = {
    _type = "interfaceAddress";
    address = ipv4;
    prefix = 24;
  };
  interfaceName = {
    _type = "interfaceName";
    value = "eth0";
  };
  transport = {
    _type = "transport";
    value = "tcp";
  };
  hostname = {
    _type = "hostname";
    value = "nas";
  };
  domain = {
    _type = "domain";
    value = "example.com";
  };
  vlanId = {
    _type = "vlanId";
    value = 100;
  };
  mtu = {
    _type = "mtu";
    value = 1500;
  };
  icmpType = {
    _type = "icmpType";
    value = 8;
  };
  unixSocket = {
    _type = "unixSocket";
    path = "/run/foo.sock";
  };
  socketUrl = {
    _type = "socketUrl";
    transport = null;
    endpoint = unixSocket;
  };
  bindUrl = {
    _type = "bindUrl";
    transport = null;
    bindpoint = unixSocket;
  };
  secureSocketUrl = {
    _type = "secureSocketUrl";
    scheme = "tls";
    endpoint = ipEndpoint;
  };
  urlHost = {
    _type = "urlHost";
    kind = "regName";
    ip = null;
    name = "example.com";
  };
  url = {
    _type = "url";
    scheme = "https";
    userinfo = null;
    host = urlHost;
    port = null;
    path = "";
    query = null;
    fragment = null;
  };
  authority = {
    _type = "authority";
    userinfo = null;
    host = urlHost;
    inherit port;
  };
  proxyUrl = {
    _type = "proxyUrl";
    scheme = "socks5";
    inherit authority;
  };

  untagged = {
    value = 0;
  };
in
{
  # ===== tags =====
  testTagsIpv4 = {
    expr = types.tags.ipv4;
    expected = "ipv4";
  };
  testTagsIpv6 = {
    expr = types.tags.ipv6;
    expected = "ipv6";
  };
  testTagsMac = {
    expr = types.tags.mac;
    expected = "mac";
  };
  testTagsCidr = {
    expr = types.tags.cidr;
    expected = "cidr";
  };
  testTagsPort = {
    expr = types.tags.port;
    expected = "port";
  };
  testTagsPortRange = {
    expr = types.tags.portRange;
    expected = "portRange";
  };
  testTagsIpEndpoint = {
    expr = types.tags.ipEndpoint;
    expected = "ipEndpoint";
  };
  testTagsDnsEndpoint = {
    expr = types.tags.dnsEndpoint;
    expected = "dnsEndpoint";
  };
  testTagsIpBindpoint = {
    expr = types.tags.ipBindpoint;
    expected = "ipBindpoint";
  };
  testTagsIpRange = {
    expr = types.tags.ipRange;
    expected = "ipRange";
  };
  testTagsInterfaceAddress = {
    expr = types.tags.interfaceAddress;
    expected = "interfaceAddress";
  };
  testTagsInterfaceName = {
    expr = types.tags.interfaceName;
    expected = "interfaceName";
  };
  testTagsTransport = {
    expr = types.tags.transport;
    expected = "transport";
  };
  testTagsHostname = {
    expr = types.tags.hostname;
    expected = "hostname";
  };
  testTagsDomain = {
    expr = types.tags.domain;
    expected = "domain";
  };
  testTagsVlanId = {
    expr = types.tags.vlanId;
    expected = "vlanId";
  };
  testTagsMtu = {
    expr = types.tags.mtu;
    expected = "mtu";
  };
  testTagsIcmpType = {
    expr = types.tags.icmpType;
    expected = "icmpType";
  };
  testTagsUnixSocket = {
    expr = types.tags.unixSocket;
    expected = "unixSocket";
  };
  testTagsSocketUrl = {
    expr = types.tags.socketUrl;
    expected = "socketUrl";
  };
  testTagsBindUrl = {
    expr = types.tags.bindUrl;
    expected = "bindUrl";
  };
  testTagsSecureSocketUrl = {
    expr = types.tags.secureSocketUrl;
    expected = "secureSocketUrl";
  };
  testTagsUrl = {
    expr = types.tags.url;
    expected = "url";
  };
  testTagsUrlHost = {
    expr = types.tags.urlHost;
    expected = "urlHost";
  };
  testTagsAuthority = {
    expr = types.tags.authority;
    expected = "authority";
  };
  testTagsProxyUrl = {
    expr = types.tags.proxyUrl;
    expected = "proxyUrl";
  };

  # ===== hasTag =====
  testHasTagMatch = {
    expr = types.hasTag "ipv4" ipv4;
    expected = true;
  };
  testHasTagMismatch = {
    expr = types.hasTag "ipv6" ipv4;
    expected = false;
  };
  testHasTagUntagged = {
    expr = types.hasTag "ipv4" untagged;
    expected = false;
  };
  testHasTagString = {
    expr = types.hasTag "ipv4" "1.2.3.4";
    expected = false;
  };
  testHasTagInt = {
    expr = types.hasTag "ipv4" 42;
    expected = false;
  };
  testHasTagNull = {
    expr = types.hasTag "ipv4" null;
    expected = false;
  };

  # ===== is* predicates: positive =====
  testIsIpv4Yes = {
    expr = types.isIpv4 ipv4;
    expected = true;
  };
  testIsIpv6Yes = {
    expr = types.isIpv6 ipv6;
    expected = true;
  };
  testIsMacYes = {
    expr = types.isMac mac;
    expected = true;
  };
  testIsCidrYes = {
    expr = types.isCidr cidr;
    expected = true;
  };
  testIsPortYes = {
    expr = types.isPort port;
    expected = true;
  };
  testIsPortRangeYes = {
    expr = types.isPortRange portRange;
    expected = true;
  };
  testIsIpEndpointYes = {
    expr = types.isIpEndpoint ipEndpoint;
    expected = true;
  };
  testIsDnsEndpointYes = {
    expr = types.isDnsEndpoint dnsEndpoint;
    expected = true;
  };
  testIsIpBindpointYes = {
    expr = types.isIpBindpoint ipBindpoint;
    expected = true;
  };
  testIsIpRangeYes = {
    expr = types.isIpRange ipRange;
    expected = true;
  };
  testIsInterfaceAddressYes = {
    expr = types.isInterfaceAddress interfaceAddress;
    expected = true;
  };
  testIsInterfaceNameYes = {
    expr = types.isInterfaceName interfaceName;
    expected = true;
  };
  testIsTransportYes = {
    expr = types.isTransport transport;
    expected = true;
  };
  testIsHostnameYes = {
    expr = types.isHostname hostname;
    expected = true;
  };
  testIsDomainYes = {
    expr = types.isDomain domain;
    expected = true;
  };
  testIsVlanIdYes = {
    expr = types.isVlanId vlanId;
    expected = true;
  };
  testIsMtuYes = {
    expr = types.isMtu mtu;
    expected = true;
  };
  testIsIcmpTypeYes = {
    expr = types.isIcmpType icmpType;
    expected = true;
  };
  testIsUnixSocketYes = {
    expr = types.isUnixSocket unixSocket;
    expected = true;
  };
  testIsSocketUrlYes = {
    expr = types.isSocketUrl socketUrl;
    expected = true;
  };
  testIsBindUrlYes = {
    expr = types.isBindUrl bindUrl;
    expected = true;
  };
  testIsSecureSocketUrlYes = {
    expr = types.isSecureSocketUrl secureSocketUrl;
    expected = true;
  };
  testIsUrlYes = {
    expr = types.isUrl url;
    expected = true;
  };
  testIsUrlHostYes = {
    expr = types.isUrlHost urlHost;
    expected = true;
  };
  testIsAuthorityYes = {
    expr = types.isAuthority authority;
    expected = true;
  };
  testIsProxyUrlYes = {
    expr = types.isProxyUrl proxyUrl;
    expected = true;
  };

  # ===== is* predicates: cross-tag negative =====
  testIsIpv4NotV6 = {
    expr = types.isIpv4 ipv6;
    expected = false;
  };
  testIsIpv6NotV4 = {
    expr = types.isIpv6 ipv4;
    expected = false;
  };
  testIsCidrNotRange = {
    expr = types.isCidr ipRange;
    expected = false;
  };

  # ===== is* predicates: non-attrs =====
  testIsIpv4String = {
    expr = types.isIpv4 "1.2.3.4";
    expected = false;
  };
  testIsMacInt = {
    expr = types.isMac 42;
    expected = false;
  };
  testIsPortNull = {
    expr = types.isPort null;
    expected = false;
  };
  testIsIpEndpointUntagged = {
    expr = types.isIpEndpoint untagged;
    expected = false;
  };

  # ===== isIp (union) =====
  testIsIpV4 = {
    expr = types.isIp ipv4;
    expected = true;
  };
  testIsIpV6 = {
    expr = types.isIp ipv6;
    expected = true;
  };
  testIsIpMac = {
    expr = types.isIp mac;
    expected = false;
  };
  testIsIpString = {
    expr = types.isIp "1.2.3.4";
    expected = false;
  };

  # ===== tryOk / tryErr =====
  testTryOkSuccess = {
    expr = (types.tryOk 42).success;
    expected = true;
  };
  testTryOkValue = {
    expr = (types.tryOk 42).value;
    expected = 42;
  };
  testTryOkError = {
    expr = (types.tryOk 42).error;
    expected = null;
  };
  testTryErrSuccess = {
    expr = (types.tryErr "boom").success;
    expected = false;
  };
  testTryErrValue = {
    expr = (types.tryErr "boom").value;
    expected = null;
  };
  testTryErrError = {
    expr = (types.tryErr "boom").error;
    expected = "boom";
  };

  # ===== ensureTag =====
  testEnsureTagReturnsInput = {
    expr = types.ensureTag "ipv4" "libnet.test" ipv4 == ipv4;
    expected = true;
  };
  testEnsureTagWrongTagThrows = {
    expr = throws (types.ensureTag "ipv4" "libnet.test" ipv6);
    expected = true;
  };
  testEnsureTagUntaggedThrows = {
    expr = throws (types.ensureTag "ipv4" "libnet.test" untagged);
    expected = true;
  };
  testEnsureTagNonAttrsThrows = {
    expr = throws (types.ensureTag "ipv4" "libnet.test" 42);
    expected = true;
  };
  testEnsureTagStringThrows = {
    expr = throws (types.ensureTag "ipv4" "libnet.test" "1.2.3.4");
    expected = true;
  };
}
