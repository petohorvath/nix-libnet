{ harness }:
let
  dnsLabel = import ../../lib/internal/dns-label.nix;
  inherit (dnsLabel) isValidLabel;
in
{
  # ===== positive =====
  simple = {
    expr = isValidLabel "nas";
    expected = true;
  };
  single-char = {
    expr = isValidLabel "a";
    expected = true;
  };
  digits = {
    expr = isValidLabel "host01";
    expected = true;
  };
  leading-digit = {
    expr = isValidLabel "3com";
    expected = true;
  };
  with-hyphen = {
    expr = isValidLabel "my-server";
    expected = true;
  };
  mixed-case = {
    expr = isValidLabel "MyHost";
    expected = true;
  };
  all-digits = {
    expr = isValidLabel "12345";
    expected = true;
  };
  # 1 + 60 ("123456789-" × 6) + 2 = 63 chars (maximum)
  max-len = {
    expr = isValidLabel "a123456789-123456789-123456789-123456789-123456789-123456789-xy";
    expected = true;
  };

  # ===== negative =====
  empty = {
    expr = isValidLabel "";
    expected = false;
  };
  underscore = {
    expr = isValidLabel "host_name";
    expected = false;
  };
  dot = {
    expr = isValidLabel "host.example";
    expected = false;
  };
  leading-hyphen = {
    expr = isValidLabel "-foo";
    expected = false;
  };
  trailing-hyphen = {
    expr = isValidLabel "foo-";
    expected = false;
  };
  single-hyphen = {
    expr = isValidLabel "-";
    expected = false;
  };
  # 64 chars (one over)
  too-long = {
    expr = isValidLabel "a123456789-123456789-123456789-123456789-123456789-123456789-xyz";
    expected = false;
  };
  whitespace = {
    expr = isValidLabel "my host";
    expected = false;
  };
  non-ascii = {
    expr = isValidLabel "café";
    expected = false;
  };
  slash = {
    expr = isValidLabel "foo/bar";
    expected = false;
  };
  not-string-int = {
    expr = isValidLabel 42;
    expected = false;
  };
  not-string-null = {
    expr = isValidLabel null;
    expected = false;
  };

  # ===== pattern is exposed =====
  pattern-exists = {
    expr = builtins.isString dnsLabel.labelPattern;
    expected = true;
  };
}
