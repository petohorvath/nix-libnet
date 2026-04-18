{ harness }:
let
  iface = import ../lib/interface.nix;
  cidr  = import ../lib/cidr.nix;
  ipv4  = import ../lib/ipv4.nix;
  ipv6  = import ../lib/ipv6.nix;
  inherit (harness) throws;
  p = iface.parse;
in
{
  # ===== Parse =====
  parse-v4          = { expr = iface.toString (p "192.168.1.5/24"); expected = "192.168.1.5/24"; };
  parse-v4-zero-host= { expr = iface.toString (p "192.168.1.0/24"); expected = "192.168.1.0/24"; };
  parse-v6          = { expr = iface.toString (p "2001:db8::5/64"); expected = "2001:db8::5/64"; };
  parse-v4-32       = { expr = iface.toString (p "1.2.3.4/32");     expected = "1.2.3.4/32"; };

  reject-no-slash   = { expr = throws (p "10.0.0.0");        expected = true; };
  reject-v4-33      = { expr = throws (p "10.0.0.0/33");     expected = true; };
  reject-v6-129     = { expr = throws (p "::/129");          expected = true; };
  reject-bad-prefix = { expr = throws (p "10.0.0.0/a");      expected = true; };

  # ===== Preserves host bits (distinguishes from cidr) =====
  preserves-host    = {
    expr = (p "192.168.1.5/24").address.value;
    expected = (ipv4.parse "192.168.1.5").value;
  };

  # ===== Predicates =====
  is-parsed         = { expr = iface.is (p "192.168.1.5/24"); expected = true; };
  is-cidr           = { expr = iface.is (cidr.parse "192.168.1.0/24"); expected = false; };
  isIpv4-v4         = { expr = iface.isIpv4 (p "192.168.1.5/24"); expected = true; };
  isIpv6-v6         = { expr = iface.isIpv6 (p "::1/64");          expected = true; };
  isValid-ok        = { expr = iface.isValid "192.168.1.5/24";     expected = true; };

  # ===== Accessors =====
  prefix-v4         = { expr = iface.prefix (p "192.168.1.5/24"); expected = 24; };
  version-v4        = { expr = iface.version (p "192.168.1.5/24"); expected = 4; };
  version-v6        = { expr = iface.version (p "::1/64");         expected = 6; };

  # ===== Derived =====
  network-v4        = { expr = cidr.toString (iface.network (p "192.168.1.5/24"));
                        expected = "192.168.1.0/24"; };
  network-v6        = { expr = cidr.toString (iface.network (p "2001:db8::5/64"));
                        expected = "2001:db8::/64"; };
  netmask-v4        = { expr = ipv4.toString (iface.netmask (p "192.168.1.5/24"));
                        expected = "255.255.255.0"; };
  broadcast-v4      = { expr = ipv4.toString (iface.broadcast (p "192.168.1.5/24"));
                        expected = "192.168.1.255"; };
  broadcast-v6      = { expr = throws (iface.broadcast (p "::1/64"));
                        expected = true; };

  # ===== Conversions =====
  toCidr            = { expr = cidr.toString (iface.toCidr (p "192.168.1.5/24"));
                        expected = "192.168.1.0/24"; };
  toRange           = {
    expr = (iface.toRange (p "192.168.1.5/24")).to.value;
    expected = (ipv4.parse "192.168.1.255").value;
  };

  # ===== fromAddressAndNetwork =====
  fromAddrNet-ok    = {
    expr = iface.toString
             (iface.fromAddressAndNetwork
               (ipv4.parse "192.168.1.5")
               (cidr.parse "192.168.1.0/24"));
    expected = "192.168.1.5/24";
  };
  fromAddrNet-out   = {
    expr = throws (iface.fromAddressAndNetwork
                     (ipv4.parse "10.0.0.1")
                     (cidr.parse "192.168.1.0/24"));
    expected = true;
  };
  fromAddrNet-mix   = {
    expr = throws (iface.fromAddressAndNetwork
                     (ipv4.parse "192.168.1.5")
                     (cidr.parse "::/0"));
    expected = true;
  };

  # ===== Distinction from CIDR =====
  # Interface vs cidr with same text representation must NOT be equal.
  iface-vs-cidr     = { expr = (p "192.168.1.5/24")._type != (cidr.parse "192.168.1.5/24")._type;
                        expected = true; };
  iface-diff-prefix = { expr = iface.eq (p "192.168.1.5/24") (p "192.168.1.5/25"); expected = false; };

  # ===== Comparison =====
  eq-same           = { expr = iface.eq (p "10.0.0.1/24") (p "10.0.0.1/24"); expected = true; };
  eq-diff-addr      = { expr = iface.eq (p "10.0.0.1/24") (p "10.0.0.2/24"); expected = false; };
  eq-diff-prefix    = { expr = iface.eq (p "10.0.0.1/24") (p "10.0.0.1/25"); expected = false; };
  compare-cross-fam = { expr = iface.compare (p "10.0.0.1/24") (p "::1/64"); expected = -1; };
  compare-same      = { expr = iface.compare (p "10.0.0.1/24") (p "10.0.0.1/24"); expected = 0; };
  compare-addr-lt   = { expr = iface.compare (p "10.0.0.1/24") (p "10.0.0.2/24"); expected = -1; };
  compare-prefix-lt = { expr = iface.compare (p "10.0.0.1/24") (p "10.0.0.1/25"); expected = -1; };
}
