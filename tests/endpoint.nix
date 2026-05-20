{ harness }:
let
  endpoint = import ../lib/endpoint.nix;
  ipEndpoint = import ../lib/ip-endpoint.nix;
  dnsEndpoint = import ../lib/dns-endpoint.nix;
  inherit (harness) throws;
  p = endpoint.parse;
in
{
  # ===== Dispatch =====
  parse-ipv4-tagged = {
    expr = (p "192.0.2.1:80")._type;
    expected = "ipEndpoint";
  };
  parse-ipv6-tagged = {
    expr = (p "[::1]:443")._type;
    expected = "ipEndpoint";
  };
  parse-hostname-tagged = {
    expr = (p "nas:22")._type;
    expected = "dnsEndpoint";
  };
  parse-domain-tagged = {
    expr = (p "pool.ntp.org:123")._type;
    expected = "dnsEndpoint";
  };
  parse-ipv4-roundtrip = {
    expr = endpoint.toString (p "192.0.2.1:80");
    expected = "192.0.2.1:80";
  };
  parse-ipv6-roundtrip = {
    expr = endpoint.toString (p "[::1]:443");
    expected = "[::1]:443";
  };
  parse-domain-roundtrip = {
    expr = endpoint.toString (p "pool.ntp.org:123");
    expected = "pool.ntp.org:123";
  };

  # ===== Reject =====
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-no-port = {
    expr = throws (p "nas");
    expected = true;
  };
  reject-underscore = {
    expr = throws (p "host_name:22");
    expected = true;
  };
  reject-unbracketed-ipv6 = {
    expr = throws (p "::1:443");
    expected = true;
  };
  reject-not-string = {
    expr = throws (endpoint.parse 42);
    expected = true;
  };

  tryParse-ok-ip = {
    expr = (endpoint.tryParse "192.0.2.1:80").success;
    expected = true;
  };
  tryParse-ok-name = {
    expr = (endpoint.tryParse "nas:22").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (endpoint.tryParse "host_name:1").success;
    expected = false;
  };

  # ===== toString / toUri =====
  toUri-ipv6 = {
    expr = endpoint.toUri (p "[2001:db8::1]:80");
    expected = "[2001:db8::1]:80";
  };
  toString-name-preserves-case = {
    expr = endpoint.toString (p "MyHost.example.com:443");
    expected = "MyHost.example.com:443";
  };

  # ===== Predicates =====
  is-ip = {
    expr = endpoint.is (p "192.0.2.1:80");
    expected = true;
  };
  is-dns = {
    expr = endpoint.is (p "nas:22");
    expected = true;
  };
  is-string = {
    expr = endpoint.is "nas:22";
    expected = false;
  };
  isIpEndpoint-yes = {
    expr = endpoint.isIpEndpoint (p "192.0.2.1:80");
    expected = true;
  };
  isIpEndpoint-no = {
    expr = endpoint.isIpEndpoint (p "nas:22");
    expected = false;
  };
  isDnsEndpoint-yes = {
    expr = endpoint.isDnsEndpoint (p "nas:22");
    expected = true;
  };
  isDnsEndpoint-no = {
    expr = endpoint.isDnsEndpoint (p "192.0.2.1:80");
    expected = false;
  };
  isValid-ip = {
    expr = endpoint.isValid "192.0.2.1:80";
    expected = true;
  };
  isValid-name = {
    expr = endpoint.isValid "pool.ntp.org:123";
    expected = true;
  };
  isValid-bad = {
    expr = endpoint.isValid "host_name:1";
    expected = false;
  };

  # ===== Member access via predicates =====
  # The union is heterogeneous (no uniform address/port), so branch on
  # the kind and use the member module's accessors.
  port-via-member = {
    expr = (import ../lib/port.nix).toInt (ipEndpoint.port (p "192.0.2.1:80"));
    expected = 80;
  };
  address-via-member = {
    expr = (dnsEndpoint.address (p "nas:22")).value;
    expected = "nas";
  };

  # IP-endpoint result carries the full ipEndpoint API (predicates).
  ip-result-has-predicates = {
    expr = ipEndpoint.isLoopback (p "127.0.0.1:80");
    expected = true;
  };

  # ===== Comparison =====
  eq-same-ip = {
    expr = endpoint.eq (p "192.0.2.1:80") (p "192.0.2.1:80");
    expected = true;
  };
  eq-same-name = {
    expr = endpoint.eq (p "nas:22") (p "nas:22");
    expected = true;
  };
  eq-name-case = {
    expr = endpoint.eq (p "NAS:22") (p "nas:22");
    expected = true;
  };
  eq-cross-kind = {
    expr = endpoint.eq (p "192.0.2.1:80") (p "nas:22");
    expected = false;
  };
  compare-ip-before-name = {
    expr = endpoint.compare (p "192.0.2.1:80") (p "nas:22");
    expected = -1;
  };
  compare-name-after-ip = {
    expr = endpoint.compare (p "nas:22") (p "192.0.2.1:80");
    expected = 1;
  };
  compare-within-name = {
    expr = endpoint.compare (p "alpha:80") (p "beta:80");
    expected = -1;
  };
  compare-name-before-unix = {
    expr = endpoint.compare (p "nas:22") (p "/run/foo.sock");
    expected = -1;
  };
  compare-unix-after-ip = {
    expr = endpoint.compare (p "/run/foo.sock") (p "10.0.0.1:80");
    expected = 1;
  };
  min-picks-ip = {
    expr = (endpoint.min (p "nas:22") (p "10.0.0.1:80"))._type;
    expected = "ipEndpoint";
  };

  # ===== unixSocket member =====
  parse-unix-tagged = {
    expr = (p "/run/foo.sock")._type;
    expected = "unixSocket";
  };
  parse-unix-abstract = {
    expr = (p "@foo")._type;
    expected = "unixSocket";
  };
  parse-unix-roundtrip = {
    expr = endpoint.toString (p "/run/postgresql/.s.PGSQL.5432");
    expected = "/run/postgresql/.s.PGSQL.5432";
  };
  isUnixSocket-yes = {
    expr = endpoint.isUnixSocket (p "/run/foo.sock");
    expected = true;
  };
  isUnixSocket-no = {
    expr = endpoint.isUnixSocket (p "192.0.2.1:80");
    expected = false;
  };
  isValid-unix = {
    expr = endpoint.isValid "/run/foo.sock";
    expected = true;
  };
  eq-same-unix = {
    expr = endpoint.eq (p "/run/foo.sock") (p "/run/foo.sock");
    expected = true;
  };
  eq-unix-cross-kind = {
    expr = endpoint.eq (p "/run/foo.sock") (p "nas:22");
    expected = false;
  };

  # Sanity: union recognises values from each member module
  is-from-ip-module = {
    expr = endpoint.is (ipEndpoint.parse "10.0.0.1:80");
    expected = true;
  };
  is-from-dns-module = {
    expr = endpoint.is (dnsEndpoint.parse "nas:22");
    expected = true;
  };
  is-from-unix-module = {
    expr = endpoint.is ((import ../lib/unix-socket.nix).parse "/run/foo.sock");
    expected = true;
  };
}
