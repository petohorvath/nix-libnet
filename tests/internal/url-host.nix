{ harness }:
let
  urlHost = import ../../lib/internal/url-host.nix;
  p = urlHost.tryParse;
in
{
  # ===== Parse: kinds =====
  ipv4 = {
    expr = (p "1.2.3.4").kind;
    expected = "ip";
  };
  ipv6-bracketed = {
    expr = urlHost.toString (p "[::1]");
    expected = "[::1]";
  };
  ipv6-unbracketed-rejected = {
    expr = p "::1" == null;
    expected = true;
  };
  regname = {
    expr = (p "example.com").kind;
    expected = "regName";
  };
  regname-underscore = {
    expr = (p "my_host").name;
    expected = "my_host";
  };
  regname-subdelims = {
    expr = (p "a+b!c").kind;
    expected = "regName";
  };
  regname-pct = {
    expr = (p "a%20b").kind;
    expected = "regName";
  };

  # ===== Reject =====
  reject-empty = {
    expr = p "" == null;
    expected = true;
  };
  reject-space = {
    expr = p "bad host" == null;
    expected = true;
  };
  reject-bad-bracket = {
    expr = p "[::xyz]" == null;
    expected = true;
  };
  reject-unclosed-bracket = {
    expr = p "[::1" == null;
    expected = true;
  };

  # ===== toString / predicates =====
  toString-regname-case = {
    expr = urlHost.toString (p "Example.COM");
    expected = "Example.COM";
  };
  toString-ipv4 = {
    expr = urlHost.toString (p "1.2.3.4");
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
    expr = urlHost.is (p "1.2.3.4");
    expected = true;
  };
  is-no = {
    expr = urlHost.is "x";
    expected = false;
  };
  isIp-yes = {
    expr = urlHost.isIp (p "1.2.3.4");
    expected = true;
  };
  isIp-no = {
    expr = urlHost.isIp (p "example.com");
    expected = false;
  };
  isRegName-yes = {
    expr = urlHost.isRegName (p "example.com");
    expected = true;
  };

  # ===== toHost (bridge to libnet.host) =====
  toHost-ip = {
    expr = (urlHost.toHost (p "1.2.3.4"))._type;
    expected = "ipv4";
  };
  toHost-hostname = {
    expr = (urlHost.toHost (p "nas"))._type;
    expected = "hostname";
  };
  toHost-domain = {
    expr = (urlHost.toHost (p "example.com"))._type;
    expected = "domain";
  };
  toHost-underscore-null = {
    expr = urlHost.toHost (p "my_host") == null;
    expected = true;
  };

  # ===== Comparison =====
  eq-ip = {
    expr = urlHost.eq (p "1.2.3.4") (p "1.2.3.4");
    expected = true;
  };
  eq-regname-ci = {
    expr = urlHost.eq (p "Example.COM") (p "example.com");
    expected = true;
  };
  eq-cross-kind = {
    expr = urlHost.eq (p "1.2.3.4") (p "example.com");
    expected = false;
  };
  compare-ip-before-regname = {
    expr = urlHost.compare (p "1.2.3.4") (p "example.com");
    expected = -1;
  };
  compare-regname-ci = {
    expr = urlHost.compare (p "alpha.com") (p "beta.com");
    expected = -1;
  };
  compare-eq = {
    expr = urlHost.compare (p "Example.COM") (p "example.com");
    expected = 0;
  };
}
