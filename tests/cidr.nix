{ harness }:
let
  cidr = import ../lib/cidr.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  inherit (harness) throws;
  p = cidr.parse;
  c4 = str: ipv4.toString str;
  c6 = str: ipv6.toString str;
in
{
  # ===== Parse: positive =====
  parse-v4-24    = { expr = cidr.toString (p "10.0.0.0/24");       expected = "10.0.0.0/24"; };
  parse-v4-0     = { expr = cidr.toString (p "0.0.0.0/0");          expected = "0.0.0.0/0"; };
  parse-v4-32    = { expr = cidr.toString (p "1.2.3.4/32");         expected = "1.2.3.4/32"; };
  parse-v6-64    = { expr = cidr.toString (p "2001:db8::/64");      expected = "2001:db8::/64"; };
  parse-v6-128   = { expr = cidr.toString (p "::1/128");            expected = "::1/128"; };
  parse-v6-0     = { expr = cidr.toString (p "::/0");               expected = "::/0"; };
  parse-noncanon = { expr = cidr.toString (p "10.0.0.5/24");        expected = "10.0.0.5/24"; };  # stores as-is

  # ===== Parse: negative =====
  reject-no-slash   = { expr = throws (p "10.0.0.0");            expected = true; };
  reject-v4-pfx-33  = { expr = throws (p "10.0.0.0/33");         expected = true; };
  reject-v6-pfx-129 = { expr = throws (p "::/129");              expected = true; };
  reject-pfx-neg    = { expr = throws (p "10.0.0.0/-1");         expected = true; };
  reject-pfx-txt    = { expr = throws (p "10.0.0.0/a");          expected = true; };
  reject-bad-addr   = { expr = throws (p "999.0.0.0/24");        expected = true; };

  # ===== tryParse =====
  tryParse-ok    = { expr = (cidr.tryParse "10.0.0.0/24").success; expected = true; };
  tryParse-bad   = { expr = (cidr.tryParse "bad").success;         expected = false; };

  # ===== Predicates =====
  is-parsed      = { expr = cidr.is (p "10.0.0.0/24");    expected = true; };
  is-string      = { expr = cidr.is "10.0.0.0/24";        expected = false; };
  isIpv4-v4      = { expr = cidr.isIpv4 (p "10.0.0.0/24"); expected = true; };
  isIpv4-v6      = { expr = cidr.isIpv4 (p "::/64");       expected = false; };
  isIpv6-v6      = { expr = cidr.isIpv6 (p "::/64");       expected = true; };
  isValid-ok     = { expr = cidr.isValid "10.0.0.0/24";   expected = true; };
  isValid-bad    = { expr = cidr.isValid "bad";           expected = false; };

  # ===== Accessors =====
  prefix-v4      = { expr = cidr.prefix (p "10.0.0.0/24"); expected = 24; };
  version-v4     = { expr = cidr.version (p "10.0.0.0/24"); expected = 4; };
  version-v6     = { expr = cidr.version (p "::/64");       expected = 6; };

  # ===== Derived values: v4 /24 =====
  network-v4-24     = { expr = c4 (cidr.network (p "10.0.0.5/24"));    expected = "10.0.0.0"; };
  broadcast-v4-24   = { expr = c4 (cidr.broadcast (p "10.0.0.0/24"));  expected = "10.0.0.255"; };
  netmask-v4-24     = { expr = c4 (cidr.netmask (p "10.0.0.0/24"));    expected = "255.255.255.0"; };
  hostmask-v4-24    = { expr = c4 (cidr.hostmask (p "10.0.0.0/24"));   expected = "0.0.0.255"; };
  firstHost-v4-24   = { expr = c4 (cidr.firstHost (p "10.0.0.0/24"));  expected = "10.0.0.1"; };
  lastHost-v4-24    = { expr = c4 (cidr.lastHost (p "10.0.0.0/24"));   expected = "10.0.0.254"; };
  size-v4-24        = { expr = cidr.size (p "10.0.0.0/24");            expected = 256; };
  numHosts-v4-24    = { expr = cidr.numHosts (p "10.0.0.0/24");        expected = 254; };

  # ===== Derived values: v4 /30 =====
  firstHost-v4-30   = { expr = c4 (cidr.firstHost (p "10.0.0.0/30"));  expected = "10.0.0.1"; };
  lastHost-v4-30    = { expr = c4 (cidr.lastHost (p "10.0.0.0/30"));   expected = "10.0.0.2"; };
  size-v4-30        = { expr = cidr.size (p "10.0.0.0/30");            expected = 4; };
  numHosts-v4-30    = { expr = cidr.numHosts (p "10.0.0.0/30");        expected = 2; };

  # ===== Derived values: v4 /31 (point-to-point) =====
  firstHost-v4-31   = { expr = c4 (cidr.firstHost (p "10.0.0.0/31"));  expected = "10.0.0.0"; };
  lastHost-v4-31    = { expr = c4 (cidr.lastHost (p "10.0.0.0/31"));   expected = "10.0.0.1"; };
  size-v4-31        = { expr = cidr.size (p "10.0.0.0/31");            expected = 2; };
  numHosts-v4-31    = { expr = cidr.numHosts (p "10.0.0.0/31");        expected = 2; };

  # ===== Derived values: v4 /32 =====
  firstHost-v4-32   = { expr = c4 (cidr.firstHost (p "1.2.3.4/32"));   expected = "1.2.3.4"; };
  lastHost-v4-32    = { expr = c4 (cidr.lastHost (p "1.2.3.4/32"));    expected = "1.2.3.4"; };
  size-v4-32        = { expr = cidr.size (p "1.2.3.4/32");             expected = 1; };
  numHosts-v4-32    = { expr = cidr.numHosts (p "1.2.3.4/32");         expected = 1; };

  # ===== Derived values: v4 /0 =====
  size-v4-0         = { expr = cidr.size (p "0.0.0.0/0");               expected = 4294967296; };

  # ===== Derived values: v6 /64 =====
  network-v6-64     = { expr = c6 (cidr.network (p "2001:db8::1/64"));   expected = "2001:db8::"; };
  netmask-v6-64     = { expr = c6 (cidr.netmask (p "2001:db8::/64"));    expected = "ffff:ffff:ffff:ffff::"; };
  firstHost-v6-64   = { expr = c6 (cidr.firstHost (p "2001:db8::/64"));  expected = "2001:db8::1"; };
  broadcast-v6      = { expr = throws (cidr.broadcast (p "2001:db8::/64")); expected = true; };

  # ===== v6 /127 (point-to-point) =====
  firstHost-v6-127  = { expr = c6 (cidr.firstHost (p "2001:db8::/127")); expected = "2001:db8::"; };
  lastHost-v6-127   = { expr = c6 (cidr.lastHost (p "2001:db8::/127"));  expected = "2001:db8::1"; };
  size-v6-127       = { expr = cidr.size (p "2001:db8::/127");           expected = 2; };

  # ===== v6 /128 =====
  firstHost-v6-128  = { expr = c6 (cidr.firstHost (p "::1/128"));        expected = "::1"; };
  size-v6-128       = { expr = cidr.size (p "::1/128");                   expected = 1; };

  # ===== v6 /0 and /65 overflow =====
  size-v6-65        = { expr = throws (cidr.size (p "::/65"));            expected = true; };
  size-v6-0         = { expr = throws (cidr.size (p "::/0"));             expected = true; };
  size-v6-66        = { expr = cidr.size (p "::/66");                      expected = 4611686018427387904; };

  # ===== Enumeration =====
  host-0         = { expr = c4 (cidr.host 0 (p "10.0.0.0/28"));   expected = "10.0.0.0"; };
  host-5         = { expr = c4 (cidr.host 5 (p "10.0.0.0/28"));   expected = "10.0.0.5"; };
  host-last      = { expr = c4 (cidr.host 15 (p "10.0.0.0/28"));  expected = "10.0.0.15"; };
  host-neg-1     = { expr = c4 (cidr.host (-1) (p "10.0.0.0/28")); expected = "10.0.0.15"; };
  host-neg-2     = { expr = c4 (cidr.host (-2) (p "10.0.0.0/28")); expected = "10.0.0.14"; };
  host-oob-pos   = { expr = throws (cidr.host 16 (p "10.0.0.0/28")); expected = true; };
  host-oob-neg   = { expr = throws (cidr.host (-17) (p "10.0.0.0/28")); expected = true; };

  hosts-24       = { expr = builtins.length (cidr.hosts (p "10.0.0.0/24")); expected = 254; };
  hosts-size-30  = { expr = map c4 (cidr.hosts (p "10.0.0.0/30"));          expected = [ "10.0.0.1" "10.0.0.2" ]; };
  hosts-huge     = { expr = throws (cidr.hosts (p "10.0.0.0/15"));          expected = true; };
  hosts-unbound  = { expr = builtins.length (cidr.hostsUnbounded (p "10.0.0.0/24")); expected = 254; };

  # ===== Containment =====
  contains-addr-in   = { expr = cidr.contains (p "10.0.0.0/24") (ipv4.parse "10.0.0.5"); expected = true; };
  contains-addr-net  = { expr = cidr.contains (p "10.0.0.0/24") (ipv4.parse "10.0.0.0"); expected = true; };
  contains-addr-bcst = { expr = cidr.contains (p "10.0.0.0/24") (ipv4.parse "10.0.0.255"); expected = true; };
  contains-addr-out  = { expr = cidr.contains (p "10.0.0.0/24") (ipv4.parse "10.0.1.0"); expected = false; };
  contains-addr-below= { expr = cidr.contains (p "10.0.0.0/24") (ipv4.parse "9.255.255.255"); expected = false; };
  contains-cidr-in   = { expr = cidr.contains (p "10.0.0.0/8") (p "10.1.0.0/16"); expected = true; };
  contains-cidr-eq   = { expr = cidr.contains (p "10.0.0.0/24") (p "10.0.0.0/24"); expected = true; };
  contains-cidr-out  = { expr = cidr.contains (p "10.0.0.0/24") (p "10.1.0.0/24"); expected = false; };
  contains-cross-fam = { expr = cidr.contains (p "10.0.0.0/24") (ipv6.parse "::1"); expected = false; };
  contains-v6        = { expr = cidr.contains (p "2001:db8::/32") (ipv6.parse "2001:db8::1"); expected = true; };

  isSubnet-yes       = { expr = cidr.isSubnetOf (p "10.0.0.0/24") (p "10.0.0.0/8"); expected = true; };
  isSubnet-self      = { expr = cidr.isSubnetOf (p "10.0.0.0/24") (p "10.0.0.0/24"); expected = true; };
  isSubnet-no        = { expr = cidr.isSubnetOf (p "10.0.0.0/8")  (p "10.0.0.0/24"); expected = false; };
  isSubnet-disj      = { expr = cidr.isSubnetOf (p "10.0.0.0/24") (p "11.0.0.0/24"); expected = false; };
  isSubnet-cross-fam = { expr = cidr.isSubnetOf (p "10.0.0.0/24") (p "::/0");        expected = false; };
  isSupernet-yes     = { expr = cidr.isSupernetOf (p "10.0.0.0/8") (p "10.0.0.0/24"); expected = true; };
  overlaps-yes       = { expr = cidr.overlaps (p "10.0.0.0/24") (p "10.0.0.0/8");    expected = true; };
  overlaps-no        = { expr = cidr.overlaps (p "10.0.0.0/24") (p "11.0.0.0/24");   expected = false; };
  overlaps-eq        = { expr = cidr.overlaps (p "10.0.0.0/24") (p "10.0.0.0/24");   expected = true; };
  overlaps-adj       = { expr = cidr.overlaps (p "10.0.0.0/25") (p "10.0.0.128/25"); expected = false; };

  # ===== Canonical =====
  canonical-zero     = { expr = cidr.toString (cidr.canonical (p "10.0.0.5/24")); expected = "10.0.0.0/24"; };
  canonical-already  = { expr = cidr.toString (cidr.canonical (p "10.0.0.0/24")); expected = "10.0.0.0/24"; };
  isCanonical-yes    = { expr = cidr.isCanonical (p "10.0.0.0/24"); expected = true; };
  isCanonical-no     = { expr = cidr.isCanonical (p "10.0.0.5/24"); expected = false; };

  # ===== subnet / supernet =====
  subnet-1-split-2   = { expr = map cidr.toString (cidr.subnet 1 (p "10.0.0.0/24"));
                         expected = [ "10.0.0.0/25" "10.0.0.128/25" ]; };
  subnet-2-split-4   = { expr = map cidr.toString (cidr.subnet 2 (p "10.0.0.0/24"));
                         expected = [ "10.0.0.0/26" "10.0.0.64/26" "10.0.0.128/26" "10.0.0.192/26" ]; };
  subnet-0-identity  = { expr = map cidr.toString (cidr.subnet 0 (p "10.0.0.0/24"));
                         expected = [ "10.0.0.0/24" ]; };
  subnet-exceeds-max = { expr = throws (cidr.subnet 1 (p "10.0.0.0/32"));  expected = true; };
  subnet-too-many    = { expr = throws (cidr.subnet 17 (p "10.0.0.0/8"));  expected = true; };
  supernet-1         = { expr = cidr.toString (cidr.supernet 1 (p "10.0.0.0/24")); expected = "10.0.0.0/23"; };
  supernet-8         = { expr = cidr.toString (cidr.supernet 8 (p "10.0.0.0/24")); expected = "10.0.0.0/16"; };
  supernet-from-0    = { expr = throws (cidr.supernet 1 (p "0.0.0.0/0"));   expected = true; };

  # ===== Set algebra =====
  summarize-merge    = { expr = map cidr.toString
                           (cidr.summarize [ (p "10.0.0.0/25") (p "10.0.0.128/25") ]);
                         expected = [ "10.0.0.0/24" ]; };
  summarize-dup      = { expr = map cidr.toString
                           (cidr.summarize [ (p "10.0.0.0/24") (p "10.0.0.0/24") ]);
                         expected = [ "10.0.0.0/24" ]; };
  summarize-contain  = { expr = map cidr.toString
                           (cidr.summarize [ (p "10.0.0.0/8") (p "10.0.0.0/24") ]);
                         expected = [ "10.0.0.0/8" ]; };
  summarize-mixed    = { expr = map cidr.toString
                           (cidr.summarize [ (p "10.0.0.0/24") (p "::/0") ]);
                         expected = [ "10.0.0.0/24" "::/0" ]; };
  summarize-4-to-2   = { expr = map cidr.toString
                           (cidr.summarize [
                             (p "10.0.0.0/26") (p "10.0.0.64/26")
                             (p "10.0.0.128/26") (p "10.0.0.192/26")
                           ]);
                         expected = [ "10.0.0.0/24" ]; };

  exclude-v4-half    = { expr = map cidr.toString (cidr.exclude (p "10.0.0.0/24") (p "10.0.0.0/25"));
                         expected = [ "10.0.0.128/25" ]; };
  exclude-v4-self    = { expr = cidr.exclude (p "10.0.0.0/24") (p "10.0.0.0/24"); expected = [ ]; };
  exclude-not-parent = { expr = throws (cidr.exclude (p "10.0.0.0/24") (p "11.0.0.0/25")); expected = true; };
  exclude-v4-sixth   = { expr = map cidr.toString (cidr.exclude (p "10.0.0.0/24") (p "10.0.0.0/26"));
                         expected = [ "10.0.0.64/26" "10.0.0.128/25" ]; };

  intersect-contained= { expr = cidr.toString (cidr.intersect (p "10.0.0.0/8") (p "10.0.0.0/24"));
                         expected = "10.0.0.0/24"; };
  intersect-disjoint = { expr = cidr.intersect (p "10.0.0.0/24") (p "11.0.0.0/24"); expected = null; };
  intersect-eq       = { expr = cidr.toString (cidr.intersect (p "10.0.0.0/24") (p "10.0.0.0/24"));
                         expected = "10.0.0.0/24"; };
  intersect-cross    = { expr = cidr.intersect (p "10.0.0.0/24") (p "::/0"); expected = null; };

  # ===== Comparison =====
  eq-same            = { expr = cidr.eq (p "10.0.0.0/24") (p "10.0.0.0/24"); expected = true; };
  eq-noncanon        = { expr = cidr.eq (p "10.0.0.0/24") (p "10.0.0.5/24"); expected = true; };  # canonical eq
  eq-diff-prefix     = { expr = cidr.eq (p "10.0.0.0/24") (p "10.0.0.0/25"); expected = false; };
  eq-diff-net        = { expr = cidr.eq (p "10.0.0.0/24") (p "10.0.1.0/24"); expected = false; };
  eq-cross-fam       = { expr = cidr.eq (p "10.0.0.0/24") (p "::/0");        expected = false; };
  compare-v4-v6      = { expr = cidr.compare (p "10.0.0.0/24") (p "::/0");   expected = -1; };
  compare-v6-v4      = { expr = cidr.compare (p "::/0") (p "10.0.0.0/24");   expected = 1; };
  compare-same       = { expr = cidr.compare (p "10.0.0.0/24") (p "10.0.0.0/24"); expected = 0; };
  compare-prefix-lt  = { expr = cidr.compare (p "10.0.0.0/24") (p "10.0.0.0/25"); expected = -1; };
}
