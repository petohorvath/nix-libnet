let
  tags = {
    ipv4 = "ipv4";
    ipv6 = "ipv6";
    mac = "mac";
    cidr = "cidr";
    port = "port";
    portRange = "portRange";
    ipEndpoint = "ipEndpoint";
    dnsEndpoint = "dnsEndpoint";
    ipBindpoint = "ipBindpoint";
    ipRange = "ipRange";
    interfaceAddress = "interfaceAddress";
    interfaceName = "interfaceName";
    transport = "transport";
    hostname = "hostname";
    domain = "domain";
    vlanId = "vlanId";
    mtu = "mtu";
    icmpType = "icmpType";
    unixSocket = "unixSocket";
    socketUrl = "socketUrl";
    bindUrl = "bindUrl";
    secureSocketUrl = "secureSocketUrl";
    url = "url";
    urlHost = "urlHost";
    authority = "authority";
    proxyUrl = "proxyUrl";
  };

  hasTag = tag: value: builtins.isAttrs value && value ? _type && value._type == tag;

  # Guards `eq`, which must return false rather than throw for untagged
  # operands.
  hasSameTag = a: b: builtins.isAttrs b && b ? _type && hasTag b._type a;

  isIpv4 = hasTag tags.ipv4;
  isIpv6 = hasTag tags.ipv6;
  isMac = hasTag tags.mac;
  isCidr = hasTag tags.cidr;
  isPort = hasTag tags.port;
  isPortRange = hasTag tags.portRange;
  isIpEndpoint = hasTag tags.ipEndpoint;
  isDnsEndpoint = hasTag tags.dnsEndpoint;
  isIpBindpoint = hasTag tags.ipBindpoint;
  isIpRange = hasTag tags.ipRange;
  isInterfaceAddress = hasTag tags.interfaceAddress;
  isInterfaceName = hasTag tags.interfaceName;
  isTransport = hasTag tags.transport;
  isHostname = hasTag tags.hostname;
  isDomain = hasTag tags.domain;
  isVlanId = hasTag tags.vlanId;
  isMtu = hasTag tags.mtu;
  isIcmpType = hasTag tags.icmpType;
  isUnixSocket = hasTag tags.unixSocket;
  isSocketUrl = hasTag tags.socketUrl;
  isBindUrl = hasTag tags.bindUrl;
  isSecureSocketUrl = hasTag tags.secureSocketUrl;
  isUrl = hasTag tags.url;
  isUrlHost = hasTag tags.urlHost;
  isAuthority = hasTag tags.authority;
  isProxyUrl = hasTag tags.proxyUrl;
  isIp = value: isIpv4 value || isIpv6 value;

  tryOk = value: {
    success = true;
    inherit value;
    error = null;
  };
  tryErr = error: {
    success = false;
    value = null;
    inherit error;
  };

  ensureTag =
    tag: context: value:
    if hasTag tag value then
      value
    else
      throw "libnet: ${context}: expected ${tag} value, got ${
        if builtins.isAttrs value && value ? _type then "${value._type} value" else builtins.typeOf value
      }";
in
{
  inherit
    ensureTag
    hasSameTag
    hasTag
    isAuthority
    isBindUrl
    isCidr
    isDnsEndpoint
    isDomain
    isHostname
    isIcmpType
    isInterfaceAddress
    isInterfaceName
    isIp
    isIpBindpoint
    isIpEndpoint
    isIpRange
    isIpv4
    isIpv6
    isMac
    isMtu
    isPort
    isPortRange
    isProxyUrl
    isSecureSocketUrl
    isSocketUrl
    isTransport
    isUnixSocket
    isUrl
    isUrlHost
    isVlanId
    tags
    tryErr
    tryOk
    ;
}
