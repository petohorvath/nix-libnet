/*
  libnet.types

  NixOS option-type integration. Exposes a `libnet.types.<name>`
  option type for each libnet value — backed by that value's
  validator and paired with a `.mk` coercer that validates its input.
  The `types` attrset below is the authoritative list.

  Requires `nixpkgs.lib`. This and `lib/with-lib.nix` are the only
  files allowed to consume injected lib; reach this module only
  through `libnet.withLib pkgs.lib`.

  Example:
    (libnet.withLib pkgs.lib).types.ipv4.mk "192.0.2.1"
    => "192.0.2.1"
*/
{ lib }:
let
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  ip = import ./ip.nix;
  mac = import ./mac.nix;
  cidr = import ./cidr.nix;
  portRange = import ./port-range.nix;
  ipEndpoint = import ./ip-endpoint.nix;
  dnsEndpoint = import ./dns-endpoint.nix;
  endpoint = import ./endpoint.nix;
  unixSocket = import ./unix-socket.nix;
  socketUrl = import ./socket-url.nix;
  bindUrl = import ./bind-url.nix;
  secureSocketUrl = import ./secure-socket-url.nix;
  url = import ./url.nix;
  urlHost = import ./url-host.nix;
  authority = import ./authority.nix;
  proxyUrl = import ./proxy-url.nix;
  ipBindpoint = import ./ip-bindpoint.nix;
  bindpoint = import ./bindpoint.nix;
  ipRange = import ./ip-range.nix;
  interfaceAddress = import ./interface-address.nix;
  interfaceName = import ./interface-name.nix;
  port = import ./port.nix;
  transport = import ./transport.nix;
  hostname = import ./hostname.nix;
  domain = import ./domain.nix;
  dnsName = import ./dns-name.nix;
  host = import ./host.nix;
  vlanId = import ./vlan-id.nix;
  mtu = import ./mtu.nix;
  icmpType = import ./icmp-type.nix;

  # Factory for string-typed module types.
  mkStrType =
    {
      typeName,
      description,
      validator,
    }:
    let
      t = lib.types.mkOptionType {
        name = typeName;
        inherit description;
        descriptionClass = "noun";
        check = v: builtins.isString v && validator v;
        merge = lib.options.mergeEqualOption;
      };
    in
    t
    // {
      mk =
        s:
        if !(builtins.isString s) then
          builtins.throw "libnet.types.${typeName}.mk: expected string, got ${builtins.typeOf s}"
        else if !(validator s) then
          builtins.throw "libnet.types.${typeName}.mk: invalid value \"${s}\""
        else
          s;
    };

  ipv4Type = mkStrType {
    typeName = "ipv4";
    description = "an IPv4 address (dotted-quad)";
    validator = ipv4.isValid;
  };

  ipv6Type = mkStrType {
    typeName = "ipv6";
    description = "an IPv6 address";
    validator = ipv6.isValid;
  };

  ipType = mkStrType {
    typeName = "ip";
    description = "an IPv4 or IPv6 address";
    validator = ip.isValid;
  };

  macType = mkStrType {
    typeName = "mac";
    description = "a MAC address (EUI-48, colon/hyphen/dot/bare)";
    validator = mac.isValid;
  };

  cidrType = mkStrType {
    typeName = "cidr";
    description = "a CIDR block (address/prefix)";
    validator = cidr.isValid;
  };

  ipv4CidrType = mkStrType {
    typeName = "ipv4Cidr";
    description = "an IPv4 CIDR block";
    validator = s: cidr.isValid s && cidr.isIpv4 (cidr.parse s);
  };

  ipv6CidrType = mkStrType {
    typeName = "ipv6Cidr";
    description = "an IPv6 CIDR block";
    validator = s: cidr.isValid s && cidr.isIpv6 (cidr.parse s);
  };

  portRangeType = mkStrType {
    typeName = "portRange";
    description = "a port or port range (80 or 5500-6000)";
    validator = portRange.isValid;
  };

  ipEndpointType = mkStrType {
    typeName = "ipEndpoint";
    description = "an IP endpoint (addr:port or [ipv6]:port)";
    validator = ipEndpoint.isValid;
  };

  dnsEndpointType = mkStrType {
    typeName = "dnsEndpoint";
    description = "a DNS-name endpoint (name:port; not an IP literal)";
    validator = dnsEndpoint.isValid;
  };

  endpointType = mkStrType {
    typeName = "endpoint";
    description = "an endpoint (IP or DNS name : port)";
    validator = endpoint.isValid;
  };

  unixSocketType = mkStrType {
    typeName = "unixSocket";
    description = "a Unix domain socket (absolute path or @abstract name)";
    validator = unixSocket.isValid;
  };

  socketUrlType = mkStrType {
    typeName = "socketUrl";
    description = "a socket URL (<scheme>://<endpoint>; scheme tcp/udp/sctp/unix)";
    validator = socketUrl.isValid;
  };

  bindUrlType = mkStrType {
    typeName = "bindUrl";
    description = "a bind URL (<scheme>://<bindpoint>; scheme tcp/udp/sctp/unix)";
    validator = bindUrl.isValid;
  };

  secureSocketUrlType = mkStrType {
    typeName = "secureSocketUrl";
    description = "a TLS-secured socket URL (<scheme>://<endpoint>; scheme tls/ssl/dtls/quic)";
    validator = secureSocketUrl.isValid;
  };

  urlType = mkStrType {
    typeName = "url";
    description = "a URL (<scheme>://<host>[:port][/path][?query][#fragment])";
    validator = url.isValid;
  };

  urlHostType = mkStrType {
    typeName = "urlHost";
    description = "a URL-authority host (RFC 3986 IP-literal or reg-name; looser than host)";
    validator = urlHost.isValid;
  };

  authorityType = mkStrType {
    typeName = "authority";
    description = "a URL authority ([userinfo@]host[:port])";
    validator = authority.isValid;
  };

  proxyUrlType = mkStrType {
    typeName = "proxyUrl";
    description = "a proxy URL (<scheme>://[user@]host:port; http/https/socks4/4a/5/5h)";
    validator = proxyUrl.isValid;
  };

  ipBindpointType = mkStrType {
    typeName = "ipBindpoint";
    description = "an IP bind target ([addr]:port[-end])";
    validator = ipBindpoint.isValid;
  };

  bindpointType = mkStrType {
    typeName = "bindpoint";
    description = "a bind target (IP [addr]:port[-end] or unix socket path)";
    validator = bindpoint.isValid;
  };

  ipRangeType = mkStrType {
    typeName = "ipRange";
    description = "an IP address range (from-to)";
    validator = ipRange.isValid;
  };

  interfaceAddressType = mkStrType {
    typeName = "interfaceAddress";
    description = "an address-on-subnet descriptor (address/prefix)";
    validator = interfaceAddress.isValid;
  };

  ipv4InterfaceAddressType = mkStrType {
    typeName = "ipv4InterfaceAddress";
    description = "an IPv4 address-on-subnet descriptor";
    validator = s: interfaceAddress.isValid s && interfaceAddress.isIpv4 (interfaceAddress.parse s);
  };

  ipv6InterfaceAddressType = mkStrType {
    typeName = "ipv6InterfaceAddress";
    description = "an IPv6 address-on-subnet descriptor";
    validator = s: interfaceAddress.isValid s && interfaceAddress.isIpv6 (interfaceAddress.parse s);
  };

  interfaceNameType = mkStrType {
    typeName = "interfaceName";
    description = "a Linux interface name (ifname; kernel dev_valid_name parity)";
    validator = interfaceName.isValid;
  };

  transportType = mkStrType {
    typeName = "transport";
    description = "a transport protocol (tcp, udp, sctp)";
    validator = transport.isValid;
  };

  hostnameType = mkStrType {
    typeName = "hostname";
    description = "an RFC 1123 hostname (single label, 1-63 chars)";
    validator = hostname.isValid;
  };

  domainType = mkStrType {
    typeName = "domain";
    description = "a DNS domain name (>=2 labels, RFC 1123 syntax, total <=253 chars)";
    validator = domain.isValid;
  };

  dnsNameType = mkStrType {
    typeName = "dnsName";
    description = "a DNS name (hostname or domain; not an IP literal)";
    validator = dnsName.isValid;
  };

  hostType = mkStrType {
    typeName = "host";
    description = "an IP address, hostname, or domain";
    validator = host.isValid;
  };

  vlanIdType =
    let
      t = lib.types.ints.between vlanId.lowestValue vlanId.highestValue;
    in
    t
    // {
      mk =
        v:
        if !(builtins.isInt v) then
          builtins.throw "libnet.types.vlanId.mk: expected int, got ${builtins.typeOf v}"
        else if !(vlanId.isValid v) then
          builtins.throw "libnet.types.vlanId.mk: out of range [${builtins.toString vlanId.lowestValue}, ${builtins.toString vlanId.highestValue}]: ${builtins.toString v}"
        else
          v;
    };

  mtuType =
    let
      t = lib.types.ints.between mtu.lowestValue mtu.highestValue;
    in
    t
    // {
      mk =
        v:
        if !(builtins.isInt v) then
          builtins.throw "libnet.types.mtu.mk: expected int, got ${builtins.typeOf v}"
        else if !(mtu.isValid v) then
          builtins.throw "libnet.types.mtu.mk: out of range [${builtins.toString mtu.lowestValue}, ${builtins.toString mtu.highestValue}]: ${builtins.toString v}"
        else
          v;
    };

  icmpTypeType =
    let
      t = lib.types.ints.between icmpType.lowestValue icmpType.highestValue;
    in
    t
    // {
      mk =
        v:
        if !(builtins.isInt v) then
          builtins.throw "libnet.types.icmpType.mk: expected int, got ${builtins.typeOf v}"
        else if !(icmpType.isValid v) then
          builtins.throw "libnet.types.icmpType.mk: out of range [${builtins.toString icmpType.lowestValue}, ${builtins.toString icmpType.highestValue}]: ${builtins.toString v}"
        else
          v;
    };

  portType =
    let
      t = lib.types.coercedTo (lib.types.strMatching "[0-9]+") (s: lib.toInt s) (
        lib.types.ints.between 0 65535
      );
    in
    t
    // {
      mk =
        v:
        if builtins.isInt v then
          (
            if v >= 0 && v <= 65535 then
              v
            else
              builtins.throw "libnet.types.port.mk: out of range: ${builtins.toString v}"
          )
        else if builtins.isString v then
          (if port.isValid v then lib.toInt v else builtins.throw "libnet.types.port.mk: invalid: \"${v}\"")
        else
          builtins.throw "libnet.types.port.mk: expected int or string";
    };
in
{
  types = {
    ipv4 = ipv4Type;
    ipv6 = ipv6Type;
    ip = ipType;
    mac = macType;
    cidr = cidrType;
    ipv4Cidr = ipv4CidrType;
    ipv6Cidr = ipv6CidrType;
    port = portType;
    portRange = portRangeType;
    ipEndpoint = ipEndpointType;
    dnsEndpoint = dnsEndpointType;
    endpoint = endpointType;
    unixSocket = unixSocketType;
    socketUrl = socketUrlType;
    bindUrl = bindUrlType;
    secureSocketUrl = secureSocketUrlType;
    url = urlType;
    urlHost = urlHostType;
    authority = authorityType;
    proxyUrl = proxyUrlType;
    ipBindpoint = ipBindpointType;
    bindpoint = bindpointType;
    ipRange = ipRangeType;
    interfaceAddress = interfaceAddressType;
    ipv4InterfaceAddress = ipv4InterfaceAddressType;
    ipv6InterfaceAddress = ipv6InterfaceAddressType;
    interfaceName = interfaceNameType;
    transport = transportType;
    hostname = hostnameType;
    domain = domainType;
    dnsName = dnsNameType;
    host = hostType;
    vlanId = vlanIdType;
    mtu = mtuType;
    icmpType = icmpTypeType;
  };
}
