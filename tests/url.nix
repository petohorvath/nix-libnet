{ harness }:
let
  url = import ../lib/url.nix;
  port = import ../lib/port.nix;
  ipEndpoint = import ../lib/ip-endpoint.nix;
  dnsEndpoint = import ../lib/dns-endpoint.nix;
  inherit (harness) throws;
  p = url.parse;
in
{
  # ===== Parse: schemes & basics =====
  parse-https = {
    expr = url.toString (p "https://example.com");
    expected = "https://example.com";
  };
  parse-http-port = {
    expr = url.toString (p "http://example.com:8080");
    expected = "http://example.com:8080";
  };
  parse-full = {
    expr = url.toString (p "https://user@example.com:8443/a/b?x=1&y=2#frag");
    expected = "https://user@example.com:8443/a/b?x=1&y=2#frag";
  };
  parse-tagged = {
    expr = (p "https://example.com")._type;
    expected = "url";
  };
  parse-scheme-lowercased = {
    expr = (p "HTTPS://example.com").scheme;
    expected = "https";
  };

  # ===== Host kinds =====
  host-ipv4 = {
    expr = (p "http://1.2.3.4/x").host.kind;
    expected = "ip";
  };
  host-ipv6-roundtrip = {
    expr = url.toString (p "http://[::1]:80/x");
    expected = "http://[::1]:80/x";
  };
  host-regname = {
    expr = (p "http://example.com").host.kind;
    expected = "regName";
  };
  host-underscore = {
    expr = (p "http://my_host/x").host.name;
    expected = "my_host";
  };
  host-preserves-case = {
    expr = (p "http://Example.COM").host.name;
    expected = "Example.COM";
  };

  # ===== Components (stored raw) =====
  comp-path = {
    expr = (p "https://h/a%20b").path;
    expected = "/a%20b";
  };
  comp-query-raw = {
    expr = (p "https://h/?x=%26").query;
    expected = "x=%26";
  };
  comp-frag = {
    expr = (p "https://h/#sec").fragment;
    expected = "sec";
  };
  comp-no-path = {
    expr = (p "https://h").path;
    expected = "";
  };
  comp-query-null = {
    expr = (p "https://h/p").query;
    expected = null;
  };
  comp-frag-null = {
    expr = (p "https://h/p").fragment;
    expected = null;
  };
  comp-userinfo = {
    expr = (p "https://tok@h").userinfo;
    expected = "tok";
  };
  comp-userinfo-null = {
    expr = (p "https://h").userinfo;
    expected = null;
  };
  comp-userinfo-creds = {
    expr = (p "https://u:pw@h").userinfo;
    expected = "u:pw";
  };

  # ===== Reject =====
  reject-no-scheme = {
    expr = throws (p "example.com/x");
    expected = true;
  };
  reject-unknown-scheme = {
    expr = throws (p "gopher://h");
    expected = true;
  };
  reject-empty-host = {
    expr = throws (p "https:///path");
    expected = true;
  };
  reject-bad-port = {
    expr = throws (p "https://h:99999");
    expected = true;
  };
  reject-multi-at = {
    expr = throws (p "https://a@b@h");
    expected = true;
  };
  reject-not-string = {
    expr = throws (url.parse 42);
    expected = true;
  };

  tryParse-ok = {
    expr = (url.tryParse "https://h").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (url.tryParse "nope").success;
    expected = false;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = url.is (p "https://h");
    expected = true;
  };
  is-string = {
    expr = url.is "https://h";
    expected = false;
  };
  isValid-ok = {
    expr = url.isValid "wss://h:9000/ws";
    expected = true;
  };
  isValid-bad = {
    expr = url.isValid "h://x";
    expected = false;
  };
  isSecure-https = {
    expr = url.isSecure (p "https://h");
    expected = true;
  };
  isSecure-http = {
    expr = url.isSecure (p "http://h");
    expected = false;
  };

  # ===== Accessors =====
  acc-scheme = {
    expr = url.scheme (p "ftp://h");
    expected = "ftp";
  };
  acc-host-name = {
    expr = (url.host (p "http://h")).name;
    expected = "h";
  };
  acc-port-explicit = {
    expr = port.toInt (url.port (p "http://h:8080"));
    expected = 8080;
  };
  acc-port-null = {
    expr = url.port (p "http://h");
    expected = null;
  };
  acc-defaultPort = {
    expr = url.defaultPort (p "https://h");
    expected = 443;
  };
  acc-effport-default = {
    expr = port.toInt (url.effectivePort (p "https://h"));
    expected = 443;
  };
  acc-effport-explicit = {
    expr = port.toInt (url.effectivePort (p "https://h:8443"));
    expected = 8443;
  };
  acc-transport-tcp = {
    expr = (url.transport (p "https://h")).value;
    expected = "tcp";
  };
  acc-transport-udp = {
    expr = (url.transport (p "coap://h")).value;
    expected = "udp";
  };

  # ===== Scheme registry =====
  scheme-ssh-port = {
    expr = url.defaultPort (p "ssh://h");
    expected = 22;
  };
  scheme-redis-port = {
    expr = url.defaultPort (p "redis://h");
    expected = 6379;
  };
  scheme-postgres-port = {
    expr = url.defaultPort (p "postgres://h");
    expected = 5432;
  };
  scheme-coap-udp = {
    expr = (url.transport (p "coap://h")).value;
    expected = "udp";
  };
  schemes-count = {
    expr = builtins.length (builtins.attrNames url.schemes);
    expected = 30;
  };

  # ===== toEndpoint =====
  toEndpoint-ipv4 = {
    expr = ipEndpoint.toString (url.toEndpoint (p "http://1.2.3.4/x"));
    expected = "1.2.3.4:80";
  };
  toEndpoint-ipv6 = {
    expr = ipEndpoint.toString (url.toEndpoint (p "https://[::1]/x"));
    expected = "[::1]:443";
  };
  toEndpoint-dns = {
    expr = dnsEndpoint.toString (url.toEndpoint (p "https://example.com"));
    expected = "example.com:443";
  };
  toEndpoint-explicit-port = {
    expr = ipEndpoint.toString (url.toEndpoint (p "http://1.2.3.4:8080"));
    expected = "1.2.3.4:8080";
  };
  toEndpoint-regname-throws = {
    expr = throws (url.toEndpoint (p "http://my_host/x"));
    expected = true;
  };

  # ===== make =====
  make-ok = {
    expr = url.toString (
      url.make {
        scheme = "https";
        host = "example.com";
        path = "/p";
      }
    );
    expected = "https://example.com/p";
  };
  make-port = {
    expr = url.toString (
      url.make {
        scheme = "http";
        host = "h";
        port = 8080;
      }
    );
    expected = "http://h:8080";
  };
  make-userinfo = {
    expr = url.toString (
      url.make {
        scheme = "https";
        host = "h";
        userinfo = "tok";
      }
    );
    expected = "https://tok@h";
  };
  make-bad-scheme = {
    expr = throws (
      url.make {
        scheme = "gopher";
        host = "h";
      }
    );
    expected = true;
  };
  make-bad-host = {
    expr = throws (
      url.make {
        scheme = "http";
        host = "bad host";
      }
    );
    expected = true;
  };

  # ===== Comparison =====
  eq-same = {
    expr = url.eq (p "https://h/p") (p "https://h/p");
    expected = true;
  };
  eq-host-case-insens = {
    expr = url.eq (p "https://Example.COM") (p "https://example.com");
    expected = true;
  };
  eq-default-vs-explicit-port = {
    expr = url.eq (p "https://h") (p "https://h:443");
    expected = true;
  };
  eq-diff-path = {
    expr = url.eq (p "https://h/a") (p "https://h/b");
    expected = false;
  };
  eq-diff-scheme = {
    expr = url.eq (p "http://h") (p "https://h");
    expected = false;
  };
  compare-scheme = {
    expr = url.compare (p "http://h") (p "https://h");
    expected = -1;
  };
  compare-host = {
    expr = url.compare (p "https://a.com") (p "https://b.com");
    expected = -1;
  };
  compare-port = {
    expr = url.compare (p "http://h:80") (p "http://h:81");
    expected = -1;
  };
  compare-path = {
    expr = url.compare (p "https://h/a") (p "https://h/b");
    expected = -1;
  };
  compare-eq = {
    expr = url.compare (p "https://h") (p "https://h");
    expected = 0;
  };
  cmp-lt = {
    expr = url.lt (p "http://h") (p "https://h");
    expected = true;
  };
  cmp-le = {
    expr = url.le (p "http://h") (p "https://h");
    expected = true;
  };
  cmp-gt = {
    expr = url.gt (p "https://h") (p "http://h");
    expected = true;
  };
  cmp-ge = {
    expr = url.ge (p "https://h") (p "http://h");
    expected = true;
  };
  cmp-min = {
    expr = url.toString (url.min (p "http://h") (p "https://h"));
    expected = "http://h";
  };
  cmp-max = {
    expr = url.toString (url.max (p "http://h") (p "https://h"));
    expected = "https://h";
  };
}
