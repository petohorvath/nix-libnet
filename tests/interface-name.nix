{ harness }:
let
  ifName = import ../lib/interface-name.nix;
  inherit (harness) throws;
  p = ifName.parse;
in
{
  # ===== parse / toString / accessor =====
  parse-ok = {
    expr = (p "eth0").value;
    expected = "eth0";
  };
  parse-tagged = {
    expr = (p "eth0")._type;
    expected = "interfaceName";
  };
  toString-roundtrip = {
    expr = ifName.toString (p "br-home");
    expected = "br-home";
  };
  value-accessor = {
    expr = ifName.value (p "wg0");
    expected = "wg0";
  };

  # ===== isValid — kernel dev_valid_name parity =====
  isValid-ok = {
    expr = ifName.isValid "eth0";
    expected = true;
  };
  isValid-ok-15 = {
    expr = ifName.isValid "abcdefghijklmno";
    expected = true;
  };
  isValid-reject-empty = {
    expr = ifName.isValid "";
    expected = false;
  };
  isValid-reject-16 = {
    expr = ifName.isValid "abcdefghijklmnop";
    expected = false;
  };
  isValid-reject-dot = {
    expr = ifName.isValid ".";
    expected = false;
  };
  isValid-reject-dotdot = {
    expr = ifName.isValid "..";
    expected = false;
  };
  isValid-reject-slash = {
    expr = ifName.isValid "eth/0";
    expected = false;
  };
  isValid-reject-colon = {
    expr = ifName.isValid "eth:0";
    expected = false;
  };
  isValid-reject-space = {
    expr = ifName.isValid "eth 0";
    expected = false;
  };
  isValid-reject-tab = {
    expr = ifName.isValid "eth\t0";
    expected = false;
  };
  isValid-reject-newline = {
    expr = ifName.isValid "eth\n0";
    expected = false;
  };
  isValid-reject-cr = {
    expr = ifName.isValid "eth\r0";
    expected = false;
  };
  isValid-accepts-dash = {
    expr = ifName.isValid "br-home";
    expected = true;
  };
  isValid-accepts-dot-in-middle = {
    expr = ifName.isValid "vlan.100";
    expected = true;
  };
  isValid-accepts-underscore = {
    expr = ifName.isValid "wg_0";
    expected = true;
  };
  isValid-not-string = {
    expr = ifName.isValid 42;
    expected = false;
  };

  # ===== parse rejects (mirror validity) =====
  parse-reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  parse-reject-16 = {
    expr = throws (p "abcdefghijklmnop");
    expected = true;
  };
  parse-reject-slash = {
    expr = throws (p "eth/0");
    expected = true;
  };
  parse-not-string = {
    expr = throws (p 42);
    expected = true;
  };
  tryParse-ok = {
    expr = (ifName.tryParse "eth0").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (ifName.tryParse "").success;
    expected = false;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = ifName.is (p "eth0");
    expected = true;
  };
  is-string = {
    expr = ifName.is "eth0";
    expected = false;
  };

  # ===== Comparison =====
  eq-same = {
    expr = ifName.eq (p "eth0") (p "eth0");
    expected = true;
  };
  eq-diff = {
    expr = ifName.eq (p "eth0") (p "eth1");
    expected = false;
  };
  eq-case-sensitive = {
    expr = ifName.eq (p "Eth0") (p "eth0");
    expected = false;
  };
  compare-lt = {
    expr = ifName.compare (p "eth0") (p "eth1");
    expected = -1;
  };
  compare-eq = {
    expr = ifName.compare (p "eth0") (p "eth0");
    expected = 0;
  };
  compare-gt = {
    expr = ifName.compare (p "eth1") (p "eth0");
    expected = 1;
  };
  cmp-min = {
    expr = ifName.toString (ifName.min (p "eth1") (p "eth0"));
    expected = "eth0";
  };
  cmp-max = {
    expr = ifName.toString (ifName.max (p "eth1") (p "eth0"));
    expected = "eth1";
  };

  # ===== Constant =====
  ifnamsiz = {
    expr = ifName.ifnamsiz;
    expected = 16;
  };
}
