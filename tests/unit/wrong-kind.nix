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
