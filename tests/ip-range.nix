{ harness }:
let
  ipRange = import ../lib/ip-range.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  cidr = import ../lib/cidr.nix;
  inherit (harness) throws;
  p = ipRange.parse;
in
{
  # ===== Parse =====
  parse-v4 = {
    expr = ipRange.toString (p "1.2.3.4-1.2.3.10");
    expected = "1.2.3.4-1.2.3.10";
  };
  parse-v4-same = {
    expr = ipRange.toString (p "1.2.3.4-1.2.3.4");
    expected = "1.2.3.4-1.2.3.4";
  };
  parse-v6 = {
    expr = ipRange.toString (p "2001:db8::1-2001:db8::ff");
    expected = "2001:db8::1-2001:db8::ff";
  };
  reject-mixed-fam = {
    expr = throws (p "1.2.3.4-::1");
    expected = true;
  };
  reject-reversed = {
    expr = throws (p "1.2.3.10-1.2.3.4");
    expected = true;
  };
  reject-no-dash = {
    expr = throws (p "1.2.3.4");
    expected = true;
  };
  reject-bad-from = {
    expr = throws (p "bad-1.2.3.4");
    expected = true;
  };

  # ===== tryParse =====
  tryParse-ok = {
    expr = (ipRange.tryParse "1.2.3.4-1.2.3.10").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (ipRange.tryParse "bad").success;
    expected = false;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = ipRange.is (p "1.2.3.4-1.2.3.10");
    expected = true;
  };
  is-string = {
    expr = ipRange.is "1.2.3.4-1.2.3.10";
    expected = false;
  };
  isIpv4-v4 = {
    expr = ipRange.isIpv4 (p "1.2.3.4-1.2.3.10");
    expected = true;
  };
  isIpv6-v6 = {
    expr = ipRange.isIpv6 (p "::1-::ff");
    expected = true;
  };
  isSingleton-yes = {
    expr = ipRange.isSingleton (p "1.2.3.4-1.2.3.4");
    expected = true;
  };
  isSingleton-no = {
    expr = ipRange.isSingleton (p "1.2.3.4-1.2.3.5");
    expected = false;
  };

  # ===== Size =====
  size-v4 = {
    expr = ipRange.size (p "1.2.3.4-1.2.3.10");
    expected = 7;
  };
  size-v4-single = {
    expr = ipRange.size (p "1.2.3.4-1.2.3.4");
    expected = 1;
  };
  size-v6 = {
    expr = ipRange.size (p "::1-::10");
    expected = 16;
  };

  # ===== Containment =====
  contains-in = {
    expr = ipRange.contains (p "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.5");
    expected = true;
  };
  contains-from = {
    expr = ipRange.contains (p "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.4");
    expected = true;
  };
  contains-to = {
    expr = ipRange.contains (p "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.10");
    expected = true;
  };
  contains-out-lo = {
    expr = ipRange.contains (p "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.3");
    expected = false;
  };
  contains-out-hi = {
    expr = ipRange.contains (p "1.2.3.4-1.2.3.10") (ipv4.parse "1.2.3.11");
    expected = false;
  };
  contains-cross = {
    expr = ipRange.contains (p "1.2.3.4-1.2.3.10") (ipv6.parse "::1");
    expected = false;
  };

  # ===== Overlaps / subrange =====
  overlaps-yes = {
    expr = ipRange.overlaps (p "1.2.3.4-1.2.3.10") (p "1.2.3.8-1.2.3.15");
    expected = true;
  };
  overlaps-no = {
    expr = ipRange.overlaps (p "1.2.3.4-1.2.3.10") (p "1.2.3.11-1.2.3.20");
    expected = false;
  };
  overlaps-same = {
    expr = ipRange.overlaps (p "1.2.3.4-1.2.3.10") (p "1.2.3.4-1.2.3.10");
    expected = true;
  };
  overlaps-cross = {
    expr = ipRange.overlaps (p "1.2.3.4-1.2.3.10") (p "::1-::ff");
    expected = false;
  };
  isSubrange-yes = {
    expr = ipRange.isSubrangeOf (p "1.2.3.5-1.2.3.8") (p "1.2.3.4-1.2.3.10");
    expected = true;
  };
  isSubrange-no = {
    expr = ipRange.isSubrangeOf (p "1.2.3.4-1.2.3.10") (p "1.2.3.5-1.2.3.8");
    expected = false;
  };
  isSuperrange-yes = {
    expr = ipRange.isSuperrangeOf (p "1.2.3.4-1.2.3.10") (p "1.2.3.5-1.2.3.8");
    expected = true;
  };

  # ===== Merge =====
  merge-overlap = {
    expr = ipRange.toString (ipRange.merge (p "1.2.3.4-1.2.3.10") (p "1.2.3.8-1.2.3.15"));
    expected = "1.2.3.4-1.2.3.15";
  };
  merge-adjacent = {
    expr = ipRange.toString (ipRange.merge (p "1.2.3.4-1.2.3.10") (p "1.2.3.11-1.2.3.15"));
    expected = "1.2.3.4-1.2.3.15";
  };
  merge-disjoint = {
    expr = ipRange.merge (p "1.2.3.4-1.2.3.10") (p "1.2.3.20-1.2.3.30");
    expected = null;
  };
  merge-cross = {
    expr = ipRange.merge (p "1.2.3.4-1.2.3.10") (p "::1-::ff");
    expected = null;
  };
  merge-contains = {
    expr = ipRange.toString (ipRange.merge (p "1.2.3.0-1.2.3.255") (p "1.2.3.10-1.2.3.50"));
    expected = "1.2.3.0-1.2.3.255";
  };

  # ===== Enumeration =====
  addresses-small = {
    expr = map ipv4.toString (ipRange.addresses (p "1.2.3.4-1.2.3.6"));
    expected = [
      "1.2.3.4"
      "1.2.3.5"
      "1.2.3.6"
    ];
  };
  addresses-huge = {
    expr = throws (ipRange.addresses (p "1.0.0.0-2.0.0.0"));
    expected = true;
  };

  # ===== toCidrs =====
  toCidrs-aligned = {
    expr = map cidr.toString (ipRange.toCidrs (p "10.0.0.0-10.0.0.255"));
    expected = [ "10.0.0.0/24" ];
  };
  toCidrs-unaligned = {
    expr = map cidr.toString (ipRange.toCidrs (p "10.0.0.1-10.0.0.6"));
    expected = [
      "10.0.0.1/32"
      "10.0.0.2/31"
      "10.0.0.4/31"
      "10.0.0.6/32"
    ];
  };
  toCidrs-single = {
    expr = map cidr.toString (ipRange.toCidrs (p "1.2.3.4-1.2.3.4"));
    expected = [ "1.2.3.4/32" ];
  };
  toCidrs-v6 = {
    expr = map cidr.toString (ipRange.toCidrs (p "2001:db8::-2001:db8::ff"));
    expected = [ "2001:db8::/120" ];
  };

  fromCidr-v4 = {
    expr = ipRange.toString (ipRange.fromCidr (cidr.parse "10.0.0.0/24"));
    expected = "10.0.0.0-10.0.0.255";
  };
  fromCidr-v6 = {
    expr = ipRange.toString (ipRange.fromCidr (cidr.parse "2001:db8::/120"));
    expected = "2001:db8::-2001:db8::ff";
  };

  # ===== Comparison =====
  eq-same = {
    expr = ipRange.eq (p "1.2.3.4-1.2.3.10") (p "1.2.3.4-1.2.3.10");
    expected = true;
  };
  eq-diff = {
    expr = ipRange.eq (p "1.2.3.4-1.2.3.10") (p "1.2.3.4-1.2.3.11");
    expected = false;
  };
  compare-lt = {
    expr = ipRange.compare (p "1.0.0.0-1.0.0.10") (p "2.0.0.0-2.0.0.10");
    expected = -1;
  };
  compare-v4-v6 = {
    expr = ipRange.compare (p "1.2.3.4-1.2.3.10") (p "::1-::ff");
    expected = -1;
  };
}
