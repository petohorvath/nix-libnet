{ harness }:
let
  dnsName = import ../lib/dns-name.nix;
  hostname = import ../lib/hostname.nix;
  domain = import ../lib/domain.nix;
  inherit (harness) throws;
  p = dnsName.parse;
in
{
  # ===== Dispatch =====
  parse-hostname-tagged = {
    expr = (p "nas")._type;
    expected = "hostname";
  };
  parse-domain-tagged = {
    expr = (p "pool.ntp.org")._type;
    expected = "domain";
  };
  parse-hostname-value = {
    expr = (p "nas").value;
    expected = "nas";
  };
  parse-domain-value = {
    expr = (p "example.com").value;
    expected = "example.com";
  };
  parse-mixed-case = {
    expr = (p "MyHost").value;
    expected = "MyHost";
  };

  # ===== IP literals rejected =====
  reject-ipv4 = {
    expr = throws (p "192.0.2.1");
    expected = true;
  };
  reject-ipv6 = {
    expr = throws (p "::1");
    expected = true;
  };
  reject-ipv4-via-tryParse = {
    expr = (dnsName.tryParse "10.0.0.1").success;
    expected = false;
  };
  # A 4-numeric-label string that is NOT a valid IP is still a domain.
  parse-numeric-not-ip = {
    expr = (p "192.0.2.300")._type;
    expected = "domain";
  };

  # ===== Other rejects =====
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
  reject-not-string = {
    expr = throws (dnsName.parse 42);
    expected = true;
  };

  tryParse-ok-hostname = {
    expr = (dnsName.tryParse "nas").success;
    expected = true;
  };
  tryParse-ok-domain = {
    expr = (dnsName.tryParse "example.com").success;
    expected = true;
  };
  tryParse-bad-error = {
    expr = builtins.isString (dnsName.tryParse "192.0.2.1").error;
    expected = true;
  };

  # ===== toString =====
  toString-hostname = {
    expr = dnsName.toString (p "nas");
    expected = "nas";
  };
  toString-domain = {
    expr = dnsName.toString (p "example.com");
    expected = "example.com";
  };
  toString-preserves-case = {
    expr = dnsName.toString (p "Example.COM");
    expected = "Example.COM";
  };

  # ===== Predicates =====
  is-hostname = {
    expr = dnsName.is (p "nas");
    expected = true;
  };
  is-domain = {
    expr = dnsName.is (p "example.com");
    expected = true;
  };
  is-string = {
    expr = dnsName.is "nas";
    expected = false;
  };
  isHostname-yes = {
    expr = dnsName.isHostname (p "nas");
    expected = true;
  };
  isHostname-no = {
    expr = dnsName.isHostname (p "example.com");
    expected = false;
  };
  isDomain-yes = {
    expr = dnsName.isDomain (p "example.com");
    expected = true;
  };
  isDomain-no = {
    expr = dnsName.isDomain (p "nas");
    expected = false;
  };
  isValid-hostname = {
    expr = dnsName.isValid "nas";
    expected = true;
  };
  isValid-domain = {
    expr = dnsName.isValid "example.com";
    expected = true;
  };
  isValid-ip = {
    expr = dnsName.isValid "192.0.2.1";
    expected = false;
  };
  isValid-bad = {
    expr = dnsName.isValid "host_name";
    expected = false;
  };

  # ===== Normalize =====
  normalize-hostname = {
    expr = (dnsName.normalize (p "MyHost")).value;
    expected = "myhost";
  };
  normalize-domain = {
    expr = (dnsName.normalize (p "Example.COM")).value;
    expected = "example.com";
  };

  # ===== eq =====
  # ===== Comparison helpers =====
  cmp-lt = {
    expr = dnsName.lt (dnsName.parse "alpha") (dnsName.parse "beta");
    expected = true;
  };
  cmp-le = {
    expr = dnsName.le (dnsName.parse "alpha") (dnsName.parse "beta");
    expected = true;
  };
  cmp-gt = {
    expr = dnsName.gt (dnsName.parse "beta") (dnsName.parse "alpha");
    expected = true;
  };
  cmp-ge = {
    expr = dnsName.ge (dnsName.parse "beta") (dnsName.parse "alpha");
    expected = true;
  };
  cmp-min = {
    expr = dnsName.toString (dnsName.min (dnsName.parse "alpha") (dnsName.parse "beta"));
    expected = "alpha";
  };
  cmp-max = {
    expr = dnsName.toString (dnsName.max (dnsName.parse "alpha") (dnsName.parse "beta"));
    expected = "beta";
  };

  eq-same-hostname = {
    expr = dnsName.eq (p "nas") (p "nas");
    expected = true;
  };
  eq-hostname-case = {
    expr = dnsName.eq (p "NAS") (p "nas");
    expected = true;
  };
  eq-domain-case = {
    expr = dnsName.eq (p "EXAMPLE.COM") (p "example.com");
    expected = true;
  };
  eq-hostname-vs-domain = {
    expr = dnsName.eq (p "nas") (p "example.com");
    expected = false;
  };

  # ===== compare =====
  compare-hostname-before-domain = {
    expr = dnsName.compare (p "zzz") (p "a.com");
    expected = -1;
  };
  compare-domain-after-hostname = {
    expr = dnsName.compare (p "a.com") (p "zzz");
    expected = 1;
  };
  compare-within-hostname = {
    expr = dnsName.compare (p "alpha") (p "beta");
    expected = -1;
  };
  compare-within-domain = {
    expr = dnsName.compare (p "alpha.com") (p "beta.com");
    expected = -1;
  };
  compare-equal-case = {
    expr = dnsName.compare (p "NAS") (p "nas");
    expected = 0;
  };

  # Sanity: recognises values from each underlying module
  is-from-hostname-module = {
    expr = dnsName.is (hostname.parse "nas");
    expected = true;
  };
  is-from-domain-module = {
    expr = dnsName.is (domain.parse "example.com");
    expected = true;
  };
}
