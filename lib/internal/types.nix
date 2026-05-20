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
    ipListener = "ipListener";
    ipRange = "ipRange";
    interface = "interface";
    transport = "transport";
    hostname = "hostname";
    domain = "domain";
    vlanId = "vlanId";
    mtu = "mtu";
    unixSocket = "unixSocket";
    socketUrl = "socketUrl";
    secureSocketUrl = "secureSocketUrl";
    url = "url";
    urlHost = "urlHost";
    authority = "authority";
    proxyUrl = "proxyUrl";
  };

  hasTag = tag: v: builtins.isAttrs v && v ? _type && v._type == tag;

  isIpv4 = hasTag tags.ipv4;
  isIpv6 = hasTag tags.ipv6;
  isMac = hasTag tags.mac;
  isCidr = hasTag tags.cidr;
  isPort = hasTag tags.port;
  isPortRange = hasTag tags.portRange;
  isIpEndpoint = hasTag tags.ipEndpoint;
  isDnsEndpoint = hasTag tags.dnsEndpoint;
  isIpListener = hasTag tags.ipListener;
  isIpRange = hasTag tags.ipRange;
  isInterface = hasTag tags.interface;
  isTransport = hasTag tags.transport;
  isHostname = hasTag tags.hostname;
  isDomain = hasTag tags.domain;
  isVlanId = hasTag tags.vlanId;
  isMtu = hasTag tags.mtu;
  isUnixSocket = hasTag tags.unixSocket;
  isSocketUrl = hasTag tags.socketUrl;
  isSecureSocketUrl = hasTag tags.secureSocketUrl;
  isUrl = hasTag tags.url;
  isUrlHost = hasTag tags.urlHost;
  isAuthority = hasTag tags.authority;
  isProxyUrl = hasTag tags.proxyUrl;
  isIp = v: isIpv4 v || isIpv6 v;

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
    tag: ctx: v:
    if hasTag tag v then
      v
    else
      builtins.throw "libnet: ${ctx}: expected ${tag} value, got ${
        if builtins.isAttrs v && v ? _type then "${v._type} value" else builtins.typeOf v
      }";
in
{
  inherit tags hasTag;
  inherit
    isIpv4
    isIpv6
    isMac
    isCidr
    isPort
    isPortRange
    isIpEndpoint
    isDnsEndpoint
    isIpListener
    isIpRange
    isInterface
    isTransport
    isHostname
    isDomain
    isVlanId
    isMtu
    isUnixSocket
    isSocketUrl
    isSecureSocketUrl
    isUrl
    isUrlHost
    isAuthority
    isProxyUrl
    isIp
    ;
  inherit tryOk tryErr ensureTag;
}
