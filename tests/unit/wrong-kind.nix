{ libnet, ... }:
let
  /*
    One row per namespace. `value` is a valid value of the namespace's
    kind. `rejects.<function>.<argument>` calls the function with one
    wrong-kind argument, named for what it gets wrong; the call must throw
    an argument-kind error naming the function that was called when forced
    only to weak head normal form, not when a field of its result is read.
    Cover a representative value-taking function, `make` where the
    namespace has one, and arithmetic offsets and indices where it has
    them.
  */
  cases = {
    ipv4 =
      let
        inherit (libnet) ipv4;
        value = ipv4.parse "192.0.2.1";
      in
      {
        module = ipv4;
        inherit value;
        rejects = {
          toString.string = ipv4.toString "192.0.2.1";
          toInt.ipv6Operand = ipv4.toInt (libnet.ipv6.parse "::1");
          toBytes.int = ipv4.toBytes 3221225985;
          fromInt = {
            string = ipv4.fromInt "1";
            set = ipv4.fromInt { };
            float = ipv4.fromInt 1.0;
          };
          fromBytes = {
            set = ipv4.fromBytes { };
            floatByte = ipv4.fromBytes [
              192
              0
              2
              1.0
            ];
          };
          add = {
            floatOffset = ipv4.add 1.5 value;
            intOperand = ipv4.add 1 3221225985;
          };
          sub.stringOffset = ipv4.sub "1" value;
          next.macOperand = ipv4.next (libnet.mac.parse "a0:36:9f:1b:1e:55");
          prev.set = ipv4.prev { };
          diff.ipv6Operand = ipv4.diff value (libnet.ipv6.parse "::1");
          compare.ipv6Operand = ipv4.compare value (libnet.ipv6.parse "::1");
          lt.ipv6Operand = ipv4.lt (libnet.ipv6.parse "::1") value;
          min.int = ipv4.min value 1;
          isPrivate.string = ipv4.isPrivate "10.0.0.1";
          isBogon.ipv6Operand = ipv4.isBogon (libnet.ipv6.parse "::1");
          toArpa.port = ipv4.toArpa (libnet.port.fromInt 80);
        };
      };
    ipv6 =
      let
        inherit (libnet) ipv6;
        value = ipv6.parse "2001:db8::1";
      in
      {
        module = ipv6;
        inherit value;
        rejects = {
          toString.string = ipv6.toString "2001:db8::1";
          toStringExpanded.ipv4Operand = ipv6.toStringExpanded (libnet.ipv4.parse "192.0.2.1");
          toStringBracketed.int = ipv6.toStringBracketed 1;
          toWords.list = ipv6.toWords [
            0
            0
            0
            1
          ];
          toGroups.set = ipv6.toGroups { };
          fromWords = {
            set = ipv6.fromWords { };
            stringWord = ipv6.fromWords [
              0
              0
              0
              "1"
            ];
          };
          fromGroups.floatGroup = ipv6.fromGroups [
            0
            0
            0
            0
            0
            0
            0
            1.0
          ];
          fromBytes.string = ipv6.fromBytes "::1";
          fromIpv4.ipv6Operand = ipv6.fromIpv4 value;
          toIpv4.ipv4Operand = ipv6.toIpv4 (libnet.ipv4.parse "192.0.2.1");
          fromMac = {
            ipv6Prefix = ipv6.fromMac value (libnet.mac.parse "a0:36:9f:1b:1e:55");
            stringMac = ipv6.fromMac (libnet.cidr.parse "2001:db8::/64") "a0:36:9f:1b:1e:55";
          };
          add = {
            floatOffset = ipv6.add 1.5 value;
            ipv4Operand = ipv6.add 1 (libnet.ipv4.parse "192.0.2.1");
          };
          sub.stringOffset = ipv6.sub "1" value;
          next.set = ipv6.next { };
          prev.ipv4Operand = ipv6.prev (libnet.ipv4.parse "192.0.2.1");
          diff.ipv4Operand = ipv6.diff (libnet.ipv4.parse "192.0.2.1") value;
          compare.ipv4Operand = ipv6.compare value (libnet.ipv4.parse "192.0.2.1");
          gt.ipv4Operand = ipv6.gt (libnet.ipv4.parse "192.0.2.1") value;
          max.string = ipv6.max value "::1";
          isGlobal.string = ipv6.isGlobal "2001:db8::1";
          isIpv4Mapped.ipv4Operand = ipv6.isIpv4Mapped (libnet.ipv4.parse "192.0.2.1");
          toArpa.null = ipv6.toArpa null;
        };
      };
    ip =
      let
        inherit (libnet) ip;
        value = ip.parse "192.0.2.1";
      in
      {
        module = ip;
        inherit value;
        rejects = {
          toString.string = ip.toString "192.0.2.1";
          version.mac = ip.version (libnet.mac.parse "a0:36:9f:1b:1e:55");
          add = {
            floatOffset = ip.add 1.5 value;
            floatOffsetIpv6 = ip.add 1.5 (ip.parse "::1");
            intOperand = ip.add 1 3221225985;
          };
          sub.stringOffset = ip.sub "1" value;
          next.cidrOperand = ip.next (libnet.cidr.parse "10.0.0.0/8");
          prev.set = ip.prev { };
          diff.int = ip.diff value 1;
          compare.port = ip.compare value (libnet.port.fromInt 80);
          le.string = ip.le "192.0.2.1" value;
          min.null = ip.min null value;
          isLoopback.string = ip.isLoopback "127.0.0.1";
          isBogon.int = ip.isBogon 1;
          toArpa.mac = ip.toArpa (libnet.mac.parse "a0:36:9f:1b:1e:55");
        };
      };
    mac =
      let
        inherit (libnet) mac;
        value = mac.parse "a0:36:9f:1b:1e:55";
      in
      {
        module = mac;
        inherit value;
        rejects = {
          toString.int = mac.toString 176028872726357;
          toStringCisco.ipv4Operand = mac.toStringCisco (libnet.ipv4.parse "192.0.2.1");
          fromInt = {
            string = mac.fromInt "1";
            set = mac.fromInt { };
          };
          fromBytes.stringByte = mac.fromBytes [
            160
            54
            159
            27
            30
            "85"
          ];
          fromOuiNic = {
            stringOui = mac.fromOuiNic "a036" 0;
            floatNic = mac.fromOuiNic 0 1.0;
          };
          add = {
            floatOffset = mac.add 1.5 value;
            intOperand = mac.add 1 176028872726357;
          };
          sub.nullOffset = mac.sub null value;
          next.set = mac.next { };
          prev.string = mac.prev "a0:36:9f:1b:1e:55";
          diff.int = mac.diff value 0;
          ge.ipv4Operand = mac.ge value (libnet.ipv4.parse "192.0.2.1");
          isMulticast.string = mac.isMulticast "a0:36:9f:1b:1e:55";
          toBytes.int = mac.toBytes 0;
          setLocal.int = mac.setLocal 0;
          setMulticast.string = mac.setMulticast "a0:36:9f:1b:1e:55";
          setUnicast.set = mac.setUnicast { };
          setUniversal.ipv4Operand = mac.setUniversal (libnet.ipv4.parse "192.0.2.1");
          oui.set = mac.oui { };
          toEui64.ipv6Operand = mac.toEui64 (libnet.ipv6.parse "::1");
        };
      };
    port =
      let
        inherit (libnet) port;
        value = port.fromInt 80;
      in
      {
        module = port;
        inherit value;
        rejects = {
          toString.int = port.toString 80;
          fromInt = {
            string = port.fromInt "80";
            set = port.fromInt { };
            float = port.fromInt 80.0;
            null = port.fromInt null;
          };
          add = {
            floatOffset = port.add 1.5 value;
            intOperand = port.add 1 80;
          };
          sub.floatOffset = port.sub 1.5 value;
          next.ipv4Operand = port.next (libnet.ipv4.parse "192.0.2.1");
          prev.vlanIdOperand = port.prev (libnet.vlanId.fromInt 80);
          compare.intOperand = port.compare value 80;
          isWellKnown.int = port.isWellKnown 80;
        };
      };
    vlanId =
      let
        inherit (libnet) vlanId;
        value = vlanId.fromInt 10;
      in
      {
        module = vlanId;
        inherit value;
        rejects = {
          toString.portOperand = vlanId.toString (libnet.port.fromInt 10);
          fromInt.string = vlanId.fromInt "10";
          add.floatOffset = vlanId.add 1.5 value;
          sub.stringOffset = vlanId.sub "1" value;
          lt.intOperand = vlanId.lt 10 value;
        };
      };
    mtu =
      let
        inherit (libnet) mtu;
        value = mtu.fromInt 1500;
      in
      {
        module = mtu;
        inherit value;
        rejects = {
          toInt.int = mtu.toInt 1500;
          fromInt.list = mtu.fromInt [ 1500 ];
          add.nullOffset = mtu.add null value;
          diff.intOperand = mtu.diff value 1500;
          max.intOperand = mtu.max 1500 value;
        };
      };
    icmpType =
      let
        inherit (libnet) icmpType;
        value = icmpType.fromInt 8;
      in
      {
        module = icmpType;
        inherit value;
        rejects = {
          toString.int = icmpType.toString 8;
          fromInt.string = icmpType.fromInt "8";
          ge.intOperand = icmpType.ge value 8;
        };
      };
    cidr =
      let
        inherit (libnet) cidr ipv4;
        value = cidr.parse "10.0.0.0/24";
        address = ipv4.parse "10.0.0.1";
      in
      {
        module = cidr;
        inherit value;
        rejects = {
          toString.ipv4Operand = cidr.toString address;
          make = {
            stringAddress = cidr.make "10.0.0.0" 24;
            cidrAddress = cidr.make value 24;
            floatPrefix = cidr.make address 24.0;
          };
          fromAddress.string = cidr.fromAddress "10.0.0.1";
          contains = {
            string = cidr.contains value "10.0.0.1";
            cidrOperand = cidr.contains value value;
            ipv4Block = cidr.contains address address;
          };
          addressAt = {
            floatIndex = cidr.addressAt 1.5 value;
            stringIndex = cidr.addressAt "1" value;
          };
          subnets.floatCount = cidr.subnets 1.0 value;
          supernet.nullCount = cidr.supernet null value;
          size.ipv4Operand = cidr.size address;
          hosts.interfaceAddressOperand = cidr.hosts (libnet.interfaceAddress.parse "10.0.0.1/24");
          isSubnetOf.ipv4Operand = cidr.isSubnetOf address value;
          overlaps.ipRangeOperand = cidr.overlaps value (libnet.ipRange.fromCidr value);
          lt.stringOperand = cidr.lt value "10.0.0.0/24";
          summarize = {
            set = cidr.summarize { };
            ipv4Element = cidr.summarize [ address ];
          };
        };
      };
    ipRange =
      let
        inherit (libnet) cidr ipRange ipv4;
        value = ipRange.parse "10.0.0.1-10.0.0.9";
        address = ipv4.parse "10.0.0.5";
      in
      {
        module = ipRange;
        inherit value;
        rejects = {
          toString.cidrOperand = ipRange.toString (cidr.parse "10.0.0.0/24");
          make = {
            stringFrom = ipRange.make "10.0.0.1" address;
            cidrTo = ipRange.make address (cidr.parse "10.0.0.0/24");
          };
          fromAddress.int = ipRange.fromAddress 167772161;
          fromCidr.ipv4 = ipRange.fromCidr address;
          contains = {
            cidrOperand = ipRange.contains value (cidr.parse "10.0.0.0/30");
            string = ipRange.contains value "10.0.0.5";
            ipv4Range = ipRange.contains address address;
          };
          addressAt = {
            floatIndex = ipRange.addressAt 1.5 value;
            nullIndex = ipRange.addressAt null value;
          };
          size.cidrOperand = ipRange.size (cidr.parse "10.0.0.0/24");
          addresses.portRangeOperand = ipRange.addresses (libnet.portRange.parse "80-90");
          overlaps.cidrOperand = ipRange.overlaps value (cidr.parse "10.0.0.0/24");
          isAdjacent.ipv4Operand = ipRange.isAdjacent address value;
          toCidrs.cidrOperand = ipRange.toCidrs (cidr.parse "10.0.0.0/24");
          le.stringOperand = ipRange.le value "10.0.0.1-10.0.0.9";
        };
      };
    interfaceAddress =
      let
        inherit (libnet) cidr interfaceAddress ipv4;
        value = interfaceAddress.parse "10.0.0.1/24";
        address = ipv4.parse "10.0.0.1";
      in
      {
        module = interfaceAddress;
        inherit value;
        rejects = {
          toString.cidrOperand = interfaceAddress.toString (cidr.parse "10.0.0.0/24");
          make = {
            cidrAddress = interfaceAddress.make (cidr.parse "10.0.0.0/24") 24;
            stringPrefix = interfaceAddress.make address "24";
          };
          fromAddress.string = interfaceAddress.fromAddress "10.0.0.1";
          fromCidrAndAddress = {
            ipv4Block = interfaceAddress.fromCidrAndAddress address address;
            cidrAddress = interfaceAddress.fromCidrAndAddress (cidr.parse "10.0.0.0/24") (
              cidr.parse "10.0.0.0/24"
            );
          };
          address.ipv4Operand = interfaceAddress.address address;
          cidr.cidrOperand = interfaceAddress.cidr (cidr.parse "10.0.0.0/24");
          broadcast.ipv4Operand = interfaceAddress.broadcast address;
          isGlobal.ipv4Operand = interfaceAddress.isGlobal address;
          gt.cidrOperand = interfaceAddress.gt value (cidr.parse "10.0.0.0/24");
        };
      };
    portRange =
      let
        inherit (libnet) port portRange;
        value = portRange.parse "80-90";
      in
      {
        module = portRange;
        inherit value;
        rejects = {
          toString.portOperand = portRange.toString (port.fromInt 80);
          make = {
            intFrom = portRange.make 80 (port.fromInt 90);
            intTo = portRange.make (port.fromInt 80) 90;
          };
          fromPort.int = portRange.fromPort 80;
          contains = {
            intPort = portRange.contains value 85;
            portOperand = portRange.contains (port.fromInt 80) (port.fromInt 80);
          };
          portAt = {
            floatIndex = portRange.portAt 1.5 value;
            stringIndex = portRange.portAt "1" value;
          };
          overlaps.portOperand = portRange.overlaps value (port.fromInt 85);
          isSubrangeOf.stringOperand = portRange.isSubrangeOf "80-90" value;
          compare.intOperand = portRange.compare value 80;
          size.int = portRange.size 80;
          ports.portOperand = portRange.ports (port.fromInt 80);
        };
      };
    transport =
      let
        inherit (libnet) transport;
        value = transport.tcp;
      in
      {
        module = transport;
        inherit value;
        rejects = {
          toString.string = transport.toString "tcp";
          isTcp.set = transport.isTcp { };
          isUdp.portOperand = transport.isUdp (libnet.port.fromInt 53);
          isSctp.null = transport.isSctp null;
          compare.string = transport.compare value "udp";
          lt.int = transport.lt 6 value;
          min.portOperand = transport.min value (libnet.port.fromInt 80);
        };
      };
    hostname =
      let
        inherit (libnet) hostname;
        value = hostname.parse "nas";
      in
      {
        module = hostname;
        inherit value;
        rejects = {
          toString.string = hostname.toString "nas";
          compare.domainOperand = hostname.compare value (libnet.domain.parse "nas.example");
          max.string = hostname.max "nas" value;
        };
      };
    domain =
      let
        inherit (libnet) domain;
        value = domain.parse "example.com";
      in
      {
        module = domain;
        inherit value;
        rejects = {
          toString.hostnameOperand = domain.toString (libnet.hostname.parse "example");
          fromLabels = {
            string = domain.fromLabels "example.com";
            intLabel = domain.fromLabels [
              "example"
              1
            ];
          };
          labels.string = domain.labels "example.com";
          parent.regNameOperand = domain.parent (libnet.regName.parse "example.com");
          isSubdomainOf.string = domain.isSubdomainOf value "example.com";
          isSuperdomainOf.null = domain.isSuperdomainOf null value;
          toHostname.set = domain.toHostname { };
          le.string = domain.le "example.com" value;
        };
      };
    dnsName =
      let
        inherit (libnet) dnsName;
        value = dnsName.parse "example.com";
      in
      {
        module = dnsName;
        inherit value;
        rejects = {
          toString.ipv4Operand = dnsName.toString (libnet.ipv4.parse "192.0.2.1");
          compare.regNameOperand = dnsName.compare value (libnet.regName.parse "example.com");
          gt.string = dnsName.gt "example.com" value;
          lt.numericHostname = dnsName.lt (libnet.hostname.parse "1234") value;
        };
      };
    host =
      let
        inherit (libnet) host;
        value = host.parse "example.com";
      in
      {
        module = host;
        inherit value;
        rejects = {
          toString.regNameOperand = host.toString (libnet.regName.parse "example.com");
          compare.string = host.compare value "example.com";
          min.portOperand = host.min (libnet.port.fromInt 80) value;
          toString.numericHostname = host.toString (libnet.hostname.parse "0x7f");
        };
      };
    regName =
      let
        inherit (libnet) regName;
        value = regName.parse "my_host";
      in
      {
        module = regName;
        inherit value;
        rejects = {
          toString.domainOperand = regName.toString (libnet.domain.parse "example.com");
          compare.string = regName.compare value "my_host";
          lt.hostnameOperand = regName.lt (libnet.hostname.parse "a") value;
        };
      };
    urlHost =
      let
        inherit (libnet) urlHost;
        value = urlHost.parse "example.com";
      in
      {
        module = urlHost;
        inherit value;
        rejects = {
          toString.domainOperand = urlHost.toString (libnet.domain.parse "example.com");
          toHost.string = urlHost.toHost "example.com";
          compare.hostnameOperand = urlHost.compare value (libnet.hostname.parse "a");
          ge.null = urlHost.ge null value;
        };
      };
    interfaceName =
      let
        inherit (libnet) interfaceName;
        value = interfaceName.parse "eth0";
      in
      {
        module = interfaceName;
        inherit value;
        rejects = {
          toString.string = interfaceName.toString "eth0";
          compare.hostnameOperand = interfaceName.compare value (libnet.hostname.parse "eth0");
          min.set = interfaceName.min { } value;
        };
      };
    unixSocket =
      let
        inherit (libnet) unixSocket;
        value = unixSocket.parse "/run/foo.sock";
      in
      {
        module = unixSocket;
        inherit value;
        rejects = {
          toString = {
            string = unixSocket.toString "/run/foo.sock";
            untagged = unixSocket.toString { value = "/run/foo.sock"; };
          };
          isPathname.ipEndpointOperand = unixSocket.isPathname (libnet.ipEndpoint.parse "192.0.2.1:80");
          isAbstract.string = unixSocket.isAbstract "@foo";
          compare.stringOperand = unixSocket.compare value "/run/foo.sock";
          lt.intOperand = unixSocket.lt 1 value;
          max.stringOperand = unixSocket.max value "/run/foo.sock";
        };
      };
    ipEndpoint =
      let
        inherit (libnet) ipEndpoint;
        value = ipEndpoint.parse "192.0.2.1:80";
        address = libnet.ipv4.parse "192.0.2.1";
        port = libnet.port.fromInt 80;
      in
      {
        module = ipEndpoint;
        inherit value;
        rejects = {
          toString.string = ipEndpoint.toString "192.0.2.1:80";
          make = {
            stringAddress = ipEndpoint.make "192.0.2.1" port;
            macAddress = ipEndpoint.make (libnet.mac.parse "00:00:5e:00:53:01") port;
            intPort = ipEndpoint.make address 80;
          };
          address.dnsEndpointOperand = ipEndpoint.address (libnet.dnsEndpoint.parse "nas:22");
          port.ipBindpointOperand = ipEndpoint.port (libnet.ipBindpoint.parse "192.0.2.1:80");
          version.ipv4Operand = ipEndpoint.version address;
          isIpv6.string = ipEndpoint.isIpv6 "[::1]:80";
          isLoopback.ipv4Operand = ipEndpoint.isLoopback address;
          toArpa.null = ipEndpoint.toArpa null;
          compare.unixSocketOperand = ipEndpoint.compare value (libnet.unixSocket.parse "/run/foo.sock");
          le.stringOperand = ipEndpoint.le "192.0.2.1:80" value;
          min.intOperand = ipEndpoint.min value 80;
        };
      };
    dnsEndpoint =
      let
        inherit (libnet) dnsEndpoint;
        value = dnsEndpoint.parse "nas:22";
        port = libnet.port.fromInt 22;
      in
      {
        module = dnsEndpoint;
        inherit value;
        rejects = {
          toString.ipEndpointOperand = dnsEndpoint.toString (libnet.ipEndpoint.parse "192.0.2.1:22");
          make = {
            stringName = dnsEndpoint.make "nas" port;
            ipv4Name = dnsEndpoint.make (libnet.ipv4.parse "192.0.2.1") port;
            numericHostname = dnsEndpoint.make (libnet.hostname.parse "1234") port;
            intPort = dnsEndpoint.make (libnet.dnsName.parse "nas") 22;
          };
          name.string = dnsEndpoint.name "nas:22";
          port.null = dnsEndpoint.port null;
          isHostname.hostnameOperand = dnsEndpoint.isHostname (libnet.hostname.parse "nas");
          isDomain.set = dnsEndpoint.isDomain { };
          compare.stringOperand = dnsEndpoint.compare "nas:22" value;
          gt.ipEndpointOperand = dnsEndpoint.gt value (libnet.ipEndpoint.parse "192.0.2.1:22");
          max.intOperand = dnsEndpoint.max 22 value;
        };
      };
    endpoint =
      let
        inherit (libnet) endpoint;
        value = endpoint.parse "/run/foo.sock";
      in
      {
        module = endpoint;
        inherit value;
        rejects = {
          toString = {
            string = endpoint.toString "/run/foo.sock";
            ipBindpointOperand = endpoint.toString (libnet.ipBindpoint.parse ":80");
          };
          compare.stringOperand = endpoint.compare value "/run/foo.sock";
          lt.ipv4Operand = endpoint.lt (libnet.ipv4.parse "192.0.2.1") value;
          min.intOperand = endpoint.min value 80;
        };
      };
    ipBindpoint =
      let
        inherit (libnet) ipBindpoint;
        value = ipBindpoint.parse "192.0.2.1:80-82";
        address = libnet.ipv4.parse "192.0.2.1";
        portRange = libnet.portRange.parse "80-82";
        endpoint = libnet.ipEndpoint.parse "192.0.2.1:80";
      in
      {
        module = ipBindpoint;
        inherit value;
        rejects = {
          toString.string = ipBindpoint.toString ":80";
          make = {
            stringAddress = ipBindpoint.make "192.0.2.1" portRange;
            macAddress = ipBindpoint.make (libnet.mac.parse "00:00:5e:00:53:01") portRange;
            portOperand = ipBindpoint.make address (libnet.port.fromInt 80);
            stringPortRange = ipBindpoint.make null "80-82";
          };
          address.ipEndpointOperand = ipBindpoint.address endpoint;
          portRange.portRangeOperand = ipBindpoint.portRange portRange;
          version.null = ipBindpoint.version null;
          isWildcard.string = ipBindpoint.isWildcard ":80";
          isIpv4.ipEndpointOperand = ipBindpoint.isIpv4 endpoint;
          isGlobal.ipv4Operand = ipBindpoint.isGlobal address;
          toArpa.ipEndpointOperand = ipBindpoint.toArpa endpoint;
          endpoints.string = ipBindpoint.endpoints "192.0.2.1:80-82";
          endpointsUnbounded.ipEndpointOperand = ipBindpoint.endpointsUnbounded endpoint;
          endpointAt = {
            floatIndex = ipBindpoint.endpointAt 1.5 value;
            stringIndex = ipBindpoint.endpointAt "1" value;
            ipEndpointOperand = ipBindpoint.endpointAt 0 endpoint;
          };
          compare.unixSocketOperand = ipBindpoint.compare value (libnet.unixSocket.parse "/run/foo.sock");
          ge.stringOperand = ipBindpoint.ge ":80" value;
          max.intOperand = ipBindpoint.max value 80;
        };
      };
    bindpoint =
      let
        inherit (libnet) bindpoint;
        value = bindpoint.parse ":80";
      in
      {
        module = bindpoint;
        inherit value;
        rejects = {
          toString = {
            string = bindpoint.toString ":80";
            ipEndpointOperand = bindpoint.toString (libnet.ipEndpoint.parse "192.0.2.1:80");
          };
          compare.dnsEndpointOperand = bindpoint.compare value (libnet.dnsEndpoint.parse "nas:22");
          le.intOperand = bindpoint.le 80 value;
          max.stringOperand = bindpoint.max value ":80";
        };
      };
    authority =
      let
        inherit (libnet) authority;
        value = authority.parse "u@example.com:80";
        host = libnet.urlHost.parse "example.com";
      in
      {
        module = authority;
        inherit value;
        rejects = {
          toString.urlOperand = authority.toString (libnet.url.parse "http://example.com");
          make = {
            string = authority.make "u@example.com:80";
            stringHost = authority.make { host = "example.com"; };
            domainHost = authority.make { host = libnet.domain.parse "example.com"; };
            intUserinfo = authority.make {
              inherit host;
              userinfo = 1;
            };
            intPort = authority.make {
              inherit host;
              port = 80;
            };
          };
          userinfo.string = authority.userinfo "u@example.com";
          host.urlHostOperand = authority.host host;
          port.null = authority.port null;
          compare.stringOperand = authority.compare value "example.com";
          lt.urlOperand = authority.lt (libnet.url.parse "http://example.com") value;
          max.set = authority.max value { };
        };
      };
    url =
      let
        inherit (libnet) url;
        value = url.parse "https://u@example.com/p?q#f";
        authority = libnet.authority.parse "example.com";
        proxyUrl = libnet.proxyUrl.parse "http://example.com:8080";
      in
      {
        module = url;
        inherit value;
        rejects = {
          toString.string = url.toString "https://example.com";
          make = {
            string = url.make "https://example.com";
            intScheme = url.make {
              scheme = 1;
              inherit authority;
            };
            stringAuthority = url.make {
              scheme = "https";
              authority = "example.com";
            };
            nullPath = url.make {
              scheme = "https";
              inherit authority;
              path = null;
            };
            intQuery = url.make {
              scheme = "https";
              inherit authority;
              query = 1;
            };
            listFragment = url.make {
              scheme = "https";
              inherit authority;
              fragment = [ ];
            };
          };
          scheme.proxyUrlOperand = url.scheme proxyUrl;
          authority.proxyUrlOperand = url.authority proxyUrl;
          userinfo.authorityOperand = url.userinfo authority;
          host.string = url.host "https://example.com";
          port.null = url.port null;
          defaultPort.set = url.defaultPort { };
          effectivePort.proxyUrlOperand = url.effectivePort proxyUrl;
          path.string = url.path "/p";
          query.authorityOperand = url.query authority;
          fragment.int = url.fragment 1;
          transport.secureSocketUrlOperand = url.transport (
            libnet.secureSocketUrl.parse "tls://192.0.2.1:443"
          );
          isSecure.proxyUrlOperand = url.isSecure proxyUrl;
          toEndpoint.string = url.toEndpoint "https://example.com";
          compare.proxyUrlOperand = url.compare value proxyUrl;
          le.string = url.le "https://example.com" value;
          gt.authorityOperand = url.gt value authority;
          min.null = url.min null value;
        };
      };
    socketUrl =
      let
        inherit (libnet) socketUrl;
        value = socketUrl.parse "tcp://192.0.2.1:80";
        endpoint = libnet.endpoint.parse "192.0.2.1:80";
      in
      {
        module = socketUrl;
        inherit value;
        rejects = {
          toString = {
            string = socketUrl.toString "tcp://192.0.2.1:80";
            bindUrlOperand = socketUrl.toString (libnet.bindUrl.parse "tcp://:80");
          };
          make = {
            transportScheme = socketUrl.make (libnet.transport.parse "tcp") endpoint;
            nullScheme = socketUrl.make null (libnet.unixSocket.parse "/run/foo.sock");
            stringEndpoint = socketUrl.make "tcp" "192.0.2.1:80";
            ipBindpointEndpoint = socketUrl.make "tcp" (libnet.ipBindpoint.parse ":80");
          };
          scheme.secureSocketUrlOperand = socketUrl.scheme (
            libnet.secureSocketUrl.parse "tls://192.0.2.1:443"
          );
          transport.string = socketUrl.transport "tcp://192.0.2.1:80";
          endpoint.ipEndpointOperand = socketUrl.endpoint endpoint;
          isUnix.unixSocketOperand = socketUrl.isUnix (libnet.unixSocket.parse "/run/foo.sock");
          isSecure.null = socketUrl.isSecure null;
          compare.stringOperand = socketUrl.compare value "tcp://192.0.2.1:80";
          lt.bindUrlOperand = socketUrl.lt (libnet.bindUrl.parse "tcp://:80") value;
          max.intOperand = socketUrl.max value 80;
        };
      };
    bindUrl =
      let
        inherit (libnet) bindUrl;
        value = bindUrl.parse "tcp://:80";
        bindpoint = libnet.bindpoint.parse ":80";
      in
      {
        module = bindUrl;
        inherit value;
        rejects = {
          toString = {
            string = bindUrl.toString "tcp://:80";
            socketUrlOperand = bindUrl.toString (libnet.socketUrl.parse "tcp://192.0.2.1:80");
          };
          make = {
            transportScheme = bindUrl.make (libnet.transport.parse "tcp") bindpoint;
            nullScheme = bindUrl.make null (libnet.unixSocket.parse "/run/foo.sock");
            stringBindpoint = bindUrl.make "tcp" ":80";
            ipEndpointBindpoint = bindUrl.make "tcp" (libnet.ipEndpoint.parse "192.0.2.1:80");
          };
          scheme.int = bindUrl.scheme 80;
          transport.socketUrlOperand = bindUrl.transport (libnet.socketUrl.parse "tcp://192.0.2.1:80");
          bindpoint.ipBindpointOperand = bindUrl.bindpoint bindpoint;
          isUnix.string = bindUrl.isUnix "unix:///run/foo.sock";
          isSecure.set = bindUrl.isSecure { };
          compare.socketUrlOperand = bindUrl.compare value (libnet.socketUrl.parse "tcp://192.0.2.1:80");
          ge.stringOperand = bindUrl.ge ":80" value;
          min.intOperand = bindUrl.min value 80;
        };
      };
    secureSocketUrl =
      let
        inherit (libnet) secureSocketUrl;
        value = secureSocketUrl.parse "tls://192.0.2.1:443";
        endpoint = libnet.endpoint.parse "192.0.2.1:443";
      in
      {
        module = secureSocketUrl;
        inherit value;
        rejects = {
          toString = {
            string = secureSocketUrl.toString "tls://192.0.2.1:443";
            socketUrlOperand = secureSocketUrl.toString (libnet.socketUrl.parse "tcp://192.0.2.1:443");
          };
          make = {
            intScheme = secureSocketUrl.make 443 endpoint;
            stringEndpoint = secureSocketUrl.make "tls" "192.0.2.1:443";
            unixSocketEndpoint = secureSocketUrl.make "tls" (libnet.unixSocket.parse "/run/foo.sock");
          };
          scheme.socketUrlOperand = secureSocketUrl.scheme (libnet.socketUrl.parse "tcp://192.0.2.1:443");
          transport.string = secureSocketUrl.transport "tls://192.0.2.1:443";
          endpoint.ipEndpointOperand = secureSocketUrl.endpoint endpoint;
          isSecure.proxyUrlOperand = secureSocketUrl.isSecure (libnet.proxyUrl.parse "https://192.0.2.1:443");
          compare.stringOperand = secureSocketUrl.compare value "tls://192.0.2.1:443";
          gt.socketUrlOperand = secureSocketUrl.gt (libnet.socketUrl.parse "tcp://192.0.2.1:443") value;
          max.null = secureSocketUrl.max value null;
        };
      };
    proxyUrl =
      let
        inherit (libnet) proxyUrl;
        value = proxyUrl.parse "socks5://u@192.0.2.1:1080";
        authority = libnet.authority.parse "u@192.0.2.1:1080";
      in
      {
        module = proxyUrl;
        inherit value;
        rejects = {
          toString = {
            string = proxyUrl.toString "socks5://192.0.2.1:1080";
            urlOperand = proxyUrl.toString (libnet.url.parse "http://192.0.2.1:1080");
          };
          make = {
            intScheme = proxyUrl.make 5 authority;
            stringAuthority = proxyUrl.make "socks5" "192.0.2.1:1080";
            urlAuthority = proxyUrl.make "http" (libnet.url.parse "http://192.0.2.1:1080");
          };
          scheme.urlOperand = proxyUrl.scheme (libnet.url.parse "http://192.0.2.1:1080");
          authority.authorityOperand = proxyUrl.authority authority;
          host.string = proxyUrl.host "socks5://192.0.2.1:1080";
          port.authorityOperand = proxyUrl.port authority;
          userinfo.null = proxyUrl.userinfo null;
          transport.int = proxyUrl.transport 1080;
          isSecure.urlOperand = proxyUrl.isSecure (libnet.url.parse "https://192.0.2.1");
          toEndpoint.ipEndpointOperand = proxyUrl.toEndpoint (libnet.ipEndpoint.parse "192.0.2.1:1080");
          compare.stringOperand = proxyUrl.compare value "socks5://192.0.2.1:1080";
          le.urlOperand = proxyUrl.le (libnet.url.parse "http://192.0.2.1:1080") value;
          min.intOperand = proxyUrl.min value 1080;
        };
      };
  };

  # Arguments of the wrong kind for every namespace: each builtin type, a
  # set whose tag is not a string, and values of a kind no namespace has,
  # one with only the tag and one with a scalar's fields.
  anyValues = [
    80
    1.5
    null
    true
    [ ]
    { }
    (x: x)
    { _type = { }; }
    { _type = "foreign"; }
    {
      _type = "foreign";
      value = 80;
    }
  ];

  # Values of a kind other than the namespace's, malformed tags included.
  # `eq value value` returns false without throwing for each, unless the
  # namespace accepts the kind, as a union accepts its members.
  foreignValues = anyValues ++ [
    { _type = 1; }
    (libnet.port.fromInt 1)
    (libnet.ipv4.parse "192.0.2.1")
  ];

  characters = text: builtins.genList (i: builtins.substring i 1 text) (builtins.stringLength text);
  capitalize =
    name:
    builtins.replaceStrings (characters "abcdefghijklmnopqrstuvwxyz")
      (characters "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
      (builtins.substring 0 1 name)
    + builtins.substring 1 (builtins.stringLength name) name;

  mkRejectTests =
    namespace: function: arguments:
    builtins.listToAttrs (
      map (argument: {
        name = "test${capitalize function}${capitalize argument}";
        value = {
          expr = builtins.seq arguments.${argument} null;
          expectedError.msg = "^libnet\\.${namespace}\\.${function}: expected ";
        };
      }) (builtins.attrNames arguments)
    );

  # `is`, `eq`, `isValid` and `tryParse` accept any value and never throw.
  mkAnyValueTests = namespace: case: {
    testIsAcceptsAnyValue = {
      expr = map case.module.is anyValues;
      expected = map (_: false) anyValues;
    };
    testEqAcceptsAnyValue = {
      expr = map (other: [
        (case.module.eq case.value other)
        (case.module.eq other case.value)
      ]) anyValues;
      expected = map (_: [
        false
        false
      ]) anyValues;
    };
    testEqFalseForTwoForeignValues =
      let
        values = builtins.filter (value: !(case.module.is value)) foreignValues;
      in
      {
        expr = map (value: case.module.eq value value) values;
        expected = map (_: false) values;
      };
    testIsValidAcceptsAnyValue = {
      expr = map case.module.isValid anyValues;
      expected = map (_: false) anyValues;
    };
    # The failure names `parse`, the function `tryParse` reports for.
    testTryParseAcceptsAnyValue = {
      expr = map (
        input:
        let
          result = case.module.tryParse input;
        in
        !result.success && builtins.match "libnet[.]${namespace}[.]parse: .*" result.error != null
      ) anyValues;
      expected = map (_: true) anyValues;
    };
  };

  mkTests =
    namespace: case:
    builtins.foldl' (
      tests: function: tests // mkRejectTests namespace function case.rejects.${function}
    ) (mkAnyValueTests namespace case) (builtins.attrNames case.rejects);
in
builtins.mapAttrs mkTests cases
