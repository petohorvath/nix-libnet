{ harness }:
let
  unixSocket = import ../lib/unix-socket.nix;
  inherit (harness) throws;
  p = unixSocket.parse;

  # 107-char pathname (max): "/" + 106 chars
  pathMax = "/" + builtins.concatStringsSep "" (builtins.genList (_: "a") 106);
  # 108-char pathname (one over)
  pathOver = "/" + builtins.concatStringsSep "" (builtins.genList (_: "a") 107);
in
{
  # ===== Parse: pathname =====
  parse-simple = {
    expr = (p "/run/foo.sock").path;
    expected = "/run/foo.sock";
  };
  parse-postgres = {
    expr = (p "/run/postgresql/.s.PGSQL.5432").path;
    expected = "/run/postgresql/.s.PGSQL.5432";
  };
  parse-tagged = {
    expr = (p "/run/foo.sock")._type;
    expected = "unixSocket";
  };
  parse-max-len = {
    expr = (p pathMax).path;
    expected = pathMax;
  };

  # ===== Parse: abstract =====
  parse-abstract = {
    expr = (p "@foo").path;
    expected = "@foo";
  };
  parse-abstract-tagged = {
    expr = (p "@my-service")._type;
    expected = "unixSocket";
  };

  # ===== Reject =====
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-relative = {
    expr = throws (p "run/foo.sock");
    expected = true;
  };
  reject-bare-name = {
    expr = throws (p "foo.sock");
    expected = true;
  };
  reject-host-port = {
    expr = throws (p "1.2.3.4:80");
    expected = true;
  };
  reject-slash-only = {
    expr = throws (p "/");
    expected = true;
  };
  reject-at-only = {
    expr = throws (p "@");
    expected = true;
  };
  reject-too-long = {
    expr = throws (p pathOver);
    expected = true;
  };
  reject-not-string = {
    expr = throws (unixSocket.parse 42);
    expected = true;
  };

  tryParse-ok = {
    expr = (unixSocket.tryParse "/run/foo.sock").success;
    expected = true;
  };
  tryParse-abstract = {
    expr = (unixSocket.tryParse "@foo").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (unixSocket.tryParse "foo.sock").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (unixSocket.tryParse "foo").error;
    expected = true;
  };

  # ===== toString / accessor =====
  toString-pathname = {
    expr = unixSocket.toString (p "/run/foo.sock");
    expected = "/run/foo.sock";
  };
  toString-abstract = {
    expr = unixSocket.toString (p "@foo");
    expected = "@foo";
  };
  path-accessor = {
    expr = unixSocket.path (p "/run/foo.sock");
    expected = "/run/foo.sock";
  };

  # ===== Predicates =====
  is-parsed = {
    expr = unixSocket.is (p "/run/foo.sock");
    expected = true;
  };
  is-string = {
    expr = unixSocket.is "/run/foo.sock";
    expected = false;
  };
  is-untagged = {
    expr = unixSocket.is { path = "/run/foo.sock"; };
    expected = false;
  };
  isValid-pathname = {
    expr = unixSocket.isValid "/run/foo.sock";
    expected = true;
  };
  isValid-abstract = {
    expr = unixSocket.isValid "@foo";
    expected = true;
  };
  isValid-bad = {
    expr = unixSocket.isValid "foo.sock";
    expected = false;
  };
  isPathname-yes = {
    expr = unixSocket.isPathname (p "/run/foo.sock");
    expected = true;
  };
  isPathname-no = {
    expr = unixSocket.isPathname (p "@foo");
    expected = false;
  };
  isAbstract-yes = {
    expr = unixSocket.isAbstract (p "@foo");
    expected = true;
  };
  isAbstract-no = {
    expr = unixSocket.isAbstract (p "/run/foo.sock");
    expected = false;
  };

  # ===== Comparison helpers =====
  cmp-lt = {
    expr = unixSocket.lt (p "/a") (p "/b");
    expected = true;
  };
  cmp-le = {
    expr = unixSocket.le (p "/a") (p "/b");
    expected = true;
  };
  cmp-gt = {
    expr = unixSocket.gt (p "/b") (p "/a");
    expected = true;
  };
  cmp-ge = {
    expr = unixSocket.ge (p "/b") (p "/a");
    expected = true;
  };

  # ===== Comparison =====
  eq-same = {
    expr = unixSocket.eq (p "/run/foo.sock") (p "/run/foo.sock");
    expected = true;
  };
  eq-case-sensitive = {
    expr = unixSocket.eq (p "/run/Foo.sock") (p "/run/foo.sock");
    expected = false;
  };
  eq-diff = {
    expr = unixSocket.eq (p "/run/a.sock") (p "/run/b.sock");
    expected = false;
  };
  compare-lt = {
    expr = unixSocket.compare (p "/run/a.sock") (p "/run/b.sock");
    expected = -1;
  };
  compare-gt = {
    expr = unixSocket.compare (p "/run/b.sock") (p "/run/a.sock");
    expected = 1;
  };
  compare-eq = {
    expr = unixSocket.compare (p "/run/a.sock") (p "/run/a.sock");
    expected = 0;
  };
  min-pick = {
    expr = (unixSocket.min (p "/run/b.sock") (p "/run/a.sock")).path;
    expected = "/run/a.sock";
  };
  max-pick = {
    expr = (unixSocket.max (p "/run/b.sock") (p "/run/a.sock")).path;
    expected = "/run/b.sock";
  };

  # ===== Constant =====
  sunPathMax = {
    expr = unixSocket.sunPathMax;
    expected = 108;
  };
}
