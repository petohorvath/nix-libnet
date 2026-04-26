/*
  libnet.types

  NixOS option-type integration. Produces string-backed option types
  (ipv4, ipv6, ip, mac, cidr, port, portRange, endpoint, listener,
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
  endpoint = import ./endpoint.nix;
  listener = import ./listener.nix;
  ipRange = import ./ip-range.nix;
  interface = import ./interface.nix;
  port = import ./port.nix;

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

  endpointType = mkStrType {
    typeName = "endpoint";
    description = "an endpoint (host:port or [ipv6]:port)";
    validator = endpoint.isValid;
  };

  listenerType = mkStrType {
    typeName = "listener";
    description = "a listener spec ([addr]:port[-end])";
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
    endpoint = endpointType;
    listener = listenerType;
    ipRange = ipRangeType;
    interface = interfaceType;
    ipv4Interface = ipv4InterfaceType;
    ipv6Interface = ipv6InterfaceType;
    interfaceName = interfaceNameType;
  };
}
