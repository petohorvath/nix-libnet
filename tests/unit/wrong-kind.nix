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
          setLocal.int = mac.setLocal 0;
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
