/*
  libnet.types

  NixOS option-type integration. Exposes a `libnet.types.<name>`
  option type for each libnet value — backed by that value's
  parser and paired with a `.mk` coercer that validates its input.
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
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  internalTypes = import ./internal/types.nix;

  # The namespaces the types parse with, keyed by namespace name.
  namespaces = {
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
    regName = import ./reg-name.nix;
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
  };

  /*
    Give an option type the identity of a libnet type: its name, its
    documentation, and a functor under which two declarations of the same
    libnet type merge to that type, while two different types conflict.
    The default functor would look the type up as `lib.types.<name>`, and
    `coercedTo` refuses to merge at all.

    `typeName`: libnet type name, such as `vlanId`.
    `description`: article-less noun phrase, as nixpkgs writes its own,
    so that `listOf` reads "list of <description>".
    `type`: the option type, extended with `mk`.

    Returns `type` under that identity.
  */
  withIdentity =
    { typeName, description }:
    type:
    let
      self = type // {
        name = typeName;
        inherit description;
        descriptionClass = "noun";
        functor = lib.types.defaultFunctor typeName // {
          type = self;
        };
        typeMerge = lib.types.defaultTypeMerge self.functor;
      };
    in
    self;

  /*
    A namespace's `tryParse` with the `libnet.<namespace>.parse: ` prefix
    stripped from its error, so `mk` can report the detail under its own
    name. It wraps `tryParse` rather than `tryParseDetail` so that the
    empty and non-string inputs keep their shared wording.

    `namespaceName`: a key of `namespaces`, such as `ipv4`.
    `input`: candidate string.

    Returns a tryResult.
  */
  detailParser =
    namespaceName: input:
    let
      result = namespaces.${namespaceName}.tryParse input;
      prefix = errors.message "${namespaceName}.parse" "";
    in
    if result.success then result else result // { error = parsing.stripPrefix prefix result.error; };

  /*
    Restrict a detail parser to one address family, failing for a value
    of the other family.

    `kind`: what the namespace reads, such as `CIDR`.
    `namespaceName`: a key of `namespaces` whose values have `version`,
    such as `cidr`.
    `version`: the accepted family, `4` or `6`.
    `input`: candidate string.

    Returns a tryResult.
  */
  restrictFamily =
    {
      kind,
      namespaceName,
      version,
    }:
    input:
    let
      result = detailParser namespaceName input;
      family = v: "IPv${toString v}";
      other = if version == 4 then 6 else 4;
    in
    if !result.success || namespaces.${namespaceName}.version result.value == version then
      result
    else
      internalTypes.tryErr "\"${input}\" is an ${family other} ${kind}, not an ${family version} ${kind}";

  /*
    Build a string option type whose values a libnet parser accepts.
    Values stay strings after merge; consumers parse them when they need
    structure.

    `typeName`: option type name, also used in `mk` error messages.
    `description`: article-less noun phrase for generated option
    documentation.
    `parser`: detail parser on a string; defaults to the namespace of
    the same name, through `detailParser`.

    Returns a nixpkgs option type extended with `mk`.
  */
  mkStringType =
    {
      typeName,
      description,
      parser ? detailParser typeName,
    }:
    withIdentity { inherit typeName description; } (
      lib.types.mkOptionType {
        name = typeName;
        check = value: builtins.isString value && (parser value).success;
        merge = lib.options.mergeEqualOption;
      }
      // {
        /*
          Validate a string against this option type, so `default` and
          `example` values fail early instead of during module evaluation.

          `input`: candidate string.

          Returns `input` unchanged; throws when it is not a string or does
          not parse, with the parser's detail.
        */
        mk =
          input:
          let
            caller = "types.${typeName}.mk";
            result = parser (errors.expectType caller "string" input);
          in
          if result.success then input else errors.fail caller result.error;
      }
    );

  /*
    Build an integer option type for a bounded integer. It accepts an
    integer or its decimal string and merges to an integer, validating
    both forms with the same `isValid` the core parsers use.

    `typeName`: option type name, used in `mk` error messages, and the
    key of its bounded-integer namespace in `namespaces`, such as
    `vlanId`.
    `label`: what the integer is, such as `VLAN ID`, for the description.

    Returns a nixpkgs option type extended with `mk`.
  */
  mkIntType =
    {
      typeName,
      label,
    }:
    let
      scalar = namespaces.${typeName};
      # An integer is valid when its decimal text is, so text and
      # integer definitions share one validator.
      isValidInt = value: builtins.isInt value && scalar.isValid (toString value);
      parser = detailParser typeName;
      fromString = input: scalar.toInt (scalar.parse input);
    in
    withIdentity
      {
        inherit typeName;
        description = "${label} (${toString scalar.minValue}–${toString scalar.maxValue}, integer or decimal string)";
      }
      (
        lib.types.coercedTo
          (lib.types.addCheck lib.types.str scalar.isValid // { description = "decimal string"; })
          fromString
          (lib.types.addCheck (lib.types.ints.between scalar.minValue scalar.maxValue) isValidInt)
        // {
          /*
            Validate a value against this option type, so `default` and
            `example` values fail early instead of during module evaluation.

            `value`: integer within the scalar's inclusive bounds, or its
            decimal string.

            Returns the integer; throws on any other type or on an invalid
            or out-of-range value, with the parser's detail for a string.
          */
          mk =
            value:
            let
              caller = "types.${typeName}.mk";
              result = parser value;
            in
            if builtins.isInt value then
              (
                if isValidInt value then
                  value
                else
                  errors.fail caller "out of range [${toString scalar.minValue}, ${toString scalar.maxValue}]: ${toString value}"
              )
            else if builtins.isString value then
              (if result.success then scalar.toInt result.value else errors.fail caller result.error)
            else
              errors.fail caller "expected int or string, got ${errors.describe value}";
        }
      );

  ipv4Type = mkStringType {
    typeName = "ipv4";
    description = "IPv4 address (dotted-quad)";
  };

  ipv6Type = mkStringType {
    typeName = "ipv6";
    description = "IPv6 address";
  };

  ipType = mkStringType {
    typeName = "ip";
    description = "IP address (IPv4 or IPv6)";
  };

  macType = mkStringType {
    typeName = "mac";
    description = "MAC address (EUI-48, colon/hyphen/dot/bare)";
  };

  cidrType = mkStringType {
    typeName = "cidr";
    description = "CIDR block (address/prefix, host bits zero)";
  };

  ipv4CidrType = mkStringType {
    typeName = "ipv4Cidr";
    description = "IPv4 CIDR block";
    parser = restrictFamily {
      kind = "CIDR";
      namespaceName = "cidr";
      version = 4;
    };
  };

  ipv6CidrType = mkStringType {
    typeName = "ipv6Cidr";
    description = "IPv6 CIDR block";
    parser = restrictFamily {
      kind = "CIDR";
      namespaceName = "cidr";
      version = 6;
    };
  };

  portRangeType = mkStringType {
    typeName = "portRange";
    description = "port range (80 or 5500-6000)";
  };

  ipEndpointType = mkStringType {
    typeName = "ipEndpoint";
    description = "IP endpoint (addr:port or [ipv6]:port)";
  };

  dnsEndpointType = mkStringType {
    typeName = "dnsEndpoint";
    description = "DNS-name endpoint (name:port; not an IP literal)";
  };

  endpointType = mkStringType {
    typeName = "endpoint";
    description = "endpoint (IP or DNS name with port, or Unix socket)";
  };

  unixSocketType = mkStringType {
    typeName = "unixSocket";
    description = "Unix domain socket (absolute path or @abstract name)";
  };

  socketUrlType = mkStringType {
    typeName = "socketUrl";
    description = "socket URL (<scheme>://<endpoint>; scheme tcp/udp/sctp/unix)";
  };

  bindUrlType = mkStringType {
    typeName = "bindUrl";
    description = "bind URL (<scheme>://<bindpoint>; scheme tcp/udp/sctp/unix)";
  };

  secureSocketUrlType = mkStringType {
    typeName = "secureSocketUrl";
    description = "TLS-secured socket URL (<scheme>://<endpoint>; scheme tls/ssl/dtls/quic)";
  };

  urlType = mkStringType {
    typeName = "url";
    description = "URL (<scheme>://<host>[:port][/path][?query][#fragment])";
  };

  urlHostType = mkStringType {
    typeName = "urlHost";
    description = "URL-authority host (RFC 3986 IP-literal or reg-name; looser than host)";
  };

  regNameType = mkStringType {
    typeName = "regName";
    description = "RFC 3986 registered name (a URL host that is not an IP literal)";
  };

  authorityType = mkStringType {
    typeName = "authority";
    description = "URL authority ([userinfo@]host[:port])";
  };

  proxyUrlType = mkStringType {
    typeName = "proxyUrl";
    description = "proxy URL (<scheme>://[user@]host:port; http/https/socks4/4a/5/5h)";
  };

  ipBindpointType = mkStringType {
    typeName = "ipBindpoint";
    description = "IP bind target ([addr]:port[-end])";
  };

  bindpointType = mkStringType {
    typeName = "bindpoint";
    description = "bind target (IP [addr]:port[-end] or Unix socket path)";
  };

  ipRangeType = mkStringType {
    typeName = "ipRange";
    description = "IP address range (from-to)";
  };

  interfaceAddressType = mkStringType {
    typeName = "interfaceAddress";
    description = "interface address (address/prefix)";
  };

  ipv4InterfaceAddressType = mkStringType {
    typeName = "ipv4InterfaceAddress";
    description = "IPv4 interface address";
    parser = restrictFamily {
      kind = "interface address";
      namespaceName = "interfaceAddress";
      version = 4;
    };
  };

  ipv6InterfaceAddressType = mkStringType {
    typeName = "ipv6InterfaceAddress";
    description = "IPv6 interface address";
    parser = restrictFamily {
      kind = "interface address";
      namespaceName = "interfaceAddress";
      version = 6;
    };
  };

  interfaceNameType = mkStringType {
    typeName = "interfaceName";
    description = "Linux interface name (ifname; kernel dev_valid_name parity)";
  };

  transportType = mkStringType {
    typeName = "transport";
    description = "transport protocol (tcp, udp, sctp)";
  };

  hostnameType = mkStringType {
    typeName = "hostname";
    description = "RFC 1123 hostname (single label, 1–63 chars)";
  };

  domainType = mkStringType {
    typeName = "domain";
    description = "DNS domain name (>=2 labels, RFC 1123 syntax, total <=253 chars)";
  };

  dnsNameType = mkStringType {
    typeName = "dnsName";
    description = "DNS name (hostname or domain; not an IP literal)";
  };

  hostType = mkStringType {
    typeName = "host";
    description = "host (IP address, hostname or domain)";
  };

  portType = mkIntType {
    typeName = "port";
    label = "port";
  };

  vlanIdType = mkIntType {
    typeName = "vlanId";
    label = "VLAN ID";
  };

  mtuType = mkIntType {
    typeName = "mtu";
    label = "MTU";
  };

  icmpTypeType = mkIntType {
    typeName = "icmpType";
    label = "ICMP type";
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
    regName = regNameType;
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
