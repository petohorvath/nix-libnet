{ harness, lib }:
let
  types = (import ../lib/types.nix { inherit lib; }).types;
  inherit (harness) throws;
in
{
  # ===== ipv4 =====
  ipv4-check-ok = {
    expr = types.ipv4.check "1.2.3.4";
    expected = true;
  };
  ipv4-check-bad = {
    expr = types.ipv4.check "bad";
    expected = false;
  };
  ipv4-check-int = {
    expr = types.ipv4.check 123;
    expected = false;
  };
  ipv4-mk-ok = {
    expr = types.ipv4.mk "1.2.3.4";
    expected = "1.2.3.4";
  };
  ipv4-mk-bad = {
    expr = throws (types.ipv4.mk "bad");
    expected = true;
  };
  ipv4-mk-int = {
    expr = throws (types.ipv4.mk 123);
    expected = true;
  };
  ipv4-desc = {
    expr = builtins.isString types.ipv4.description;
    expected = true;
  };

  # ===== ipv6 =====
  ipv6-check-ok = {
    expr = types.ipv6.check "::1";
    expected = true;
  };
  ipv6-check-bad = {
    expr = types.ipv6.check "bad";
    expected = false;
  };
  ipv6-mk-ok = {
    expr = types.ipv6.mk "2001:db8::1";
    expected = "2001:db8::1";
  };
  ipv6-mk-not-normalized = {
    expr = types.ipv6.mk "2001:DB8::1";
    expected = "2001:DB8::1";
  };

  # ===== ip =====
  ip-check-v4 = {
    expr = types.ip.check "1.2.3.4";
    expected = true;
  };
  ip-check-v6 = {
    expr = types.ip.check "::1";
    expected = true;
  };
  ip-check-bad = {
    expr = types.ip.check "bad";
    expected = false;
  };

  # ===== mac =====
  mac-check-colon = {
    expr = types.mac.check "aa:bb:cc:dd:ee:ff";
    expected = true;
  };
  mac-check-hyphen = {
    expr = types.mac.check "aa-bb-cc-dd-ee-ff";
    expected = true;
  };
  mac-check-cisco = {
    expr = types.mac.check "aabb.ccdd.eeff";
    expected = true;
  };
  mac-check-bad = {
    expr = types.mac.check "zz:zz:zz:zz:zz:zz";
    expected = false;
  };
  mac-mk-ok = {
    expr = types.mac.mk "aa:bb:cc:dd:ee:ff";
    expected = "aa:bb:cc:dd:ee:ff";
  };

  # ===== cidr =====
  cidr-v4-ok = {
    expr = types.cidr.check "10.0.0.0/24";
    expected = true;
  };
  cidr-v6-ok = {
    expr = types.cidr.check "2001:db8::/32";
    expected = true;
  };
  cidr-bad = {
    expr = types.cidr.check "bad";
    expected = false;
  };
  ipv4Cidr-v4-ok = {
    expr = types.ipv4Cidr.check "10.0.0.0/24";
    expected = true;
  };
  ipv4Cidr-v6-rej = {
    expr = types.ipv4Cidr.check "::/0";
    expected = false;
  };
  ipv6Cidr-v6-ok = {
    expr = types.ipv6Cidr.check "::/0";
    expected = true;
  };
  ipv6Cidr-v4-rej = {
    expr = types.ipv6Cidr.check "10.0.0.0/24";
    expected = false;
  };

  # ===== port (coerced int) =====
  port-check-int = {
    expr = types.port.check 80;
    expected = true;
  };
  port-check-string = {
    expr = types.port.check "80";
    expected = true;
  };
  port-check-over = {
    expr = types.port.check 70000;
    expected = false;
  };
  port-check-neg = {
    expr = types.port.check (-1);
    expected = false;
  };
  port-mk-int = {
    expr = types.port.mk 80;
    expected = 80;
  };
  port-mk-string = {
    expr = types.port.mk "80";
    expected = 80;
  };
  port-mk-bad-int = {
    expr = throws (types.port.mk 70000);
    expected = true;
  };
  port-mk-bad-str = {
    expr = throws (types.port.mk "abc");
    expected = true;
  };

  # ===== portRange =====
  portRange-single = {
    expr = types.portRange.check "80";
    expected = true;
  };
  portRange-range = {
    expr = types.portRange.check "80-90";
    expected = true;
  };
  portRange-bad = {
    expr = types.portRange.check "90-80";
    expected = false;
  };

  # ===== endpoint =====
  endpoint-v4-ok = {
    expr = types.endpoint.check "1.2.3.4:80";
    expected = true;
  };
  endpoint-v6-ok = {
    expr = types.endpoint.check "[::1]:80";
    expected = true;
  };
  endpoint-bad = {
    expr = types.endpoint.check "::1:80";
    expected = false;
  };

  # ===== listener =====
  listener-null = {
    expr = types.listener.check ":80";
    expected = true;
  };
  listener-wild = {
    expr = types.listener.check "*:80";
    expected = true;
  };
  listener-range = {
    expr = types.listener.check "1.2.3.4:80-90";
    expected = true;
  };

  # ===== ipRange =====
  ipRange-v4 = {
    expr = types.ipRange.check "1.2.3.4-1.2.3.10";
    expected = true;
  };
  ipRange-v6 = {
    expr = types.ipRange.check "::1-::ff";
    expected = true;
  };
  ipRange-bad = {
    expr = types.ipRange.check "1.2.3.4";
    expected = false;
  };

  # ===== interface =====
  iface-v4 = {
    expr = types.interface.check "10.0.0.5/24";
    expected = true;
  };
  iface-v6 = {
    expr = types.interface.check "::1/64";
    expected = true;
  };
  ipv4Iface-v6-rej = {
    expr = types.ipv4Interface.check "::1/64";
    expected = false;
  };
  ipv6Iface-v4-rej = {
    expr = types.ipv6Interface.check "10.0.0.5/24";
    expected = false;
  };

  # ===== interfaceName =====
  ifname-ok = {
    expr = types.interfaceName.check "eth0";
    expected = true;
  };
  ifname-ok-max = {
    expr = types.interfaceName.check "abcdefghijklmno"; # 15 bytes
    expected = true;
  };
  ifname-empty = {
    expr = types.interfaceName.check "";
    expected = false;
  };
  ifname-too-long = {
    expr = types.interfaceName.check "abcdefghijklmnop"; # 16 bytes
    expected = false;
  };
  ifname-dot = {
    expr = types.interfaceName.check ".";
    expected = false;
  };
  ifname-dotdot = {
    expr = types.interfaceName.check "..";
    expected = false;
  };
  ifname-slash = {
    expr = types.interfaceName.check "eth/0";
    expected = false;
  };
  ifname-colon = {
    expr = types.interfaceName.check "eth:0";
    expected = false;
  };
  ifname-space = {
    expr = types.interfaceName.check "eth 0";
    expected = false;
  };
  ifname-int = {
    expr = types.interfaceName.check 0;
    expected = false;
  };
  ifname-mk-ok = {
    expr = types.interfaceName.mk "wg0";
    expected = "wg0";
  };
  ifname-mk-bad = {
    expr = throws (types.interfaceName.mk "..");
    expected = true;
  };
  ifname-rej-cidr = {
    expr = types.interfaceName.check "10.0.0.5/24";
    expected = false; # the address-on-subnet form is the `interface` type
  };

  # ===== transport =====
  transport-check-tcp = {
    expr = types.transport.check "tcp";
    expected = true;
  };
  transport-check-udp = {
    expr = types.transport.check "udp";
    expected = true;
  };
  transport-check-sctp = {
    expr = types.transport.check "sctp";
    expected = true;
  };
  transport-check-bad = {
    expr = types.transport.check "icmp";
    expected = false;
  };
  transport-check-upper = {
    expr = types.transport.check "TCP";
    expected = false;
  };
  transport-check-int = {
    expr = types.transport.check 6;
    expected = false;
  };
  transport-mk-ok = {
    expr = types.transport.mk "tcp";
    expected = "tcp";
  };
  transport-mk-bad = {
    expr = throws (types.transport.mk "icmp");
    expected = true;
  };
  transport-desc = {
    expr = builtins.isString types.transport.description;
    expected = true;
  };

  # ===== hostname =====
  hostname-check-ok = {
    expr = types.hostname.check "nas";
    expected = true;
  };
  hostname-check-hyphen = {
    expr = types.hostname.check "my-server";
    expected = true;
  };
  hostname-check-leading-digit = {
    expr = types.hostname.check "3com";
    expected = true;
  };
  hostname-check-underscore = {
    expr = types.hostname.check "host_name";
    expected = false;
  };
  hostname-check-dot = {
    expr = types.hostname.check "host.example.com";
    expected = false;
  };
  hostname-check-empty = {
    expr = types.hostname.check "";
    expected = false;
  };
  hostname-check-int = {
    expr = types.hostname.check 42;
    expected = false;
  };
  hostname-mk-ok = {
    expr = types.hostname.mk "MyHost";
    expected = "MyHost";
  };
  hostname-mk-bad = {
    expr = throws (types.hostname.mk "host_name");
    expected = true;
  };
  hostname-desc = {
    expr = builtins.isString types.hostname.description;
    expected = true;
  };

  # ===== domain =====
  domain-check-ok = {
    expr = types.domain.check "example.com";
    expected = true;
  };
  domain-check-three-labels = {
    expr = types.domain.check "foo.example.com";
    expected = true;
  };
  domain-check-mixed-case = {
    expr = types.domain.check "Example.COM";
    expected = true;
  };
  domain-check-single-label = {
    expr = types.domain.check "example";
    expected = false;
  };
  domain-check-trailing-dot = {
    expr = types.domain.check "example.com.";
    expected = false;
  };
  domain-check-underscore = {
    expr = types.domain.check "host_name.com";
    expected = false;
  };
  domain-check-int = {
    expr = types.domain.check 42;
    expected = false;
  };
  domain-mk-ok = {
    expr = types.domain.mk "example.com";
    expected = "example.com";
  };
  domain-mk-bad = {
    expr = throws (types.domain.mk "example");
    expected = true;
  };
  domain-desc = {
    expr = builtins.isString types.domain.description;
    expected = true;
  };

  # ===== host =====
  host-check-ip = {
    expr = types.host.check "192.168.1.1";
    expected = true;
  };
  host-check-ipv6 = {
    expr = types.host.check "::1";
    expected = true;
  };
  host-check-hostname = {
    expr = types.host.check "nas";
    expected = true;
  };
  host-check-domain = {
    expr = types.host.check "example.com";
    expected = true;
  };
  host-check-bad = {
    expr = types.host.check "host_name";
    expected = false;
  };
  host-check-empty = {
    expr = types.host.check "";
    expected = false;
  };
  host-check-int = {
    expr = types.host.check 42;
    expected = false;
  };
  host-mk-ip = {
    expr = types.host.mk "192.168.1.1";
    expected = "192.168.1.1";
  };
  host-mk-hostname = {
    expr = types.host.mk "nas";
    expected = "nas";
  };
  host-mk-bad = {
    expr = throws (types.host.mk "host_name");
    expected = true;
  };
  host-desc = {
    expr = builtins.isString types.host.description;
    expected = true;
  };

  # ===== .mk smart constructors =====
  mk-preserves-case = {
    expr = types.mac.mk "AA:BB:CC:DD:EE:FF";
    expected = "AA:BB:CC:DD:EE:FF";
  }; # not normalized
  mk-cidr-throws-bad = {
    expr = throws (types.cidr.mk "bad");
    expected = true;
  };
  mk-cidr-wrong-fam = {
    expr = throws (types.ipv4Cidr.mk "::/0");
    expected = true;
  };
}
