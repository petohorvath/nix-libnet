{ harness }:
let
  ifAddr = import ../lib/interface-address.nix;
  cidr = import ../lib/cidr.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  inherit (harness) throws;
  p = ifAddr.parse;
in
{
  # ===== Parse =====
  parse-v4 = {
    expr = ifAddr.toString (p "192.168.1.5/24");
    expected = "192.168.1.5/24";
  };
  parse-v4-zero-host = {
    expr = ifAddr.toString (p "192.168.1.0/24");
    expected = "192.168.1.0/24";
  };
  parse-v6 = {
    expr = ifAddr.toString (p "2001:db8::5/64");
    expected = "2001:db8::5/64";
  };
  parse-v4-32 = {
    expr = ifAddr.toString (p "1.2.3.4/32");
    expected = "1.2.3.4/32";
  };

  reject-no-slash = {
    expr = throws (p "10.0.0.0");
    expected = true;
  };
  reject-v4-33 = {
    expr = throws (p "10.0.0.0/33");
    expected = true;
  };
  reject-v6-129 = {
    expr = throws (p "::/129");
    expected = true;
  };
  reject-bad-prefix = {
    expr = throws (p "10.0.0.0/a");
    expected = true;
  };
  reject-not-string = {
    expr = throws (p 42);
    expected = true;
  };

  # A bare ifname is not an interfaceAddress (it has no `/prefix`).
  parse-bare-name-throws = {
    expr = throws (p "eth0");
    expected = true;
  };
  isValid-bare-name-false = {
    expr = ifAddr.isValid "eth0";
    expected = false;
  };

  # ===== tryParse =====
  tryParse-ok = {
    expr = (ifAddr.tryParse "10.0.0.1/24").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (ifAddr.tryParse "nope").success;
    expected = false;
  };

  # ===== Preserves host bits (distinguishes from cidr) =====
  preserves-host = {
    expr = (p "192.168.1.5/24").address.value;
    expected = (ipv4.parse "192.168.1.5").value;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = ifAddr.is (p "192.168.1.5/24");
    expected = true;
  };
  is-cidr = {
    expr = ifAddr.is (cidr.parse "192.168.1.0/24");
    expected = false;
  };
  is-string = {
    expr = ifAddr.is "192.168.1.5/24";
    expected = false;
  };
  isIpv4-v4 = {
    expr = ifAddr.isIpv4 (p "192.168.1.5/24");
    expected = true;
  };
  isIpv6-v6 = {
    expr = ifAddr.isIpv6 (p "::1/64");
    expected = true;
  };
  isValid-ok = {
    expr = ifAddr.isValid "192.168.1.5/24";
    expected = true;
  };

  # ===== Accessors =====
  prefix-v4 = {
    expr = ifAddr.prefix (p "192.168.1.5/24");
    expected = 24;
  };
  address-accessor = {
    expr = (ifAddr.address (p "192.168.1.5/24")).value;
    expected = (ipv4.parse "192.168.1.5").value;
  };
  version-v4 = {
    expr = ifAddr.version (p "192.168.1.5/24");
    expected = 4;
  };
  version-v6 = {
    expr = ifAddr.version (p "::1/64");
    expected = 6;
  };

  # ===== Derived =====
  network-v4 = {
    expr = cidr.toString (ifAddr.network (p "192.168.1.5/24"));
    expected = "192.168.1.0/24";
  };
  network-v6 = {
    expr = cidr.toString (ifAddr.network (p "2001:db8::5/64"));
    expected = "2001:db8::/64";
  };
  netmask-v4 = {
    expr = ipv4.toString (ifAddr.netmask (p "192.168.1.5/24"));
    expected = "255.255.255.0";
  };
  broadcast-v4 = {
    expr = ipv4.toString (ifAddr.broadcast (p "192.168.1.5/24"));
    expected = "192.168.1.255";
  };
  broadcast-v6-throws = {
    expr = throws (ifAddr.broadcast (p "::1/64"));
    expected = true;
  };

  # ===== Conversions =====
  # toCidr preserves host bits; network returns the canonical block.
  toCidr-preserves-host = {
    expr = cidr.toString (ifAddr.toCidr (p "192.168.1.5/24"));
    expected = "192.168.1.5/24";
  };
  toCidr-v6-preserves-host = {
    expr = cidr.toString (ifAddr.toCidr (p "2001:db8::5/64"));
    expected = "2001:db8::5/64";
  };
  network-vs-toCidr = {
    expr = cidr.toString (ifAddr.network (p "192.168.1.5/24"));
    expected = "192.168.1.0/24";
  };
  toRange = {
    expr = (ifAddr.toRange (p "192.168.1.5/24")).to.value;
    expected = (ipv4.parse "192.168.1.255").value;
  };

  # ===== Constructors =====
  make-ok = {
    expr = ifAddr.toString (ifAddr.make (ipv4.parse "10.0.0.1") 24);
    expected = "10.0.0.1/24";
  };
  make-bad-prefix-throws = {
    expr = throws (ifAddr.make (ipv4.parse "10.0.0.1") 33);
    expected = true;
  };
  make-non-ip-throws = {
    expr = throws (ifAddr.make "10.0.0.1" 24);
    expected = true;
  };

  # ===== fromAddress =====
  fromAddress-v4 = {
    expr = ifAddr.toString (ifAddr.fromAddress (ipv4.parse "10.0.0.1"));
    expected = "10.0.0.1/32";
  };
  fromAddress-v6 = {
    expr = ifAddr.toString (ifAddr.fromAddress (ipv6.parse "2001:db8::1"));
    expected = "2001:db8::1/128";
  };
  fromAddress-non-ip-throws = {
    expr = throws (ifAddr.fromAddress "10.0.0.1");
    expected = true;
  };

  # ===== fromAddressAndNetwork =====
  fromAddrNet-ok = {
    expr = ifAddr.toString (
      ifAddr.fromAddressAndNetwork (ipv4.parse "192.168.1.5") (cidr.parse "192.168.1.0/24")
    );
    expected = "192.168.1.5/24";
  };
  fromAddrNet-out = {
    expr = throws (ifAddr.fromAddressAndNetwork (ipv4.parse "10.0.0.1") (cidr.parse "192.168.1.0/24"));
    expected = true;
  };
  fromAddrNet-mix = {
    expr = throws (ifAddr.fromAddressAndNetwork (ipv4.parse "192.168.1.5") (cidr.parse "::/0"));
    expected = true;
  };

  # ===== Distinction from CIDR =====
  # interfaceAddress vs cidr with same text representation must NOT be equal.
  ifaddr-vs-cidr = {
    expr = (p "192.168.1.5/24")._type != (cidr.parse "192.168.1.5/24")._type;
    expected = true;
  };
  ifaddr-tagged = {
    expr = (p "192.168.1.5/24")._type;
    expected = "interfaceAddress";
  };

  # ===== Comparison helpers =====
  cmp-lt = {
    expr = ifAddr.lt (p "10.0.0.1/24") (p "10.0.0.2/24");
    expected = true;
  };
  cmp-le = {
    expr = ifAddr.le (p "10.0.0.1/24") (p "10.0.0.2/24");
    expected = true;
  };
  cmp-gt = {
    expr = ifAddr.gt (p "10.0.0.2/24") (p "10.0.0.1/24");
    expected = true;
  };
  cmp-ge = {
    expr = ifAddr.ge (p "10.0.0.2/24") (p "10.0.0.1/24");
    expected = true;
  };
  cmp-min = {
    expr = ifAddr.toString (ifAddr.min (p "10.0.0.1/24") (p "10.0.0.2/24"));
    expected = "10.0.0.1/24";
  };
  cmp-max = {
    expr = ifAddr.toString (ifAddr.max (p "10.0.0.1/24") (p "10.0.0.2/24"));
    expected = "10.0.0.2/24";
  };

  # ===== Comparison =====
  eq-same = {
    expr = ifAddr.eq (p "10.0.0.1/24") (p "10.0.0.1/24");
    expected = true;
  };
  eq-diff-addr = {
    expr = ifAddr.eq (p "10.0.0.1/24") (p "10.0.0.2/24");
    expected = false;
  };
  eq-diff-prefix = {
    expr = ifAddr.eq (p "10.0.0.1/24") (p "10.0.0.1/25");
    expected = false;
  };
  compare-cross-fam = {
    expr = ifAddr.compare (p "10.0.0.1/24") (p "::1/64");
    expected = -1;
  };
  compare-same = {
    expr = ifAddr.compare (p "10.0.0.1/24") (p "10.0.0.1/24");
    expected = 0;
  };
  compare-addr-lt = {
    expr = ifAddr.compare (p "10.0.0.1/24") (p "10.0.0.2/24");
    expected = -1;
  };
  compare-prefix-lt = {
    expr = ifAddr.compare (p "10.0.0.1/24") (p "10.0.0.1/25");
    expected = -1;
  };

  # ===== Forwarded predicates (apply to the address) =====
  fwd-loopback-v4 = {
    expr = ifAddr.isLoopback (p "127.0.0.1/8");
    expected = true;
  };
  fwd-loopback-v6 = {
    expr = ifAddr.isLoopback (p "::1/128");
    expected = true;
  };
  fwd-loopback-no = {
    expr = ifAddr.isLoopback (p "8.8.8.8/32");
    expected = false;
  };
  fwd-linkLocal-v6 = {
    expr = ifAddr.isLinkLocal (p "fe80::1/64");
    expected = true;
  };
  fwd-multicast-v4 = {
    expr = ifAddr.isMulticast (p "224.0.0.1/32");
    expected = true;
  };
  fwd-documentation-v4 = {
    expr = ifAddr.isDocumentation (p "192.0.2.1/24");
    expected = true;
  };
  fwd-global-v4 = {
    expr = ifAddr.isGlobal (p "8.8.8.8/32");
    expected = true;
  };
  fwd-bogon-v4 = {
    expr = ifAddr.isBogon (p "10.0.0.1/24");
    expected = true;
  };
  fwd-bogon-v6 = {
    expr = ifAddr.isBogon (p "fc00::1/64");
    expected = true;
  };
  fwd-toArpa-v4 = {
    expr = ifAddr.toArpa (p "1.2.3.4/32");
    expected = "4.3.2.1.in-addr.arpa";
  };
  fwd-toArpa-v6 = {
    expr = ifAddr.toArpa (p "::1/128");
    expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa";
  };

  # ===== Round-trip =====
  roundtrip = {
    expr = ifAddr.toString (p "192.168.1.5/24");
    expected = "192.168.1.5/24";
  };
}
