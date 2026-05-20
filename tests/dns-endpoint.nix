{ harness }:
let
  dnsEndpoint = import ../lib/dns-endpoint.nix;
  dnsName = import ../lib/dns-name.nix;
  port = import ../lib/port.nix;
  inherit (harness) throws;
  p = dnsEndpoint.parse;
in
{
  # ===== Parse =====
  parse-hostname = {
    expr = dnsEndpoint.toString (p "nas:22");
    expected = "nas:22";
  };
  parse-domain = {
    expr = dnsEndpoint.toString (p "pool.ntp.org:123");
    expected = "pool.ntp.org:123";
  };
  parse-tagged = {
    expr = (p "nas:22")._type;
    expected = "dnsEndpoint";
  };
  parse-address-hostname = {
    expr = (dnsEndpoint.address (p "nas:22")).value;
    expected = "nas";
  };
  parse-address-domain = {
    expr = (dnsEndpoint.address (p "pool.ntp.org:123")).value;
    expected = "pool.ntp.org";
  };
  parse-port = {
    expr = port.toInt (dnsEndpoint.port (p "nas:22"));
    expected = 22;
  };
  parse-preserves-case = {
    expr = dnsEndpoint.toString (p "MyHost.Example.COM:443");
    expected = "MyHost.Example.COM:443";
  };

  # ===== Reject =====
  reject-ipv4 = {
    expr = throws (p "192.0.2.1:80");
    expected = true;
  };
  reject-bracketed-ipv6 = {
    expr = throws (p "[::1]:443");
    expected = true;
  };
  reject-no-port = {
    expr = throws (p "nas");
    expected = true;
  };
  reject-empty-port = {
    expr = throws (p "nas:");
    expected = true;
  };
  reject-bad-port = {
    expr = throws (p "nas:99999");
    expected = true;
  };
  reject-underscore = {
    expr = throws (p "host_name:22");
    expected = true;
  };
  reject-multi-colon = {
    expr = throws (p "a:b:22");
    expected = true;
  };
  reject-not-string = {
    expr = throws (dnsEndpoint.parse 42);
    expected = true;
  };

  tryParse-ok = {
    expr = (dnsEndpoint.tryParse "nas:22").success;
    expected = true;
  };
  tryParse-ip-rejected = {
    expr = (dnsEndpoint.tryParse "192.0.2.1:80").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (dnsEndpoint.tryParse "192.0.2.1:80").error;
    expected = true;
  };

  # ===== make =====
  make-ok = {
    expr = dnsEndpoint.toString (dnsEndpoint.make (dnsName.parse "nas") (port.fromInt 22));
    expected = "nas:22";
  };
  make-bad-address = {
    expr = throws (dnsEndpoint.make "nas" (port.fromInt 22));
    expected = true;
  };
  make-bad-port = {
    expr = throws (dnsEndpoint.make (dnsName.parse "nas") 22);
    expected = true;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = dnsEndpoint.is (p "nas:22");
    expected = true;
  };
  is-string = {
    expr = dnsEndpoint.is "nas:22";
    expected = false;
  };
  isValid-ok = {
    expr = dnsEndpoint.isValid "pool.ntp.org:123";
    expected = true;
  };
  isValid-ip = {
    expr = dnsEndpoint.isValid "192.0.2.1:80";
    expected = false;
  };
  isHostname-yes = {
    expr = dnsEndpoint.isHostname (p "nas:22");
    expected = true;
  };
  isHostname-no = {
    expr = dnsEndpoint.isHostname (p "example.com:80");
    expected = false;
  };
  isDomain-yes = {
    expr = dnsEndpoint.isDomain (p "example.com:80");
    expected = true;
  };
  isDomain-no = {
    expr = dnsEndpoint.isDomain (p "nas:22");
    expected = false;
  };

  # ===== Comparison helpers =====
  cmp-lt = {
    expr = dnsEndpoint.lt (p "alpha:80") (p "beta:80");
    expected = true;
  };
  cmp-le = {
    expr = dnsEndpoint.le (p "alpha:80") (p "beta:80");
    expected = true;
  };
  cmp-gt = {
    expr = dnsEndpoint.gt (p "beta:80") (p "alpha:80");
    expected = true;
  };
  cmp-ge = {
    expr = dnsEndpoint.ge (p "beta:80") (p "alpha:80");
    expected = true;
  };
  cmp-min = {
    expr = dnsEndpoint.toString (dnsEndpoint.min (p "alpha:80") (p "beta:80"));
    expected = "alpha:80";
  };
  cmp-max = {
    expr = dnsEndpoint.toString (dnsEndpoint.max (p "alpha:80") (p "beta:80"));
    expected = "beta:80";
  };

  # ===== Comparison =====
  eq-same = {
    expr = dnsEndpoint.eq (p "nas:22") (p "nas:22");
    expected = true;
  };
  eq-case-insens = {
    expr = dnsEndpoint.eq (p "NAS:22") (p "nas:22");
    expected = true;
  };
  eq-diff-port = {
    expr = dnsEndpoint.eq (p "nas:22") (p "nas:23");
    expected = false;
  };
  eq-diff-host = {
    expr = dnsEndpoint.eq (p "nas:22") (p "router:22");
    expected = false;
  };
  compare-by-host = {
    expr = dnsEndpoint.compare (p "alpha:80") (p "beta:80");
    expected = -1;
  };
  compare-by-port = {
    expr = dnsEndpoint.compare (p "nas:22") (p "nas:80");
    expected = -1;
  };
  compare-equal = {
    expr = dnsEndpoint.compare (p "NAS:22") (p "nas:22");
    expected = 0;
  };
}
