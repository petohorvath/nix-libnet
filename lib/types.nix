/*
  libnet.types

  NixOS option-type integration. Produces string-backed option types
  (ipv4, ipv6, ip, mac, cidr, port, portRange, ipEndpoint, listener,
  ipRange, interface, interfaceName) plus `.mk` coercers that validate
  and return the string.

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
  ipListener = import ./ip-listener.nix;
  listener = import ./listener.nix;
  ipRange = import ./ip-range.nix;
  interface = import ./interface.nix;
  port = import ./port.nix;
  transport = import ./transport.nix;
  hostname = import ./hostname.nix;
  domain = import ./domain.nix;
  dnsName = import ./dns-name.nix;
  host = import ./host.nix;
  vlanId = import ./vlan-id.nix;
  mtu = import ./mtu.nix;

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

  ipListenerType = mkStrType {
    typeName = "ipListener";
    description = "an IP listener spec ([addr]:port[-end])";
    validator = ipListener.isValid;
  };

  listenerType = mkStrType {
    typeName = "listener";
    description = "a listener (IP [addr]:port[-end] or unix socket path)";
    validator = listener.isValid;
  };

  ipRangeType = mkStrType {
    typeName = "ipRange";
    description = "an IP address range (from-to)";
    validator = ipRange.isValid;
  };

  interfaceType = mkStrType {
    typeName = "interface";
    description = "an address-on-subnet descriptor (address/prefix)";
    validator = interface.isValid;
  };

  ipv4InterfaceType = mkStrType {
    typeName = "ipv4Interface";
    description = "an IPv4 address-on-subnet descriptor";
    validator = s: interface.isValid s && interface.isIpv4 (interface.parse s);
  };

  ipv6InterfaceType = mkStrType {
    typeName = "ipv6Interface";
    description = "an IPv6 address-on-subnet descriptor";
    validator = s: interface.isValid s && interface.isIpv6 (interface.parse s);
  };

  interfaceNameType = mkStrType {
    typeName = "interfaceName";
    description = "a Linux interface name (ifname; kernel dev_valid_name parity)";
    validator = interface.isValidName;
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
    ipListener = ipListenerType;
    listener = listenerType;
    ipRange = ipRangeType;
    interface = interfaceType;
    ipv4Interface = ipv4InterfaceType;
    ipv6Interface = ipv6InterfaceType;
    interfaceName = interfaceNameType;
    transport = transportType;
    hostname = hostnameType;
    domain = domainType;
    dnsName = dnsNameType;
    host = hostType;
    vlanId = vlanIdType;
    mtu = mtuType;
  };
}
