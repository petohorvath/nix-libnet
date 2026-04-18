{ harness }:
let
  lst      = import ../lib/listener.nix;
  ipv4     = import ../lib/ipv4.nix;
  ipv6     = import ../lib/ipv6.nix;
  port     = import ../lib/port.nix;
  pr       = import ../lib/portRange.nix;
  endpoint = import ../lib/endpoint.nix;
  inherit (harness) throws;
  p = lst.parse;
in
{
  # ===== Parse =====
  parse-null-single = { expr = lst.toString (p ":8080");            expected = ":8080"; };
  parse-null-range  = { expr = lst.toString (p ":8080-8090");       expected = ":8080-8090"; };
  parse-wild-star   = { expr = lst.toString (p "*:8080");           expected = ":8080"; };
  parse-wild-any    = { expr = lst.toString (p "any:8080");         expected = ":8080"; };
  parse-v4-single   = { expr = lst.toString (p "1.2.3.4:8080");     expected = "1.2.3.4:8080"; };
  parse-v4-range    = { expr = lst.toString (p "1.2.3.4:5000-6000"); expected = "1.2.3.4:5000-6000"; };
  parse-v4-explicit = { expr = lst.toString (p "0.0.0.0:80");       expected = "0.0.0.0:80"; };
  parse-v6-range    = { expr = lst.toString (p "[::1]:5000-6000");  expected = "[::1]:5000-6000"; };
  parse-v6-explicit = { expr = lst.toString (p "[::]:80");          expected = "[::]:80"; };
  parse-v6-single   = { expr = lst.toString (p "[::1]:80");         expected = "[::1]:80"; };

  # ===== Reject =====
  reject-v6-unbrak  = { expr = throws (p "::1:80");            expected = true; };
  reject-bad-port   = { expr = throws (p ":70000");            expected = true; };
  reject-open-range = { expr = throws (p "1.2.3.4:5500-");     expected = true; };
  reject-reverse    = { expr = throws (p "1.2.3.4:6000-5500"); expected = true; };
  reject-not-string = { expr = throws (lst.parse 123);         expected = true; };

  # ===== tryParse =====
  tryParse-ok       = { expr = (lst.tryParse ":80").success; expected = true; };
  tryParse-bad      = { expr = (lst.tryParse "bad").success; expected = false; };

  # ===== Predicates =====
  is-parsed         = { expr = lst.is (p ":80");    expected = true; };
  is-string         = { expr = lst.is ":80";         expected = false; };
  isValid-ok        = { expr = lst.isValid ":80";    expected = true; };

  # ===== isAnyAddress variants =====
  anyAddr-null      = { expr = lst.isAnyAddress (p ":80");         expected = true; };
  anyAddr-star      = { expr = lst.isAnyAddress (p "*:80");        expected = true; };
  anyAddr-any       = { expr = lst.isAnyAddress (p "any:80");      expected = true; };
  anyAddr-0000      = { expr = lst.isAnyAddress (p "0.0.0.0:80");  expected = true; };
  anyAddr-v6-any    = { expr = lst.isAnyAddress (p "[::]:80");     expected = true; };
  anyAddr-no        = { expr = lst.isAnyAddress (p "1.2.3.4:80");  expected = false; };
  anyAddr-v6-loop   = { expr = lst.isAnyAddress (p "[::1]:80");    expected = false; };
  isWildcard-alias  = { expr = lst.isWildcard (p ":80");           expected = true; };

  # ===== isRange =====
  isRange-single    = { expr = lst.isRange (p ":80");          expected = false; };
  isRange-range     = { expr = lst.isRange (p ":80-90");       expected = true; };

  # ===== Family =====
  isIpv4-v4         = { expr = lst.isIpv4 (p "1.2.3.4:80"); expected = true; };
  isIpv4-null       = { expr = lst.isIpv4 (p ":80");         expected = false; };
  isIpv6-v6         = { expr = lst.isIpv6 (p "[::1]:80");    expected = true; };
  version-v4        = { expr = lst.version (p "1.2.3.4:80"); expected = 4; };
  version-null      = { expr = lst.version (p ":80");         expected = null; };

  # ===== Expansion =====
  toEndpoints       = {
    expr = map endpoint.toString (lst.toEndpoints (p "1.2.3.4:80-82"));
    expected = [ "1.2.3.4:80" "1.2.3.4:81" "1.2.3.4:82" ];
  };
  toEndpoints-v6    = {
    expr = map endpoint.toString (lst.toEndpoints (p "[::1]:80-81"));
    expected = [ "[::1]:80" "[::1]:81" ];
  };
  toEndpoints-null  = { expr = throws (lst.toEndpoints (p ":80-82")); expected = true; };
  toEndpoints-big   = { expr = throws (lst.toEndpoints (p "1.2.3.4:0-5000")); expected = true; };

  endpoint-at-0     = { expr = endpoint.toString (lst.endpoint 0 (p "1.2.3.4:80-82"));
                        expected = "1.2.3.4:80"; };
  endpoint-at-2     = { expr = endpoint.toString (lst.endpoint 2 (p "1.2.3.4:80-82"));
                        expected = "1.2.3.4:82"; };
  endpoint-at-neg   = { expr = endpoint.toString (lst.endpoint (-1) (p "1.2.3.4:80-82"));
                        expected = "1.2.3.4:82"; };
  endpoint-oob      = { expr = throws (lst.endpoint 3 (p "1.2.3.4:80-82")); expected = true; };
  endpoint-null     = { expr = throws (lst.endpoint 0 (p ":80-82"));        expected = true; };

  # ===== Comparison =====
  eq-same           = { expr = lst.eq (p ":80") (p ":80");              expected = true; };
  eq-null-vs-expl   = { expr = lst.eq (p ":80") (p "0.0.0.0:80");        expected = false; };
  compare-null-v4   = { expr = lst.compare (p ":80") (p "0.0.0.0:80");   expected = -1; };
  compare-v4-v6     = { expr = lst.compare (p "1.2.3.4:80") (p "[::1]:80"); expected = -1; };
  compare-same      = { expr = lst.compare (p ":80") (p ":80");           expected = 0; };
  lt-null-first     = { expr = lst.lt (p ":80") (p "0.0.0.0:80");         expected = true; };
}
