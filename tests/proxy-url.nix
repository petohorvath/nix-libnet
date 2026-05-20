{ harness }:
let
  proxyUrl = import ../lib/proxy-url.nix;
  authority = import ../lib/authority.nix;
  port = import ../lib/port.nix;
  inherit (harness) throws;
  p = proxyUrl.parse;
in
{
  # ===== Parse & toString =====
  parse-socks5 = {
    expr = proxyUrl.toString (p "socks5://127.0.0.1:1080");
    expected = "socks5://127.0.0.1:1080";
  };
  parse-http = {
    expr = proxyUrl.toString (p "http://proxy.corp:8080");
    expected = "http://proxy.corp:8080";
  };
  parse-https = {
    expr = proxyUrl.toString (p "https://proxy:8443");
    expected = "https://proxy:8443";
  };
  parse-socks4a = {
    expr = proxyUrl.toString (p "socks4a://h:1080");
    expected = "socks4a://h:1080";
  };
  parse-socks5h = {
    expr = proxyUrl.toString (p "socks5h://h:1080");
    expected = "socks5h://h:1080";
  };
  parse-userinfo = {
    expr = proxyUrl.toString (p "socks5://user:pass@10.0.0.1:1080");
    expected = "socks5://user:pass@10.0.0.1:1080";
  };
  parse-ipv6 = {
    expr = proxyUrl.toString (p "socks5://[::1]:1080");
    expected = "socks5://[::1]:1080";
  };
  parse-scheme-case-insensitive = {
    expr = proxyUrl.toString (p "SOCKS5://h:1080");
    expected = "socks5://h:1080";
  };
  parse-tagged = {
    expr = (p "socks5://h:1080")._type;
    expected = "proxyUrl";
  };
  parse-scheme-accessor = {
    expr = proxyUrl.scheme (p "socks5://h:1080");
    expected = "socks5";
  };
  parse-authority-kind = {
    expr = (proxyUrl.authority (p "socks5://h:1080"))._type;
    expected = "authority";
  };
  parse-authority-host-ip = {
    expr = (authority.host (proxyUrl.authority (p "socks5://1.2.3.4:1080"))).kind;
    expected = "ip";
  };
  parse-authority-port = {
    expr = port.toInt (authority.port (proxyUrl.authority (p "socks5://h:1080")));
    expected = 1080;
  };

  # ===== Reject =====
  reject-no-scheme = {
    expr = throws (p "127.0.0.1:1080");
    expected = true;
  };
  reject-unknown-scheme = {
    expr = throws (p "ftp://h:1080");
    expected = true;
  };
  reject-bare-socks = {
    expr = throws (p "socks://h:1080");
    expected = true;
  };
  reject-no-port = {
    expr = throws (p "socks5://127.0.0.1");
    expected = true;
  };
  reject-empty-host = {
    expr = throws (p "socks5://:1080");
    expected = true;
  };
  reject-multi-at = {
    expr = throws (p "socks5://a@b@h:1080");
    expected = true;
  };
  reject-path = {
    expr = throws (p "http://h:8080/pac");
    expected = true;
  };
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-not-string = {
    expr = throws (proxyUrl.parse 42);
    expected = true;
  };

  tryParse-ok = {
    expr = (proxyUrl.tryParse "socks5://h:1080").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (proxyUrl.tryParse "socks5://h").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (proxyUrl.tryParse "socks5://h").error;
    expected = true;
  };

  # ===== make =====
  make-ok = {
    expr = proxyUrl.toString (
      proxyUrl.make "socks5" (
        authority.make {
          host = "10.0.0.1";
          port = 1080;
        }
      )
    );
    expected = "socks5://10.0.0.1:1080";
  };
  make-userinfo = {
    expr = proxyUrl.toString (
      proxyUrl.make "http" (
        authority.make {
          host = "h";
          userinfo = "u:p";
          port = 8080;
        }
      )
    );
    expected = "http://u:p@h:8080";
  };
  make-scheme-case = {
    expr = proxyUrl.toString (
      proxyUrl.make "SOCKS5" (
        authority.make {
          host = "h";
          port = 1080;
        }
      )
    );
    expected = "socks5://h:1080";
  };
  make-unknown-scheme-throws = {
    expr = throws (
      proxyUrl.make "ftp" (
        authority.make {
          host = "h";
          port = 1080;
        }
      )
    );
    expected = true;
  };
  make-no-port-throws = {
    expr = throws (proxyUrl.make "socks5" (authority.make { host = "h"; }));
    expected = true;
  };
  make-non-authority-throws = {
    expr = throws (proxyUrl.make "socks5" "h:1080");
    expected = true;
  };
  make-non-string-scheme-throws = {
    expr = throws (
      proxyUrl.make 42 (
        authority.make {
          host = "h";
          port = 1080;
        }
      )
    );
    expected = true;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = proxyUrl.is (p "socks5://h:1080");
    expected = true;
  };
  is-string = {
    expr = proxyUrl.is "socks5://h:1080";
    expected = false;
  };
  isValid-ok = {
    expr = proxyUrl.isValid "http://proxy:8080";
    expected = true;
  };
  isValid-bad = {
    expr = proxyUrl.isValid "ftp://h:1";
    expected = false;
  };
  isValid-no-port = {
    expr = proxyUrl.isValid "socks5://h";
    expected = false;
  };

  # ===== Comparison =====
  eq-same = {
    expr = proxyUrl.eq (p "socks5://h:1080") (p "socks5://h:1080");
    expected = true;
  };
  eq-diff-scheme = {
    expr = proxyUrl.eq (p "socks5://h:1080") (p "socks5h://h:1080");
    expected = false;
  };
  eq-diff-authority = {
    expr = proxyUrl.eq (p "socks5://h:1080") (p "socks5://h:1081");
    expected = false;
  };
  eq-userinfo-matters = {
    expr = proxyUrl.eq (p "socks5://u@h:1080") (p "socks5://h:1080");
    expected = false;
  };
  eq-host-case-insensitive = {
    expr = proxyUrl.eq (p "socks5://Example.COM:1080") (p "socks5://example.com:1080");
    expected = true;
  };
  compare-http-before-socks5 = {
    expr = proxyUrl.compare (p "http://h:1") (p "socks5://h:1");
    expected = -1;
  };
  compare-socks4-before-socks4a = {
    expr = proxyUrl.compare (p "socks4://h:1") (p "socks4a://h:1");
    expected = -1;
  };
  compare-within-scheme-by-authority = {
    expr = proxyUrl.compare (p "socks5://h:1080") (p "socks5://h:1081");
    expected = -1;
  };
  compare-eq = {
    expr = proxyUrl.compare (p "socks5://h:1080") (p "socks5://h:1080");
    expected = 0;
  };
  cmp-lt = {
    expr = proxyUrl.lt (p "http://h:1") (p "socks5://h:1");
    expected = true;
  };
  cmp-le = {
    expr = proxyUrl.le (p "socks5://h:1080") (p "socks5://h:1080");
    expected = true;
  };
  cmp-gt = {
    expr = proxyUrl.gt (p "socks5://h:1") (p "http://h:1");
    expected = true;
  };
  cmp-ge = {
    expr = proxyUrl.ge (p "socks5://h:1080") (p "socks5://h:1080");
    expected = true;
  };
  cmp-min = {
    expr = proxyUrl.toString (proxyUrl.min (p "socks5://h:1") (p "http://h:1"));
    expected = "http://h:1";
  };
  cmp-max = {
    expr = proxyUrl.toString (proxyUrl.max (p "socks5://h:1") (p "http://h:1"));
    expected = "socks5://h:1";
  };

  # ===== Constant =====
  schemes-list = {
    expr = proxyUrl.schemes;
    expected = [
      "http"
      "https"
      "socks4"
      "socks4a"
      "socks5"
      "socks5h"
    ];
  };
}
