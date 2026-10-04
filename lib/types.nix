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

  /*
    Build a string option type whose values a libnet validator accepts.
    Values stay strings after merge; consumers parse them when they need
    structure.

    `typeName`: option type name, also used in `mk` error messages.
    `description`: noun phrase for generated option documentation.
    `validator`: predicate on a string, such as a module's `isValid`.

    Returns a nixpkgs option type extended with `mk`.
  */
  mkStringType =
    {
      typeName,
      description,
      validator,
    }:
    lib.types.mkOptionType {
      name = typeName;
      inherit description;
      descriptionClass = "noun";
      check = value: builtins.isString value && validator value;
      merge = lib.options.mergeEqualOption;
    }
    // {
      /*
        Validate a string against this option type, so `default` and
        `example` values fail early instead of during module evaluation.

        `input`: candidate string.

        Returns `input` unchanged; throws when it is not a string or the
        validator rejects it.
      */
      mk =
        input:
        if !(builtins.isString input) then
          throw "libnet.types.${typeName}.mk: expected string, got ${builtins.typeOf input}"
        else if !(validator input) then
          throw "libnet.types.${typeName}.mk: invalid value \"${input}\""
        else
          input;
    };

  /*
    Build an integer option type for a bounded libnet scalar. It keeps
    nixpkgs' integer type metadata and merge behavior, but delegates
    validation to the same domain rules the core constructors use.

    `typeName`: option type name, used in `mk` error messages.
    `scalar`: bounded scalar module providing `lowestValue`,
    `highestValue`, and `isValid`, such as `libnet.vlanId`.

    Returns a nixpkgs option type extended with `mk`.
  */
  mkIntType =
    typeName: scalar:
    lib.types.ints.between scalar.lowestValue scalar.highestValue
    // {
      check = scalar.isValid;

      /*
        Validate an integer against this option type, so `default` and
        `example` values fail early instead of during module evaluation.

        `value`: candidate integer.

        Returns `value` unchanged; throws when it is not an integer or
        lies outside the scalar's inclusive bounds.
      */
      mk =
        value:
        if !(builtins.isInt value) then
          throw "libnet.types.${typeName}.mk: expected int, got ${builtins.typeOf value}"
        else if !(scalar.isValid value) then
          throw "libnet.types.${typeName}.mk: out of range [${toString scalar.lowestValue}, ${toString scalar.highestValue}]: ${toString value}"
        else
          value;
    };

  ipv4Type = mkStringType {
    typeName = "ipv4";
    description = "an IPv4 address (dotted-quad)";
    validator = ipv4.isValid;
  };

  ipv6Type = mkStringType {
    typeName = "ipv6";
    description = "an IPv6 address";
    validator = ipv6.isValid;
  };

  ipType = mkStringType {
    typeName = "ip";
    description = "an IPv4 or IPv6 address";
    validator = ip.isValid;
  };

  macType = mkStringType {
    typeName = "mac";
    description = "a MAC address (EUI-48, colon/hyphen/dot/bare)";
    validator = mac.isValid;
  };

  cidrType = mkStringType {
    typeName = "cidr";
    description = "a CIDR block (address/prefix)";
    validator = cidr.isValid;
  };

  ipv4CidrType = mkStringType {
    typeName = "ipv4Cidr";
    description = "an IPv4 CIDR block";
    validator = input: cidr.isValid input && cidr.isIpv4 (cidr.parse input);
  };

  ipv6CidrType = mkStringType {
    typeName = "ipv6Cidr";
    description = "an IPv6 CIDR block";
    validator = input: cidr.isValid input && cidr.isIpv6 (cidr.parse input);
  };

  portRangeType = mkStringType {
    typeName = "portRange";
    description = "a port or port range (80 or 5500-6000)";
    validator = portRange.isValid;
  };

  ipEndpointType = mkStringType {
    typeName = "ipEndpoint";
    description = "an IP endpoint (addr:port or [ipv6]:port)";
    validator = ipEndpoint.isValid;
  };

  dnsEndpointType = mkStringType {
    typeName = "dnsEndpoint";
    description = "a DNS-name endpoint (name:port; not an IP literal)";
    validator = dnsEndpoint.isValid;
  };

  endpointType = mkStringType {
    typeName = "endpoint";
    description = "an endpoint (IP or DNS name : port)";
    validator = endpoint.isValid;
  };

  unixSocketType = mkStringType {
    typeName = "unixSocket";
    description = "a Unix domain socket (absolute path or @abstract name)";
    validator = unixSocket.isValid;
  };

  socketUrlType = mkStringType {
    typeName = "socketUrl";
    description = "a socket URL (<scheme>://<endpoint>; scheme tcp/udp/sctp/unix)";
    validator = socketUrl.isValid;
  };

  bindUrlType = mkStringType {
    typeName = "bindUrl";
    description = "a bind URL (<scheme>://<bindpoint>; scheme tcp/udp/sctp/unix)";
    validator = bindUrl.isValid;
  };

  secureSocketUrlType = mkStringType {
    typeName = "secureSocketUrl";
    description = "a TLS-secured socket URL (<scheme>://<endpoint>; scheme tls/ssl/dtls/quic)";
    validator = secureSocketUrl.isValid;
  };

  urlType = mkStringType {
    typeName = "url";
    description = "a URL (<scheme>://<host>[:port][/path][?query][#fragment])";
    validator = url.isValid;
  };

  urlHostType = mkStringType {
    typeName = "urlHost";
    description = "a URL-authority host (RFC 3986 IP-literal or reg-name; looser than host)";
    validator = urlHost.isValid;
  };

  authorityType = mkStringType {
    typeName = "authority";
    description = "a URL authority ([userinfo@]host[:port])";
    validator = authority.isValid;
  };

  proxyUrlType = mkStringType {
    typeName = "proxyUrl";
    description = "a proxy URL (<scheme>://[user@]host:port; http/https/socks4/4a/5/5h)";
    validator = proxyUrl.isValid;
  };

  ipBindpointType = mkStringType {
    typeName = "ipBindpoint";
    description = "an IP bind target ([addr]:port[-end])";
    validator = ipBindpoint.isValid;
  };

  bindpointType = mkStringType {
    typeName = "bindpoint";
    description = "a bind target (IP [addr]:port[-end] or unix socket path)";
    validator = bindpoint.isValid;
  };

  ipRangeType = mkStringType {
    typeName = "ipRange";
    description = "an IP address range (from-to)";
    validator = ipRange.isValid;
  };

  interfaceAddressType = mkStringType {
    typeName = "interfaceAddress";
    description = "an address-on-subnet descriptor (address/prefix)";
    validator = interfaceAddress.isValid;
  };

  ipv4InterfaceAddressType = mkStringType {
    typeName = "ipv4InterfaceAddress";
    description = "an IPv4 address-on-subnet descriptor";
    validator =
      input: interfaceAddress.isValid input && interfaceAddress.isIpv4 (interfaceAddress.parse input);
  };

  ipv6InterfaceAddressType = mkStringType {
    typeName = "ipv6InterfaceAddress";
    description = "an IPv6 address-on-subnet descriptor";
    validator =
      input: interfaceAddress.isValid input && interfaceAddress.isIpv6 (interfaceAddress.parse input);
  };

  interfaceNameType = mkStringType {
    typeName = "interfaceName";
    description = "a Linux interface name (ifname; kernel dev_valid_name parity)";
    validator = interfaceName.isValid;
  };

  transportType = mkStringType {
    typeName = "transport";
    description = "a transport protocol (tcp, udp, sctp)";
    validator = transport.isValid;
  };

  hostnameType = mkStringType {
    typeName = "hostname";
    description = "an RFC 1123 hostname (single label, 1-63 chars)";
    validator = hostname.isValid;
  };

  domainType = mkStringType {
    typeName = "domain";
    description = "a DNS domain name (>=2 labels, RFC 1123 syntax, total <=253 chars)";
    validator = domain.isValid;
  };

  dnsNameType = mkStringType {
    typeName = "dnsName";
    description = "a DNS name (hostname or domain; not an IP literal)";
    validator = dnsName.isValid;
  };

  hostType = mkStringType {
    typeName = "host";
    description = "an IP address, hostname, or domain";
    validator = host.isValid;
  };

  vlanIdType = mkIntType "vlanId" vlanId;
  mtuType = mkIntType "mtu" mtu;
  icmpTypeType = mkIntType "icmpType" icmpType;

  # Ports merge as integers, so string definitions are coerced to ints.
  portType =
    lib.types.coercedTo (lib.types.strMatching "[0-9]+") lib.toInt (lib.types.ints.between 0 65535)
    // {
      /*
        Validate a port for this option type, so `default` and `example`
        values fail early instead of during module evaluation.

        `value`: integer in [0, 65535], or its decimal string form.

        Returns the port as an integer; throws on any other type or on an
        invalid or out-of-range value.
      */
      mk =
        value:
        if builtins.isInt value then
          (
            if value >= 0 && value <= 65535 then
              value
            else
              throw "libnet.types.port.mk: out of range: ${toString value}"
          )
        else if builtins.isString value then
          (
            if port.isValid value then lib.toInt value else throw "libnet.types.port.mk: invalid: \"${value}\""
          )
        else
          throw "libnet.types.port.mk: expected int or string";
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
