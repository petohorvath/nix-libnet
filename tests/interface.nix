{ harness }:
let
  iface = import ../lib/interface.nix;
  cidr = import ../lib/cidr.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  inherit (harness) throws;
  p = iface.parse;
  pn = iface.parseName;
in
{
  # ===== Parse =====
  parse-v4 = {
    expr = iface.toString (p "192.168.1.5/24");
    expected = "192.168.1.5/24";
  };
  parse-v4-zero-host = {
    expr = iface.toString (p "192.168.1.0/24");
    expected = "192.168.1.0/24";
  };
  parse-v6 = {
    expr = iface.toString (p "2001:db8::5/64");
    expected = "2001:db8::5/64";
  };
  parse-v4-32 = {
    expr = iface.toString (p "1.2.3.4/32");
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

  # parse remains strict: bare names never go through CIDR parse.
  parse-bare-name-throws = {
    expr = throws (p "eth0");
    expected = true;
  };
  isValid-bare-name-false = {
    expr = iface.isValid "eth0";
    expected = false;
  };

  # ===== Preserves host bits (distinguishes from cidr) =====
  preserves-host = {
    expr = (p "192.168.1.5/24").address.value;
    expected = (ipv4.parse "192.168.1.5").value;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = iface.is (p "192.168.1.5/24");
    expected = true;
  };
  is-cidr = {
    expr = iface.is (cidr.parse "192.168.1.0/24");
    expected = false;
  };
  isIpv4-v4 = {
    expr = iface.isIpv4 (p "192.168.1.5/24");
    expected = true;
  };
  isIpv6-v6 = {
    expr = iface.isIpv6 (p "::1/64");
    expected = true;
  };
  isValid-ok = {
    expr = iface.isValid "192.168.1.5/24";
    expected = true;
  };

  # ===== Accessors =====
  prefix-v4 = {
    expr = iface.prefix (p "192.168.1.5/24");
    expected = 24;
  };
  version-v4 = {
    expr = iface.version (p "192.168.1.5/24");
    expected = 4;
  };
  version-v6 = {
    expr = iface.version (p "::1/64");
    expected = 6;
  };

  # ===== Derived =====
  network-v4 = {
    expr = cidr.toString (iface.network (p "192.168.1.5/24"));
    expected = "192.168.1.0/24";
  };
  network-v6 = {
    expr = cidr.toString (iface.network (p "2001:db8::5/64"));
    expected = "2001:db8::/64";
  };
  netmask-v4 = {
    expr = ipv4.toString (iface.netmask (p "192.168.1.5/24"));
    expected = "255.255.255.0";
  };
  broadcast-v4 = {
    expr = ipv4.toString (iface.broadcast (p "192.168.1.5/24"));
    expected = "192.168.1.255";
  };
  broadcast-v6 = {
    expr = throws (iface.broadcast (p "::1/64"));
    expected = true;
  };

  # ===== Conversions =====
  toCidr = {
    expr = cidr.toString (iface.toCidr (p "192.168.1.5/24"));
    expected = "192.168.1.0/24";
  };
  toRange = {
    expr = (iface.toRange (p "192.168.1.5/24")).to.value;
    expected = (ipv4.parse "192.168.1.255").value;
  };

  # ===== fromAddressAndNetwork =====
  fromAddrNet-ok = {
    expr = iface.toString (
      iface.fromAddressAndNetwork (ipv4.parse "192.168.1.5") (cidr.parse "192.168.1.0/24")
    );
    expected = "192.168.1.5/24";
  };
  fromAddrNet-out = {
    expr = throws (iface.fromAddressAndNetwork (ipv4.parse "10.0.0.1") (cidr.parse "192.168.1.0/24"));
    expected = true;
  };
  fromAddrNet-mix = {
    expr = throws (iface.fromAddressAndNetwork (ipv4.parse "192.168.1.5") (cidr.parse "::/0"));
    expected = true;
  };

  # ===== Distinction from CIDR =====
  # Interface vs cidr with same text representation must NOT be equal.
  iface-vs-cidr = {
    expr = (p "192.168.1.5/24")._type != (cidr.parse "192.168.1.5/24")._type;
    expected = true;
  };
  iface-diff-prefix = {
    expr = iface.eq (p "192.168.1.5/24") (p "192.168.1.5/25");
    expected = false;
  };

  # ===== Comparison =====
  eq-same = {
    expr = iface.eq (p "10.0.0.1/24") (p "10.0.0.1/24");
    expected = true;
  };
  eq-diff-addr = {
    expr = iface.eq (p "10.0.0.1/24") (p "10.0.0.2/24");
    expected = false;
  };
  eq-diff-prefix = {
    expr = iface.eq (p "10.0.0.1/24") (p "10.0.0.1/25");
    expected = false;
  };
  compare-cross-fam = {
    expr = iface.compare (p "10.0.0.1/24") (p "::1/64");
    expected = -1;
  };
  compare-same = {
    expr = iface.compare (p "10.0.0.1/24") (p "10.0.0.1/24");
    expected = 0;
  };
  compare-addr-lt = {
    expr = iface.compare (p "10.0.0.1/24") (p "10.0.0.2/24");
    expected = -1;
  };
  compare-prefix-lt = {
    expr = iface.compare (p "10.0.0.1/24") (p "10.0.0.1/25");
    expected = -1;
  };

  # ===== isValidName — kernel dev_valid_name parity =====
  isValidName-ok = {
    expr = iface.isValidName "eth0";
    expected = true;
  };
  isValidName-ok-15 = {
    expr = iface.isValidName "abcdefghijklmno";
    expected = true;
  };
  isValidName-reject-empty = {
    expr = iface.isValidName "";
    expected = false;
  };
  isValidName-reject-16 = {
    expr = iface.isValidName "abcdefghijklmnop";
    expected = false;
  };
  isValidName-reject-dot = {
    expr = iface.isValidName ".";
    expected = false;
  };
  isValidName-reject-dotdot = {
    expr = iface.isValidName "..";
    expected = false;
  };
  isValidName-reject-slash = {
    expr = iface.isValidName "eth/0";
    expected = false;
  };
  isValidName-reject-colon = {
    expr = iface.isValidName "eth:0";
    expected = false;
  };
  isValidName-reject-space = {
    expr = iface.isValidName "eth 0";
    expected = false;
  };
  isValidName-reject-tab = {
    expr = iface.isValidName "eth\t0";
    expected = false;
  };
  isValidName-reject-newline = {
    expr = iface.isValidName "eth\n0";
    expected = false;
  };
  isValidName-reject-cr = {
    expr = iface.isValidName "eth\r0";
    expected = false;
  };
  isValidName-accepts-dash = {
    expr = iface.isValidName "br-home";
    expected = true;
  };
  isValidName-accepts-dot-in-middle = {
    expr = iface.isValidName "vlan.100";
    expected = true;
  };
  isValidName-accepts-underscore = {
    expr = iface.isValidName "wg_0";
    expected = true;
  };

  # ===== parseName / tryParseName =====
  parseName-ok = {
    expr = (pn "eth0").name;
    expected = "eth0";
  };
  parseName-reject-empty = {
    expr = throws (pn "");
    expected = true;
  };
  parseName-reject-16 = {
    expr = throws (pn "abcdefghijklmnop");
    expected = true;
  };
  parseName-reject-slash = {
    expr = throws (pn "eth/0");
    expected = true;
  };
  tryParseName-ok-success = {
    expr = (iface.tryParseName "eth0").success;
    expected = true;
  };
  tryParseName-bad-success-false = {
    expr = (iface.tryParseName "").success;
    expected = false;
  };

  # ===== Shape predicates =====
  is-true-addr-only = {
    expr = iface.is (p "10.0.0.1/24");
    expected = true;
  };
  is-true-name-only = {
    expr = iface.is (pn "eth0");
    expected = true;
  };
  is-true-named-addr = {
    expr = iface.is (iface.withName "eth0" (p "10.0.0.1/24"));
    expected = true;
  };
  hasName-true = {
    expr = iface.hasName (pn "eth0");
    expected = true;
  };
  hasName-false = {
    expr = iface.hasName (p "10.0.0.1/24");
    expected = false;
  };
  hasAddress-true = {
    expr = iface.hasAddress (p "10.0.0.1/24");
    expected = true;
  };
  hasAddress-false = {
    expr = iface.hasAddress (pn "eth0");
    expected = false;
  };
  isIpv4-false-on-name-only = {
    expr = iface.isIpv4 (pn "eth0");
    expected = false;
  };
  isIpv6-false-on-name-only = {
    expr = iface.isIpv6 (pn "eth0");
    expected = false;
  };

  # ===== Constructors =====
  make-unchanged-name-null = {
    expr = (iface.make (ipv4.parse "10.0.0.1") 24).name;
    expected = null;
  };
  makeNamed-ok = {
    expr = iface.toString (iface.makeNamed (ipv4.parse "10.0.0.1") 24 "eth0");
    expected = "10.0.0.1/24";
  };
  makeNamed-ok-name-set = {
    expr = (iface.makeNamed (ipv4.parse "10.0.0.1") 24 "eth0").name;
    expected = "eth0";
  };
  makeNamed-bad-name-throws = {
    expr = throws (iface.makeNamed (ipv4.parse "10.0.0.1") 24 "eth/0");
    expected = true;
  };
  makeNamed-bad-prefix-throws = {
    expr = throws (iface.makeNamed (ipv4.parse "10.0.0.1") 33 "eth0");
    expected = true;
  };
  makeName-ok = {
    expr = (iface.makeName "eth0").name;
    expected = "eth0";
  };
  makeName-bad-throws = {
    expr = throws (iface.makeName "");
    expected = true;
  };

  # ===== Combinators =====
  withName-attach-to-addr-only = {
    expr = (iface.withName "eth0" (p "10.0.0.1/24")).name;
    expected = "eth0";
  };
  withName-replace = {
    expr = (iface.withName "eth1" (iface.withName "eth0" (p "10.0.0.1/24"))).name;
    expected = "eth1";
  };
  withName-on-name-only-replaces = {
    expr = (iface.withName "wlan0" (pn "eth0")).name;
    expected = "wlan0";
  };
  withName-invalid-throws = {
    expr = throws (iface.withName "eth/0" (p "10.0.0.1/24"));
    expected = true;
  };
  withAddress-attach-to-name-only = {
    expr = iface.toString (iface.withAddress (ipv4.parse "10.0.0.1") 24 (pn "eth0"));
    expected = "10.0.0.1/24";
  };
  withAddress-replace = {
    expr =
      (iface.withAddress (ipv4.parse "192.168.1.5") 24 (p "10.0.0.1/8")).address.value
      == (ipv4.parse "192.168.1.5").value;
    expected = true;
  };
  withAddress-preserves-name = {
    expr =
      (iface.withAddress (ipv4.parse "10.0.0.1") 24 (iface.withName "eth0" (p "192.168.1.5/24"))).name;
    expected = "eth0";
  };
  withAddress-bad-prefix-throws = {
    expr = throws (iface.withAddress (ipv4.parse "10.0.0.1") 33 (pn "eth0"));
    expected = true;
  };
  withAddress-bad-address-throws = {
    expr = throws (iface.withAddress "not-an-ip" 24 (pn "eth0"));
    expected = true;
  };

  # ===== Accessors on name-only =====
  name-on-named = {
    expr = iface.name (pn "eth0");
    expected = "eth0";
  };
  name-null-on-addr-only = {
    expr = iface.name (p "10.0.0.1/24");
    expected = null;
  };
  address-null-on-name-only = {
    expr = iface.address (pn "eth0");
    expected = null;
  };
  prefix-null-on-name-only = {
    expr = iface.prefix (pn "eth0");
    expected = null;
  };
  version-null-on-name-only = {
    expr = iface.version (pn "eth0");
    expected = null;
  };
  network-throws-on-name-only = {
    expr = throws (iface.network (pn "eth0"));
    expected = true;
  };
  netmask-throws-on-name-only = {
    expr = throws (iface.netmask (pn "eth0"));
    expected = true;
  };
  hostmask-throws-on-name-only = {
    expr = throws (iface.hostmask (pn "eth0"));
    expected = true;
  };
  broadcast-throws-on-name-only = {
    expr = throws (iface.broadcast (pn "eth0"));
    expected = true;
  };
  toCidr-throws-on-name-only = {
    expr = throws (iface.toCidr (pn "eth0"));
    expected = true;
  };
  toRange-throws-on-name-only = {
    expr = throws (iface.toRange (pn "eth0"));
    expected = true;
  };

  # ===== toString on new shapes =====
  toString-name-only = {
    expr = iface.toString (pn "eth0");
    expected = "eth0";
  };
  toString-named-addr-drops-name = {
    expr = iface.toString (iface.withName "eth0" (p "1.2.3.4/24"));
    expected = "1.2.3.4/24";
  };

  # ===== Round-trips =====
  roundtrip-addr-only = {
    expr = iface.toString (p "192.168.1.5/24");
    expected = "192.168.1.5/24";
  };
  roundtrip-name-only = {
    expr = iface.toString (pn "eth0");
    expected = "eth0";
  };

  # ===== eq extensions =====
  eq-same-name-only = {
    expr = iface.eq (pn "eth0") (pn "eth0");
    expected = true;
  };
  eq-diff-name-only = {
    expr = iface.eq (pn "eth0") (pn "eth1");
    expected = false;
  };
  eq-named-addr-both-same = {
    expr = iface.eq (iface.withName "eth0" (p "10.0.0.1/24")) (iface.withName "eth0" (p "10.0.0.1/24"));
    expected = true;
  };
  eq-named-addr-diff-name = {
    expr = iface.eq (iface.withName "eth0" (p "10.0.0.1/24")) (iface.withName "eth1" (p "10.0.0.1/24"));
    expected = false;
  };
  eq-named-vs-unnamed-same-addr = {
    expr = iface.eq (iface.withName "eth0" (p "10.0.0.1/24")) (p "10.0.0.1/24");
    expected = false;
  };
  eq-addr-only-vs-name-only = {
    expr = iface.eq (p "10.0.0.1/24") (pn "eth0");
    expected = false;
  };

  # ===== compare extensions =====
  compare-addr-only-lt-name-only = {
    expr = iface.compare (p "10.0.0.1/24") (pn "eth0");
    expected = -1;
  };
  compare-name-only-gt-addr-only = {
    expr = iface.compare (pn "eth0") (p "10.0.0.1/24");
    expected = 1;
  };
  compare-name-only-lex-lt = {
    expr = iface.compare (pn "eth0") (pn "eth1");
    expected = -1;
  };
  compare-name-only-lex-eq = {
    expr = iface.compare (pn "eth0") (pn "eth0");
    expected = 0;
  };
  compare-named-vs-unnamed-same-addr = {
    # null name sorts before set name at equal addr+prefix.
    expr = iface.compare (p "10.0.0.1/24") (iface.withName "eth0" (p "10.0.0.1/24"));
    expected = -1;
  };
  compare-same-addr-diff-name-lex = {
    expr = iface.compare (iface.withName "eth0" (p "10.0.0.1/24")) (
      iface.withName "eth1" (p "10.0.0.1/24")
    );
    expected = -1;
  };
}
