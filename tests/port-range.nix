{ harness }:
let
  pr = import ../lib/port-range.nix;
  port = import ../lib/port.nix;
  inherit (harness) throws;
  p = pr.parse;
in
{
  # ===== Parse =====
  parse-single = {
    expr = pr.toString (p "8080");
    expected = "8080";
  };
  parse-hyphen = {
    expr = pr.toString (p "5500-6000");
    expected = "5500-6000";
  };
  parse-colon = {
    expr = pr.toString (p "5500:6000");
    expected = "5500-6000";
  }; # canonical is hyphen
  parse-same = {
    expr = pr.toString (p "80-80");
    expected = "80";
  }; # singleton canonical

  reject-reversed = {
    expr = throws (p "6000-5500");
    expected = true;
  };
  reject-neg = {
    expr = throws (p "-1-10");
    expected = true;
  };
  reject-over = {
    expr = throws (p "0-65536");
    expected = true;
  };
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };

  # ===== Formatting =====
  fmt-colon = {
    expr = pr.toStringColon (p "5500-6000");
    expected = "5500:6000";
  };
  fmt-colon-single = {
    expr = pr.toStringColon (p "80");
    expected = "80";
  };

  # ===== make / fromPort =====
  make-ok = {
    expr = pr.toString (pr.make 100 200);
    expected = "100-200";
  };
  make-single = {
    expr = pr.toString (pr.make 80 80);
    expected = "80";
  };
  make-reverse = {
    expr = throws (pr.make 200 100);
    expected = true;
  };
  make-over = {
    expr = throws (pr.make 0 65536);
    expected = true;
  };
  fromPort-ok = {
    expr = pr.toString (pr.fromPort (port.fromInt 80));
    expected = "80";
  };

  # ===== Predicates =====
  is-parsed = {
    expr = pr.is (p "80");
    expected = true;
  };
  is-string = {
    expr = pr.is "80";
    expected = false;
  };
  isValid-ok = {
    expr = pr.isValid "80-90";
    expected = true;
  };
  isSingle-yes = {
    expr = pr.isSingleton (p "80");
    expected = true;
  };
  isSingle-no = {
    expr = pr.isSingleton (p "80-90");
    expected = false;
  };

  # ===== Accessors =====
  from-val = {
    expr = pr.from (p "80-90");
    expected = 80;
  };
  to-val = {
    expr = pr.to (p "80-90");
    expected = 90;
  };
  size-single = {
    expr = pr.size (p "80");
    expected = 1;
  };
  size-range = {
    expr = pr.size (p "80-90");
    expected = 11;
  };
  size-full = {
    expr = pr.size (p "0-65535");
    expected = 65536;
  };

  # ===== Containment =====
  contains-in = {
    expr = pr.contains (p "80-90") (port.fromInt 85);
    expected = true;
  };
  contains-from = {
    expr = pr.contains (p "80-90") (port.fromInt 80);
    expected = true;
  };
  contains-to = {
    expr = pr.contains (p "80-90") (port.fromInt 90);
    expected = true;
  };
  contains-out = {
    expr = pr.contains (p "80-90") (port.fromInt 91);
    expected = false;
  };
  overlaps-yes = {
    expr = pr.overlaps (p "80-90") (p "85-95");
    expected = true;
  };
  overlaps-touch = {
    expr = pr.overlaps (p "80-90") (p "90-100");
    expected = true;
  };
  overlaps-no = {
    expr = pr.overlaps (p "80-90") (p "91-100");
    expected = false;
  };
  subrange-yes = {
    expr = pr.isSubrangeOf (p "82-88") (p "80-90");
    expected = true;
  };
  subrange-no = {
    expr = pr.isSubrangeOf (p "80-90") (p "82-88");
    expected = false;
  };
  superrange-yes = {
    expr = pr.isSuperrangeOf (p "80-90") (p "82-88");
    expected = true;
  };

  # ===== Merge =====
  merge-adjacent = {
    expr = pr.toString (pr.merge (p "80-90") (p "91-100"));
    expected = "80-100";
  };
  merge-overlap = {
    expr = pr.toString (pr.merge (p "80-90") (p "85-100"));
    expected = "80-100";
  };
  merge-contain = {
    expr = pr.toString (pr.merge (p "80-100") (p "85-90"));
    expected = "80-100";
  };
  merge-disjoint = {
    expr = pr.merge (p "80-90") (p "100-110");
    expected = null;
  };

  # ===== Enumeration =====
  ports-small = {
    expr = map port.toInt (pr.ports (p "80-83"));
    expected = [
      80
      81
      82
      83
    ];
  };
  ports-single = {
    expr = map port.toInt (pr.ports (p "80"));
    expected = [ 80 ];
  };
  ports-4096-ok = {
    expr = builtins.length (pr.ports (p "0-4095"));
    expected = 4096;
  };
  ports-4097-throw = {
    expr = throws (pr.ports (p "0-4096"));
    expected = true;
  };
  ports-unbounded = {
    expr = builtins.length (pr.portsUnbounded (p "0-4096"));
    expected = 4097;
  };

  # ===== Comparison =====
  eq-same = {
    expr = pr.eq (p "80-90") (p "80-90");
    expected = true;
  };
  eq-diff = {
    expr = pr.eq (p "80-90") (p "80-91");
    expected = false;
  };
  compare-from-lt = {
    expr = pr.compare (p "80-100") (p "81-82");
    expected = -1;
  };
  compare-same-from = {
    expr = pr.compare (p "80-90") (p "80-100");
    expected = -1;
  };
  compare-eq = {
    expr = pr.compare (p "80-90") (p "80-90");
    expected = 0;
  };
}
