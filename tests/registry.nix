{ harness }:
let
  registry = import ../lib/registry.nix;
  cidr = import ../lib/cidr.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  ip = import ../lib/ip.nix;
  port = import ../lib/port.nix;

  v4Strings = registry.bogons.ipv4;
  v6Strings = registry.bogons.ipv6;

  v4Cidrs = map cidr.parse v4Strings;
  v6Cidrs = map cidr.parse v6Strings;

  isIpv4 = c: c.address._type == "ipv4";
  isIpv6 = c: c.address._type == "ipv6";

  inAnyV4 = addr: builtins.any (c: cidr.containsAddress c addr) v4Cidrs;
  inAnyV6 = addr: builtins.any (c: cidr.containsAddress c addr) v6Cidrs;

  inV4 = s: inAnyV4 (ipv4.parse s);
  inV6 = s: inAnyV6 (ipv6.parse s);

  wkp = registry.wellKnownPorts;
  sharedNames = builtins.attrNames (builtins.intersectAttrs wkp.tcp wkp.udp);

  isValidInt = v: builtins.isInt v && v >= 0 && v <= 65535;
  allValidInts = ports: builtins.all (n: isValidInt ports.${n}) (builtins.attrNames ports);
  allLiftable = ports: builtins.all (n: port.is (port.fromInt ports.${n})) (builtins.attrNames ports);
in
{
  # ===== Shape =====
  v4-nonempty = {
    expr = builtins.length v4Strings > 0;
    expected = true;
  };
  v6-nonempty = {
    expr = builtins.length v6Strings > 0;
    expected = true;
  };

  # ===== Family correctness =====
  v4-all-ipv4 = {
    expr = builtins.all isIpv4 v4Cidrs;
    expected = true;
  };
  v6-all-ipv6 = {
    expr = builtins.all isIpv6 v6Cidrs;
    expected = true;
  };

  # ===== isBogon parity =====
  # Every registry entry's network (and v4 broadcast) satisfies the
  # hand-written isBogon predicate. Keeps registry ↔ predicate in lock-step.
  v4-isBogon-network = {
    expr = builtins.all (c: ipv4.isBogon (cidr.network c)) v4Cidrs;
    expected = true;
  };
  v4-isBogon-broadcast = {
    expr = builtins.all (c: ipv4.isBogon (cidr.broadcast c)) v4Cidrs;
    expected = true;
  };
  v6-isBogon-network = {
    expr = builtins.all (c: ipv6.isBogon (cidr.network c)) v6Cidrs;
    expected = true;
  };

  # ===== Dispatch parity =====
  ip-isBogon-v4 = {
    expr = builtins.all (c: ip.isBogon (cidr.network c)) v4Cidrs;
    expected = true;
  };
  ip-isBogon-v6 = {
    expr = builtins.all (c: ip.isBogon (cidr.network c)) v6Cidrs;
    expected = true;
  };

  # ===== Coverage spot checks — positive =====
  covers-private-10 = {
    expr = inV4 "10.0.0.1";
    expected = true;
  };
  covers-private-192-168 = {
    expr = inV4 "192.168.1.1";
    expected = true;
  };
  covers-private-172-16 = {
    expr = inV4 "172.16.0.1";
    expected = true;
  };
  covers-loopback-v4 = {
    expr = inV4 "127.0.0.1";
    expected = true;
  };
  covers-linklocal-v4 = {
    expr = inV4 "169.254.1.1";
    expected = true;
  };
  covers-broadcast = {
    expr = inV4 "255.255.255.255";
    expected = true;
  };
  covers-doc-v4 = {
    expr = inV4 "192.0.2.1";
    expected = true;
  };

  covers-loopback-v6 = {
    expr = inV6 "::1";
    expected = true;
  };
  covers-linklocal-v6 = {
    expr = inV6 "fe80::1";
    expected = true;
  };
  covers-multicast-v6 = {
    expr = inV6 "ff02::1";
    expected = true;
  };
  covers-unique-local-v6 = {
    expr = inV6 "fd00::1";
    expected = true;
  };
  covers-doc-v6 = {
    expr = inV6 "2001:db8::1";
    expected = true;
  };

  # ===== Coverage spot checks — negative =====
  excludes-1-1-1-1 = {
    expr = inV4 "1.1.1.1";
    expected = false;
  };
  excludes-8-8-8-8 = {
    expr = inV4 "8.8.8.8";
    expected = false;
  };
  excludes-cloudflare-v6 = {
    expr = inV6 "2606:4700:4700::1111";
    expected = false;
  };

  # ===== wellKnownPorts — shape =====
  wkp-tcp-nonempty = {
    expr = wkp.tcp != { };
    expected = true;
  };
  wkp-udp-nonempty = {
    expr = wkp.udp != { };
    expected = true;
  };

  # ===== wellKnownPorts — range =====
  wkp-tcp-all-valid-ints = {
    expr = allValidInts wkp.tcp;
    expected = true;
  };
  wkp-udp-all-valid-ints = {
    expr = allValidInts wkp.udp;
    expected = true;
  };

  # ===== wellKnownPorts — liftable to Port =====
  wkp-tcp-all-liftable = {
    expr = allLiftable wkp.tcp;
    expected = true;
  };
  wkp-udp-all-liftable = {
    expr = allLiftable wkp.udp;
    expected = true;
  };

  # ===== wellKnownPorts — cross-protocol consistency =====
  # Every name present in both tcp and udp must map to the same integer.
  wkp-shared-consistent = {
    expr = builtins.all (n: wkp.tcp.${n} == wkp.udp.${n}) sharedNames;
    expected = true;
  };

  # ===== wellKnownPorts — spot checks =====
  wkp-tcp-http = {
    expr = wkp.tcp.http;
    expected = 80;
  };
  wkp-tcp-https = {
    expr = wkp.tcp.https;
    expected = 443;
  };
  wkp-tcp-ssh = {
    expr = wkp.tcp.ssh;
    expected = 22;
  };
  wkp-tcp-postgres = {
    expr = wkp.tcp.postgres;
    expected = 5432;
  };
  wkp-tcp-mongodb = {
    expr = wkp.tcp.mongodb;
    expected = 27017;
  };
  wkp-udp-dns = {
    expr = wkp.udp.dns;
    expected = 53;
  };
  wkp-udp-ntp = {
    expr = wkp.udp.ntp;
    expected = 123;
  };
}
