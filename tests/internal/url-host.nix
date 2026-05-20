{ harness }:
let
  urlHost = import ../../lib/internal/url-host.nix;
  tp = urlHost.tryParse;
  v = s: (urlHost.tryParse s).value;
in
{
  # ===== tryParse: standard record =====
  tryParse-ok-success = {
    expr = (tp "example.com").success;
    expected = true;
  };
  tryParse-bad-success = {
    expr = (tp "bad host").success;
    expected = false;
  };
  tryParse-error-string = {
    expr = builtins.isString (tp "bad host").error;
    expected = true;
  };

  # ===== Parse: kinds =====
  ipv4 = {
    expr = (v "1.2.3.4").kind;
    expected = "ip";
  };
  ipv6-bracketed = {
    expr = urlHost.toString (v "[::1]");
    expected = "[::1]";
  };
  ipv6-unbracketed-rejected = {
    expr = (tp "::1").success;
    expected = false;
  };
  regname = {
    expr = (v "example.com").kind;
    expected = "regName";
  };
  regname-underscore = {
    expr = (v "my_host").name;
    expected = "my_host";
  };
  regname-subdelims = {
    expr = (v "a+b!c").kind;
    expected = "regName";
  };
  regname-pct = {
    expr = (v "a%20b").kind;
    expected = "regName";
  };

  # ===== Reject =====
  reject-empty = {
    expr = (tp "").success;
    expected = false;
  };
  reject-space = {
    expr = (tp "bad host").success;
    expected = false;
  };
  reject-bad-bracket = {
    expr = (tp "[::xyz]").success;
    expected = false;
  };
  reject-unclosed-bracket = {
    expr = (tp "[::1").success;
    expected = false;
  };

  # ===== toString / predicates =====
  toString-regname-case = {
    expr = urlHost.toString (v "Example.COM");
    expected = "Example.COM";
  };
  toString-ipv4 = {
    expr = urlHost.toString (v "1.2.3.4");
    expected = "1.2.3.4";
  };
  isValid-ok = {
    expr = urlHost.isValid "example.com";
    expected = true;
  };
  isValid-bad = {
    expr = urlHost.isValid "bad host";
    expected = false;
  };
  is-yes = {
    expr = urlHost.is (v "1.2.3.4");
    expected = true;
  };
  is-no = {
    expr = urlHost.is "x";
    expected = false;
  };
  isIp-yes = {
    expr = urlHost.isIp (v "1.2.3.4");
    expected = true;
  };
  isIp-no = {
    expr = urlHost.isIp (v "example.com");
    expected = false;
  };
  isRegName-yes = {
    expr = urlHost.isRegName (v "example.com");
    expected = true;
  };

  # ===== toHost (bridge to libnet.host) =====
  toHost-ip = {
    expr = (urlHost.toHost (v "1.2.3.4"))._type;
    expected = "ipv4";
  };
  toHost-hostname = {
    expr = (urlHost.toHost (v "nas"))._type;
    expected = "hostname";
  };
  toHost-domain = {
    expr = (urlHost.toHost (v "example.com"))._type;
    expected = "domain";
  };
  toHost-underscore-null = {
    expr = urlHost.toHost (v "my_host") == null;
    expected = true;
  };

  # ===== Comparison =====
  eq-ip = {
    expr = urlHost.eq (v "1.2.3.4") (v "1.2.3.4");
    expected = true;
  };
  eq-regname-ci = {
    expr = urlHost.eq (v "Example.COM") (v "example.com");
    expected = true;
  };
  eq-cross-kind = {
    expr = urlHost.eq (v "1.2.3.4") (v "example.com");
    expected = false;
  };
  compare-ip-before-regname = {
    expr = urlHost.compare (v "1.2.3.4") (v "example.com");
    expected = -1;
  };
  compare-regname-ci = {
    expr = urlHost.compare (v "alpha.com") (v "beta.com");
    expected = -1;
  };
  compare-eq = {
    expr = urlHost.compare (v "Example.COM") (v "example.com");
    expected = 0;
  };
}
