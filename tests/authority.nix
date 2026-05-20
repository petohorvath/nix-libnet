{ harness }:
let
  authority = import ../lib/authority.nix;
  port = import ../lib/port.nix;
  inherit (harness) throws;
  p = authority.parse;
in
{
  # ===== Parse & toString =====
  parse-host-only = {
    expr = authority.toString (p "example.com");
    expected = "example.com";
  };
  parse-host-port = {
    expr = authority.toString (p "example.com:8443");
    expected = "example.com:8443";
  };
  parse-userinfo = {
    expr = authority.toString (p "user@example.com:8443");
    expected = "user@example.com:8443";
  };
  parse-userinfo-no-port = {
    expr = authority.toString (p "user@example.com");
    expected = "user@example.com";
  };
  parse-ipv4 = {
    expr = authority.toString (p "1.2.3.4:80");
    expected = "1.2.3.4:80";
  };
  parse-ipv6 = {
    expr = authority.toString (p "[::1]:80");
    expected = "[::1]:80";
  };
  parse-ipv6-no-port = {
    expr = authority.toString (p "[::1]");
    expected = "[::1]";
  };
  parse-tagged = {
    expr = (p "example.com")._type;
    expected = "authority";
  };
  parse-creds-userinfo = {
    expr = authority.userinfo (p "u:pw@h");
    expected = "u:pw";
  };
  parse-underscore-host = {
    expr = (authority.host (p "my_host")).name;
    expected = "my_host";
  };
  parse-host-case-preserved = {
    expr = (authority.host (p "Example.COM")).name;
    expected = "Example.COM";
  };

  # ===== Accessors =====
  acc-userinfo = {
    expr = authority.userinfo (p "tok@h");
    expected = "tok";
  };
  acc-userinfo-null = {
    expr = authority.userinfo (p "h");
    expected = null;
  };
  acc-host-name = {
    expr = (authority.host (p "h")).name;
    expected = "h";
  };
  acc-host-kind-ip = {
    expr = (authority.host (p "1.2.3.4")).kind;
    expected = "ip";
  };
  acc-port = {
    expr = port.toInt (authority.port (p "h:8080"));
    expected = 8080;
  };
  acc-port-null = {
    expr = authority.port (p "h");
    expected = null;
  };

  # ===== Reject =====
  reject-empty-host = {
    expr = throws (p "");
    expected = true;
  };
  reject-port-only = {
    expr = throws (p ":80");
    expected = true;
  };
  reject-bad-port = {
    expr = throws (p "h:99999");
    expected = true;
  };
  reject-multi-at = {
    expr = throws (p "a@b@h");
    expected = true;
  };
  reject-space = {
    expr = throws (p "bad host");
    expected = true;
  };
  reject-not-string = {
    expr = throws (authority.parse 42);
    expected = true;
  };

  tryParse-ok = {
    expr = (authority.tryParse "h:80").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (authority.tryParse "a@b@c").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (authority.tryParse "").error;
    expected = true;
  };

  # ===== make =====
  make-host = {
    expr = authority.toString (authority.make { host = "example.com"; });
    expected = "example.com";
  };
  make-host-port = {
    expr = authority.toString (
      authority.make {
        host = "h";
        port = 8080;
      }
    );
    expected = "h:8080";
  };
  make-userinfo = {
    expr = authority.toString (
      authority.make {
        host = "h";
        userinfo = "tok";
      }
    );
    expected = "tok@h";
  };
  make-full = {
    expr = authority.toString (
      authority.make {
        host = "h";
        userinfo = "u:pw";
        port = 443;
      }
    );
    expected = "u:pw@h:443";
  };
  make-ipv6 = {
    expr = authority.toString (
      authority.make {
        host = "[::1]";
        port = 80;
      }
    );
    expected = "[::1]:80";
  };
  make-bad-host = {
    expr = throws (authority.make { host = "bad host"; });
    expected = true;
  };
  make-bad-port = {
    expr = throws (
      authority.make {
        host = "h";
        port = "80";
      }
    );
    expected = true;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = authority.is (p "h");
    expected = true;
  };
  is-string = {
    expr = authority.is "h";
    expected = false;
  };
  isValid-ok = {
    expr = authority.isValid "user@h:80";
    expected = true;
  };
  isValid-bad = {
    expr = authority.isValid "a@b@c";
    expected = false;
  };
  isValid-empty = {
    expr = authority.isValid "";
    expected = false;
  };

  # ===== Comparison =====
  # Unlike `url`, userinfo is part of identity and there is no default
  # port (a null port differs from any explicit one).
  eq-same = {
    expr = authority.eq (p "h:80") (p "h:80");
    expected = true;
  };
  eq-userinfo-matters = {
    expr = authority.eq (p "u@h") (p "h");
    expected = false;
  };
  eq-userinfo-same = {
    expr = authority.eq (p "u@h") (p "u@h");
    expected = true;
  };
  eq-host-case-insensitive = {
    expr = authority.eq (p "Example.COM:80") (p "example.com:80");
    expected = true;
  };
  eq-port-null-vs-explicit = {
    expr = authority.eq (p "h") (p "h:80");
    expected = false;
  };
  eq-diff-port = {
    expr = authority.eq (p "h:80") (p "h:81");
    expected = false;
  };
  compare-host = {
    expr = authority.compare (p "a.com") (p "b.com");
    expected = -1;
  };
  compare-port = {
    expr = authority.compare (p "h:80") (p "h:81");
    expected = -1;
  };
  compare-port-null-first = {
    expr = authority.compare (p "h") (p "h:80");
    expected = -1;
  };
  compare-userinfo-tiebreak = {
    expr = authority.compare (p "a@h") (p "b@h");
    expected = -1;
  };
  compare-eq = {
    expr = authority.compare (p "h:80") (p "h:80");
    expected = 0;
  };
  cmp-lt = {
    expr = authority.lt (p "h:80") (p "h:81");
    expected = true;
  };
  cmp-le = {
    expr = authority.le (p "h:80") (p "h:80");
    expected = true;
  };
  cmp-gt = {
    expr = authority.gt (p "h:81") (p "h:80");
    expected = true;
  };
  cmp-ge = {
    expr = authority.ge (p "h:80") (p "h:80");
    expected = true;
  };
  cmp-min = {
    expr = authority.toString (authority.min (p "h:80") (p "h:81"));
    expected = "h:80";
  };
  cmp-max = {
    expr = authority.toString (authority.max (p "h:80") (p "h:81"));
    expected = "h:81";
  };
}
