{ libnet, ... }:
let
  /*
    One row per namespace. `value` is a valid value of the namespace's
    kind. `rejects.<function>.<argument>` calls the function with one
    wrong-kind argument, named for what it gets wrong; the call must throw
    an argument-kind error naming the function that was called. Cover a
    representative value-taking function, `make` where the namespace has
    one, and arithmetic offsets and indices where it has them.
  */
  cases = {
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
          expr = arguments.${argument};
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
