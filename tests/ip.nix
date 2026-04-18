{ harness }:
let
  ip   = import ../lib/ip.nix;
  ipv4 = import ../lib/ipv4.nix;
  ipv6 = import ../lib/ipv6.nix;
  inherit (harness) throws;
  p = ip.parse;
in
{
  # ===== Dispatch parse =====
  parse-v4          = { expr = ip.version (p "1.2.3.4");    expected = 4; };
  parse-v6          = { expr = ip.version (p "::1");         expected = 6; };
  parse-rejects-bad = { expr = throws (p "bogus");           expected = true; };
  tryParse-v4       = { expr = (ip.tryParse "1.2.3.4").success; expected = true; };
  tryParse-v6       = { expr = (ip.tryParse "::1").success;     expected = true; };
  tryParse-bad      = { expr = (ip.tryParse "bad").success;     expected = false; };

  # ===== version / is predicates =====
  isIpv4-v4         = { expr = ip.isIpv4 (p "1.2.3.4"); expected = true; };
  isIpv4-v6         = { expr = ip.isIpv4 (p "::1");      expected = false; };
  isIpv6-v6         = { expr = ip.isIpv6 (p "::1");      expected = true; };
  is-string         = { expr = ip.is "1.2.3.4";          expected = false; };
  is-parsed         = { expr = ip.is (p "1.2.3.4");     expected = true; };

  toString-v4       = { expr = ip.toString (p "1.2.3.4");  expected = "1.2.3.4"; };
  toString-v6       = { expr = ip.toString (p "2001:db8::1"); expected = "2001:db8::1"; };

  # ===== Forwarded predicates: dispatch by family =====
  loopback-v4       = { expr = ip.isLoopback (p "127.0.0.1"); expected = true; };
  loopback-v6       = { expr = ip.isLoopback (p "::1");        expected = true; };
  loopback-no-v4    = { expr = ip.isLoopback (p "8.8.8.8");    expected = false; };
  loopback-no-v6    = { expr = ip.isLoopback (p "2001:db8::1"); expected = false; };

  unspec-v4         = { expr = ip.isUnspecified (p "0.0.0.0"); expected = true; };
  unspec-v6         = { expr = ip.isUnspecified (p "::");       expected = true; };

  link-v4           = { expr = ip.isLinkLocal (p "169.254.1.1"); expected = true; };
  link-v6           = { expr = ip.isLinkLocal (p "fe80::1");      expected = true; };

  mcast-v4          = { expr = ip.isMulticast (p "224.0.0.1"); expected = true; };
  mcast-v6          = { expr = ip.isMulticast (p "ff00::1");    expected = true; };

  doc-v4            = { expr = ip.isDocumentation (p "192.0.2.1");    expected = true; };
  doc-v6            = { expr = ip.isDocumentation (p "2001:db8::1"); expected = true; };

  global-v4         = { expr = ip.isGlobal (p "8.8.8.8");                expected = true; };
  global-v6         = { expr = ip.isGlobal (p "2606:4700:4700::1111"); expected = true; };

  bogon-v4          = { expr = ip.isBogon (p "127.0.0.1"); expected = true; };
  bogon-v6          = { expr = ip.isBogon (p "::1");        expected = true; };
  bogon-public-v4   = { expr = ip.isBogon (p "8.8.8.8");   expected = false; };

  arpa-v4           = { expr = ip.toArpa (p "1.2.3.4");     expected = "4.3.2.1.in-addr.arpa"; };
  arpa-v6           = { expr = ip.toArpa (p "::1");
                        expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa"; };

  # ===== Comparison =====
  eq-v4-v4          = { expr = ip.eq (p "1.2.3.4") (p "1.2.3.4"); expected = true; };
  eq-v4-v6          = { expr = ip.eq (p "1.2.3.4") (p "::1");     expected = false; };
  eq-v6-v6          = { expr = ip.eq (p "::1") (p "::1");          expected = true; };

  compare-v4-v6     = { expr = ip.compare (p "255.255.255.255") (p "::");  expected = -1; };  # v4 < v6
  compare-v6-v4     = { expr = ip.compare (p "::") (p "0.0.0.0");          expected = 1; };
  compare-same-v4   = { expr = ip.compare (p "1.2.3.4") (p "1.2.3.4");     expected = 0; };
  lt-cross          = { expr = ip.lt (p "255.255.255.255") (p "::");       expected = true; };

  min-cross         = { expr = ip.toString (ip.min (p "1.2.3.4") (p "::1")); expected = "1.2.3.4"; };
  max-cross         = { expr = ip.toString (ip.max (p "1.2.3.4") (p "::1")); expected = "::1"; };

  # ===== Arithmetic dispatch =====
  add-v4            = { expr = ip.toString (ip.add 1 (p "1.2.3.4")); expected = "1.2.3.5"; };
  add-v6            = { expr = ip.toString (ip.add 1 (p "::1"));      expected = "::2"; };
  sub-v4            = { expr = ip.toString (ip.sub 1 (p "1.2.3.5")); expected = "1.2.3.4"; };
  next-v4           = { expr = ip.toString (ip.next (p "1.2.3.4")); expected = "1.2.3.5"; };
  next-v6           = { expr = ip.toString (ip.next (p "::1"));      expected = "::2"; };
  prev-v4           = { expr = ip.toString (ip.prev (p "1.2.3.5")); expected = "1.2.3.4"; };
  diff-v4           = { expr = ip.diff (p "1.2.3.4") (p "1.2.3.10"); expected = 6; };
  diff-v6           = { expr = ip.diff (p "::1") (p "::10");         expected = 15; };
  diff-cross        = { expr = throws (ip.diff (p "1.2.3.4") (p "::1")); expected = true; };

  # ===== Sort mixed list (stable v4-before-v6) =====
  sort-mixed        = {
    expr = map ip.toString (builtins.sort (a: b: ip.lt a b)
             [ (p "::1") (p "1.2.3.4") (p "::") (p "0.0.0.1") ]);
    expected = [ "0.0.0.1" "1.2.3.4" "::" "::1" ];
  };
}
