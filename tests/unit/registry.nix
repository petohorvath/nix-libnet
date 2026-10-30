{ libnet, ... }:
let
  inherit (libnet)
    cidr
    icmpType
    ip
    ipv4
    ipv6
    port
    registry
    ;

  v4Strings = registry.bogons.ipv4;
  v6Strings = registry.bogons.ipv6;

  v4Cidrs = map cidr.parse v4Strings;
  v6Cidrs = map cidr.parse v6Strings;

  inherit (cidr) isIpv4 isIpv6;

  inAnyV4 = address: builtins.any (block: cidr.contains block address) v4Cidrs;
  inAnyV6 = address: builtins.any (block: cidr.contains block address) v6Cidrs;

  inV4 = input: inAnyV4 (ipv4.parse input);
  inV6 = input: inAnyV6 (ipv6.parse input);

  maxWords = [
    4294967295
    4294967295
    4294967295
    4294967295
  ];

  # The addresses on both sides of each edge of a block, within the
  # address space.
  edgesV4 =
    block:
    let
      first = cidr.networkAddress block;
      last = cidr.topAddress block;
    in
    [
      first
      last
    ]
    ++ (if ipv4.toInt first == 0 then [ ] else [ (ipv4.prev first) ])
    ++ (if ipv4.eq last ipv4.broadcast then [ ] else [ (ipv4.next last) ]);
  edgesV6 =
    block:
    let
      first = cidr.networkAddress block;
      last = cidr.topAddress block;
    in
    [
      first
      last
    ]
    ++ (if ipv6.eq first ipv6.unspecified then [ ] else [ (ipv6.prev first) ])
    ++ (if ipv6.toWords last == maxWords then [ ] else [ (ipv6.next last) ]);

  # The holes that the predicates carve out of a special-purpose block,
  # which no registry entry edge need touch.
  holesV4 = map cidr.parse [
    "192.0.0.9/32"
    "192.0.0.10/32"
  ];
  holesV6 = map cidr.parse [
    "2001::/32"
    "2001:1::1/128"
    "2001:1::2/128"
    "2001:1::3/128"
    "2001:3::/32"
    "2001:4:112::/48"
    "2001:20::/28"
    "2001:30::/28"
    "64:ff9b::/96"
  ];

  # Probe every edge of every registry entry and hole: on each, the
  # registry and isBogon must agree in both directions.
  probesV4 = builtins.concatMap edgesV4 (v4Cidrs ++ holesV4);
  probesV6 = builtins.concatMap edgesV6 (v6Cidrs ++ holesV6);

  wellKnownPorts = registry.ports;
  sharedNames = builtins.attrNames (builtins.intersectAttrs wellKnownPorts.tcp wellKnownPorts.udp);

  hasUniqueNumbers =
    portTable:
    let
      numbers = builtins.attrValues portTable;
    in
    builtins.all (number: builtins.length (builtins.filter (n: n == number) numbers) == 1) numbers;

  isValidInt = value: builtins.isInt value && value >= 0 && value <= 65535;
  allValidInts =
    portTable: builtins.all (name: isValidInt portTable.${name}) (builtins.attrNames portTable);
  allLiftable =
    portTable:
    builtins.all (name: port.is (port.fromInt portTable.${name})) (builtins.attrNames portTable);

  inherit (registry) icmpTypes;
  isIcmpByte = value: builtins.isInt value && value >= 0 && value <= 255;
  allIcmpBytes =
    typeTable: builtins.all (name: isIcmpByte typeTable.${name}) (builtins.attrNames typeTable);
  allIcmpLiftable =
    typeTable:
    builtins.all (name: icmpType.is (icmpType.fromInt typeTable.${name})) (
      builtins.attrNames typeTable
    );
in
{
  # ===== Shape =====
  testV4Nonempty = {
    expr = builtins.length v4Strings > 0;
    expected = true;
  };
  testV6Nonempty = {
    expr = builtins.length v6Strings > 0;
    expected = true;
  };

  # ===== Family correctness =====
  testV4AllIpv4 = {
    expr = builtins.all isIpv4 v4Cidrs;
    expected = true;
  };
  testV6AllIpv6 = {
    expr = builtins.all isIpv6 v6Cidrs;
    expected = true;
  };

  # ===== Canonical text =====
  testV4Canonical = {
    expr = builtins.all (input: cidr.toString (cidr.parse input) == input) v4Strings;
    expected = true;
  };
  testV6Canonical = {
    expr = builtins.all (input: cidr.toString (cidr.parse input) == input) v6Strings;
    expected = true;
  };

  # ===== isBogon parity =====
  # Every registry entry's first and last address satisfies the
  # hand-written isBogon predicate. Keeps registry ↔ predicate in lock-step.
  testV4IsBogonNetworkAddress = {
    expr = builtins.all (block: ipv4.isBogon (cidr.networkAddress block)) v4Cidrs;
    expected = true;
  };
  testV4IsBogonTop = {
    expr = builtins.all (block: ipv4.isBogon (cidr.topAddress block)) v4Cidrs;
    expected = true;
  };
  testV6IsBogonNetworkAddress = {
    expr = builtins.all (block: ipv6.isBogon (cidr.networkAddress block)) v6Cidrs;
    expected = true;
  };
  testV6IsBogonTop = {
    expr = builtins.all (block: ipv6.isBogon (cidr.topAddress block)) v6Cidrs;
    expected = true;
  };

  # On both sides of every registry entry's and hole's edges, an address
  # is in the registry exactly when isBogon holds, so neither side covers
  # space the other does not.
  testV4AgreesAtEdges = {
    expr = builtins.filter (address: inAnyV4 address != ipv4.isBogon address) probesV4;
    expected = [ ];
  };
  testV6AgreesAtEdges = {
    expr = builtins.filter (address: inAnyV6 address != ipv6.isBogon address) probesV6;
    expected = [ ];
  };

  # ===== Dispatch parity =====
  testIpIsBogonV4 = {
    expr = builtins.all (block: ip.isBogon (cidr.networkAddress block)) v4Cidrs;
    expected = true;
  };
  testIpIsBogonV6 = {
    expr = builtins.all (block: ip.isBogon (cidr.networkAddress block)) v6Cidrs;
    expected = true;
  };

  # ===== Coverage spot checks — positive =====
  testCoversPrivate10 = {
    expr = inV4 "10.0.0.1";
    expected = true;
  };
  testCoversPrivate192168 = {
    expr = inV4 "192.168.1.1";
    expected = true;
  };
  testCoversPrivate17216 = {
    expr = inV4 "172.16.0.1";
    expected = true;
  };
  testCoversLoopbackV4 = {
    expr = inV4 "127.0.0.1";
    expected = true;
  };
  testCoversLinkLocalV4 = {
    expr = inV4 "169.254.1.1";
    expected = true;
  };
  testCoversBroadcast = {
    expr = inV4 "255.255.255.255";
    expected = true;
  };
  testCoversDocumentationV4 = {
    expr = inV4 "192.0.2.1";
    expected = true;
  };

  testCoversLoopbackV6 = {
    expr = inV6 "::1";
    expected = true;
  };
  testCoversLinkLocalV6 = {
    expr = inV6 "fe80::1";
    expected = true;
  };
  testCoversMulticastV6 = {
    expr = inV6 "ff02::1";
    expected = true;
  };
  testCoversUniqueLocalV6 = {
    expr = inV6 "fd00::1";
    expected = true;
  };
  testCoversDocumentationV6 = {
    expr = inV6 "2001:db8::1";
    expected = true;
  };
  testCovers6to4RelayV4 = {
    expr = inV4 "192.88.99.1";
    expected = true;
  };
  testCoversProtocolAssignmentV4 = {
    expr = inV4 "192.0.0.8";
    expected = true;
  };
  testCoversLocalNat64 = {
    expr = inV6 "64:ff9b:1::1";
    expected = true;
  };
  testCoversDummy = {
    expr = inV6 "100:0:0:1::1";
    expected = true;
  };
  testCoversProtocolAssignmentV6 = {
    expr = inV6 "2001:1::4";
    expected = true;
  };
  testCoversBenchmarkingV6 = {
    expr = inV6 "2001:2::1";
    expected = true;
  };
  testCoversSrv6Sid = {
    expr = inV6 "5f00::1";
    expected = true;
  };

  # ===== Coverage spot checks — negative =====
  testExcludes1111 = {
    expr = inV4 "1.1.1.1";
    expected = false;
  };
  testExcludes8888 = {
    expr = inV4 "8.8.8.8";
    expected = false;
  };
  testExcludesCloudflareV6 = {
    expr = inV6 "2606:4700:4700::1111";
    expected = false;
  };
  # Globally reachable addresses inside bogon blocks stay out of the
  # registry.
  testExcludesPcpAnycastV4 = {
    expr = inV4 "192.0.0.9";
    expected = false;
  };
  testExcludesTurnAnycastV4 = {
    expr = inV4 "192.0.0.10";
    expected = false;
  };
  testExcludesReachableV6 = {
    expr = builtins.any inV6 [
      "2001:1::1"
      "2001:1::2"
      "2001:1::3"
      "2001:3::1"
      "2001:4:112::1"
      "2001:20::1"
      "2001:30::1"
    ];
    expected = false;
  };
  testExcludesTeredo = {
    expr = inV6 "2001::1";
    expected = false;
  };
  testExcludesWellKnownNat64 = {
    expr = inV6 "64:ff9b::1";
    expected = false;
  };

  # ===== ports — shape =====
  testPortsTcpNonempty = {
    expr = wellKnownPorts.tcp != { };
    expected = true;
  };
  testPortsUdpNonempty = {
    expr = wellKnownPorts.udp != { };
    expected = true;
  };

  # ===== ports — range =====
  testPortsTcpAllValidInts = {
    expr = allValidInts wellKnownPorts.tcp;
    expected = true;
  };
  testPortsUdpAllValidInts = {
    expr = allValidInts wellKnownPorts.udp;
    expected = true;
  };

  # ===== ports — liftable to Port =====
  testPortsTcpAllLiftable = {
    expr = allLiftable wellKnownPorts.tcp;
    expected = true;
  };
  testPortsUdpAllLiftable = {
    expr = allLiftable wellKnownPorts.udp;
    expected = true;
  };

  # ===== ports — cross-protocol consistency =====
  # Every name present in both tcp and udp must map to the same integer.
  testPortsSharedConsistent = {
    expr = builtins.all (name: wellKnownPorts.tcp.${name} == wellKnownPorts.udp.${name}) sharedNames;
    expected = true;
  };

  # ===== ports — spot checks =====
  testPortsTcpHttp = {
    expr = wellKnownPorts.tcp.http;
    expected = 80;
  };
  testPortsTcpHttps = {
    expr = wellKnownPorts.tcp.https;
    expected = 443;
  };
  testPortsTcpSsh = {
    expr = wellKnownPorts.tcp.ssh;
    expected = 22;
  };
  testPortsTcpPostgres = {
    expr = wellKnownPorts.tcp.postgres;
    expected = 5432;
  };
  testPortsTcpMongodb = {
    expr = wellKnownPorts.tcp.mongodb;
    expected = 27017;
  };
  testPortsUdpDns = {
    expr = wellKnownPorts.udp.dns;
    expected = 53;
  };
  testPortsTcpAmqp = {
    expr = wellKnownPorts.tcp.amqp;
    expected = 5672;
  };
  # One name per number within a protocol: no alias entries.
  testPortsTcpUnique = {
    expr = hasUniqueNumbers wellKnownPorts.tcp;
    expected = true;
  };
  testPortsUdpUnique = {
    expr = hasUniqueNumbers wellKnownPorts.udp;
    expected = true;
  };
  testPortsUdpNtp = {
    expr = wellKnownPorts.udp.ntp;
    expected = 123;
  };

  # ===== icmpTypes — shape =====
  testIcmpV4Nonempty = {
    expr = icmpTypes.ipv4 != { };
    expected = true;
  };
  testIcmpV6Nonempty = {
    expr = icmpTypes.ipv6 != { };
    expected = true;
  };

  # ===== icmpTypes — range (8-bit) =====
  testIcmpV4AllBytes = {
    expr = allIcmpBytes icmpTypes.ipv4;
    expected = true;
  };
  testIcmpV6AllBytes = {
    expr = allIcmpBytes icmpTypes.ipv6;
    expected = true;
  };

  # ===== icmpTypes — liftable to IcmpType =====
  testIcmpV4AllLiftable = {
    expr = allIcmpLiftable icmpTypes.ipv4;
    expected = true;
  };
  testIcmpV6AllLiftable = {
    expr = allIcmpLiftable icmpTypes.ipv6;
    expected = true;
  };

  # ===== icmpTypes — ICMPv6 partition (error <128, informational >=128) =====
  # Per RFC 4443 §2.1, the high bit distinguishes the two classes.
  testIcmpV6EchoRequestInformational = {
    expr = icmpTypes.ipv6.echoRequest >= 128;
    expected = true;
  };
  testIcmpV6DestinationUnreachableError = {
    expr = icmpTypes.ipv6.destinationUnreachable < 128;
    expected = true;
  };

  # ===== icmpTypes — spot checks =====
  testIcmpV4EchoReply = {
    expr = icmpTypes.ipv4.echoReply;
    expected = 0;
  };
  testIcmpV4EchoRequest = {
    expr = icmpTypes.ipv4.echoRequest;
    expected = 8;
  };
  testIcmpV4DestinationUnreachable = {
    expr = icmpTypes.ipv4.destinationUnreachable;
    expected = 3;
  };
  testIcmpV4TimeExceeded = {
    expr = icmpTypes.ipv4.timeExceeded;
    expected = 11;
  };
  testIcmpV4ExtendedEchoRequest = {
    expr = icmpTypes.ipv4.extendedEchoRequest;
    expected = 42;
  };
  testIcmpV4ExtendedEchoReply = {
    expr = icmpTypes.ipv4.extendedEchoReply;
    expected = 43;
  };
  testIcmpV6EchoRequest = {
    expr = icmpTypes.ipv6.echoRequest;
    expected = 128;
  };
  testIcmpV6EchoReply = {
    expr = icmpTypes.ipv6.echoReply;
    expected = 129;
  };
  testIcmpV6NeighborSolicitation = {
    expr = icmpTypes.ipv6.neighborSolicitation;
    expected = 135;
  };
  testIcmpV6NeighborAdvertisement = {
    expr = icmpTypes.ipv6.neighborAdvertisement;
    expected = 136;
  };
  testIcmpV6RouterAdvertisement = {
    expr = icmpTypes.ipv6.routerAdvertisement;
    expected = 134;
  };
  testIcmpV6ExtendedEchoRequest = {
    expr = icmpTypes.ipv6.extendedEchoRequest;
    expected = 160;
  };
  testIcmpV6ExtendedEchoReply = {
    expr = icmpTypes.ipv6.extendedEchoReply;
    expected = 161;
  };
  testIcmpV6RplControl = {
    expr = icmpTypes.ipv6.rplControl;
    expected = 155;
  };

  # Extended Echo pair parity across v4 (RFC 8335) and v6 (RFC 8335)
  testIcmpExtendedEchoNamesMatch = {
    expr =
      (icmpTypes.ipv4 ? extendedEchoRequest)
      && (icmpTypes.ipv4 ? extendedEchoReply)
      && (icmpTypes.ipv6 ? extendedEchoRequest)
      && (icmpTypes.ipv6 ? extendedEchoReply);
    expected = true;
  };
}
