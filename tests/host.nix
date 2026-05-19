{ harness }:
let
  host = import ../lib/host.nix;
  ip = import ../lib/ip.nix;
  hostname = import ../lib/hostname.nix;
  domain = import ../lib/domain.nix;
  inherit (harness) throws;
  p = host.parse;
in
{
  # ===== Dispatch =====
  parse-ipv4-tagged = {
    expr = (p "192.168.1.1")._type;
    expected = "ipv4";
  };
  parse-ipv6-tagged = {
    expr = (p "::1")._type;
    expected = "ipv6";
  };
  parse-hostname-tagged = {
    expr = (p "nas")._type;
    expected = "hostname";
  };
  parse-hostname-mixed-case = {
    expr = (p "MyHost")._type;
    expected = "hostname";
  };
  parse-domain-tagged = {
    expr = (p "example.com")._type;
    expected = "domain";
  };
  parse-deep-domain-tagged = {
    expr = (p "a.b.c.example.com")._type;
    expected = "domain";
  };
  # Dispatch order: IP wins over domain for dotted-quad strings.
  parse-dotted-quad-as-ip = {
    expr = (p "10.0.0.1")._type;
    expected = "ipv4";
  };
  parse-ipv4-value = {
    expr = ip.toString (p "192.168.1.1");
    expected = "192.168.1.1";
  };
  parse-hostname-value = {
    expr = (p "nas").value;
    expected = "nas";
  };
  parse-domain-value = {
    expr = (p "example.com").value;
    expected = "example.com";
  };

  # ===== Reject =====
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-underscore = {
    expr = throws (p "host_name");
    expected = true;
  };
  reject-trailing-dot = {
    expr = throws (p "example.com.");
    expected = true;
  };
  reject-leading-dot = {
    expr = throws (p ".example.com");
    expected = true;
  };
  reject-whitespace = {
    expr = throws (p "my host");
    expected = true;
  };
  reject-not-string = {
    expr = throws (host.parse 42);
    expected = true;
  };

  tryParse-ok-ip = {
    expr = (host.tryParse "192.168.1.1").success;
    expected = true;
  };
  tryParse-ok-hostname = {
    expr = (host.tryParse "nas").success;
    expected = true;
  };
  tryParse-ok-domain = {
    expr = (host.tryParse "example.com").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (host.tryParse "host_name").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (host.tryParse "host_name").error;
    expected = true;
  };

  # ===== toString (dispatches) =====
  toString-ipv4 = {
    expr = host.toString (p "192.168.1.1");
    expected = "192.168.1.1";
  };
  toString-ipv6 = {
    expr = host.toString (p "::1");
    expected = "::1";
  };
  toString-hostname = {
    expr = host.toString (p "nas");
    expected = "nas";
  };
  toString-domain = {
    expr = host.toString (p "example.com");
    expected = "example.com";
  };
  toString-hostname-preserves-case = {
    expr = host.toString (p "MyHost");
    expected = "MyHost";
  };
  toString-untagged-throws = {
    expr = throws (host.toString { value = "nope"; });
    expected = true;
  };

  # ===== Predicates =====
  is-ip = {
    expr = host.is (p "192.168.1.1");
    expected = true;
  };
  is-hostname = {
    expr = host.is (p "nas");
    expected = true;
  };
  is-domain = {
    expr = host.is (p "example.com");
    expected = true;
  };
  is-string = {
    expr = host.is "nas";
    expected = false;
  };
  is-untagged = {
    expr = host.is { value = "nas"; };
    expected = false;
  };

  isIp-ip = {
    expr = host.isIp (p "10.0.0.1");
    expected = true;
  };
  isIp-hostname = {
    expr = host.isIp (p "nas");
    expected = false;
  };
  isIp-domain = {
    expr = host.isIp (p "example.com");
    expected = false;
  };

  isHostname-hostname = {
    expr = host.isHostname (p "nas");
    expected = true;
  };
  isHostname-ip = {
    expr = host.isHostname (p "10.0.0.1");
    expected = false;
  };
  isHostname-domain = {
    expr = host.isHostname (p "example.com");
    expected = false;
  };

  isDomain-domain = {
    expr = host.isDomain (p "example.com");
    expected = true;
  };
  isDomain-hostname = {
    expr = host.isDomain (p "nas");
    expected = false;
  };
  isDomain-ip = {
    expr = host.isDomain (p "10.0.0.1");
    expected = false;
  };

  isName-hostname = {
    expr = host.isName (p "nas");
    expected = true;
  };
  isName-domain = {
    expr = host.isName (p "example.com");
    expected = true;
  };
  isName-ip = {
    expr = host.isName (p "10.0.0.1");
    expected = false;
  };

  isValid-ip = {
    expr = host.isValid "192.168.1.1";
    expected = true;
  };
  isValid-hostname = {
    expr = host.isValid "nas";
    expected = true;
  };
  isValid-domain = {
    expr = host.isValid "example.com";
    expected = true;
  };
  isValid-bad = {
    expr = host.isValid "host_name";
    expected = false;
  };
  isValid-not-string = {
    expr = host.isValid 42;
    expected = false;
  };

  # ===== eq =====
  eq-same-ipv4 = {
    expr = host.eq (p "10.0.0.1") (p "10.0.0.1");
    expected = true;
  };
  eq-same-hostname = {
    expr = host.eq (p "nas") (p "nas");
    expected = true;
  };
  eq-same-domain = {
    expr = host.eq (p "example.com") (p "example.com");
    expected = true;
  };
  eq-hostname-case-insens = {
    expr = host.eq (p "NAS") (p "nas");
    expected = true;
  };
  eq-domain-case-insens = {
    expr = host.eq (p "EXAMPLE.COM") (p "example.com");
    expected = true;
  };
  eq-ip-vs-hostname = {
    expr = host.eq (p "10.0.0.1") (p "nas");
    expected = false;
  };
  eq-hostname-vs-domain = {
    expr = host.eq (p "nas") (p "example.com");
    expected = false;
  };
  eq-ipv4-vs-ipv6 = {
    expr = host.eq (p "0.0.0.0") (p "::");
    expected = false;
  };
  eq-untagged = {
    expr = host.eq (p "nas") { value = "nas"; };
    expected = false;
  };

  # ===== compare =====
  compare-ip-before-hostname = {
    expr = host.compare (p "10.0.0.1") (p "nas");
    expected = -1;
  };
  compare-hostname-before-domain = {
    expr = host.compare (p "nas") (p "example.com");
    expected = -1;
  };
  compare-domain-after-ip = {
    expr = host.compare (p "example.com") (p "10.0.0.1");
    expected = 1;
  };
  compare-ipv4-before-ipv6 = {
    expr = host.compare (p "10.0.0.1") (p "::1");
    expected = -1;
  };
  compare-same-ipv4-eq = {
    expr = host.compare (p "10.0.0.1") (p "10.0.0.1");
    expected = 0;
  };
  compare-same-hostname-case = {
    expr = host.compare (p "NAS") (p "nas");
    expected = 0;
  };
  compare-same-domain-case = {
    expr = host.compare (p "EXAMPLE.COM") (p "example.com");
    expected = 0;
  };
  compare-within-hostname-lex = {
    expr = host.compare (p "alpha") (p "beta");
    expected = -1;
  };
  compare-within-domain-lex = {
    expr = host.compare (p "alpha.com") (p "beta.com");
    expected = -1;
  };
  compare-within-ipv4 = {
    expr = host.compare (p "10.0.0.1") (p "10.0.0.2");
    expected = -1;
  };

  lt-ip-vs-hostname = {
    expr = host.lt (p "10.0.0.1") (p "nas");
    expected = true;
  };
  le-equal = {
    expr = host.le (p "nas") (p "nas");
    expected = true;
  };
  ge-equal = {
    expr = host.ge (p "nas") (p "nas");
    expected = true;
  };
  gt-hostname-vs-ip = {
    expr = host.gt (p "nas") (p "10.0.0.1");
    expected = true;
  };
  min-picks-smaller-family = {
    expr = (host.min (p "nas") (p "10.0.0.1"))._type;
    expected = "ipv4";
  };
  max-picks-larger-family = {
    expr = (host.max (p "10.0.0.1") (p "example.com"))._type;
    expected = "domain";
  };

  # Sanity: structural .is checks recognise values from each underlying module
  is-from-ip-module = {
    expr = host.is (ip.parse "10.0.0.1");
    expected = true;
  };
  is-from-hostname-module = {
    expr = host.is (hostname.parse "nas");
    expected = true;
  };
  is-from-domain-module = {
    expr = host.is (domain.parse "example.com");
    expected = true;
  };
}
