{ harness }:
let
  hostname = import ../lib/hostname.nix;
  inherit (harness) throws;
  p = hostname.parse;

  # 1 + 60 ("123456789-" × 6) + 2 = 63 chars (maximum valid)
  len63 = "a123456789-123456789-123456789-123456789-123456789-123456789-xy";
  # 1 + 60 + 3 = 64 chars (one over the limit)
  len64 = "a123456789-123456789-123456789-123456789-123456789-123456789-xyz";
in
{
  # ===== Parse =====
  parse-simple = {
    expr = (p "nas").value;
    expected = "nas";
  };
  parse-single-char = {
    expr = (p "b").value;
    expected = "b";
  };
  parse-with-digits = {
    expr = (p "host01").value;
    expected = "host01";
  };
  parse-leading-digit = {
    expr = (p "3com").value;
    expected = "3com";
  };
  parse-with-hyphen = {
    expr = (p "my-server").value;
    expected = "my-server";
  };
  parse-mixed-case = {
    expr = (p "MyHost").value;
    expected = "MyHost";
  };
  parse-max-len = {
    expr = (p len63).value;
    expected = len63;
  };
  parse-tagged = {
    expr = (p "nas")._type;
    expected = "hostname";
  };

  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-underscore = {
    expr = throws (p "host_name");
    expected = true;
  };
  reject-dot = {
    expr = throws (p "host.example.com");
    expected = true;
  };
  reject-leading-hyphen = {
    expr = throws (p "-foo");
    expected = true;
  };
  reject-trailing-hyphen = {
    expr = throws (p "foo-");
    expected = true;
  };
  reject-single-hyphen = {
    expr = throws (p "-");
    expected = true;
  };
  reject-too-long = {
    expr = throws (p len64);
    expected = true;
  };
  reject-whitespace-leading = {
    expr = throws (p " nas");
    expected = true;
  };
  reject-whitespace-trailing = {
    expr = throws (p "nas ");
    expected = true;
  };
  reject-whitespace-middle = {
    expr = throws (p "my host");
    expected = true;
  };
  reject-non-ascii = {
    expr = throws (p "café");
    expected = true;
  };
  reject-not-string = {
    expr = throws (hostname.parse 42);
    expected = true;
  };
  reject-slash = {
    expr = throws (p "foo/bar");
    expected = true;
  };

  tryParse-ok = {
    expr = (hostname.tryParse "nas").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (hostname.tryParse "host_name").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (hostname.tryParse "host_name").error;
    expected = true;
  };
  tryParse-not-string = {
    expr = (hostname.tryParse 42).success;
    expected = false;
  };

  # ===== Round-trip =====
  rt-toString = {
    expr = hostname.toString (p "nas");
    expected = "nas";
  };
  rt-preserves-case = {
    expr = hostname.toString (p "MyHost");
    expected = "MyHost";
  };

  # ===== Predicates =====
  is-parsed = {
    expr = hostname.is (p "nas");
    expected = true;
  };
  is-string = {
    expr = hostname.is "nas";
    expected = false;
  };
  is-untagged = {
    expr = hostname.is { value = "nas"; };
    expected = false;
  };
  isValid-ok = {
    expr = hostname.isValid "nas";
    expected = true;
  };
  isValid-bad = {
    expr = hostname.isValid "host_name";
    expected = false;
  };
  isValid-not-string = {
    expr = hostname.isValid 42;
    expected = false;
  };

  # ===== Normalize =====
  normalize-upper = {
    expr = (hostname.normalize (p "MyHost")).value;
    expected = "myhost";
  };
  normalize-already-lower = {
    expr = (hostname.normalize (p "myhost")).value;
    expected = "myhost";
  };
  normalize-mixed = {
    expr = (hostname.normalize (p "My-Host")).value;
    expected = "my-host";
  };
  normalize-preserves-tag = {
    expr = hostname.is (hostname.normalize (p "NAS"));
    expected = true;
  };
  normalize-digits-unchanged = {
    expr = (hostname.normalize (p "host01")).value;
    expected = "host01";
  };

  # ===== Equality (case-insensitive) =====
  eq-same = {
    expr = hostname.eq (p "nas") (p "nas");
    expected = true;
  };
  eq-case-upper = {
    expr = hostname.eq (p "NAS") (p "nas");
    expected = true;
  };
  eq-case-mixed = {
    expr = hostname.eq (p "MyHost") (p "myhost");
    expected = true;
  };
  eq-diff = {
    expr = hostname.eq (p "nas") (p "router");
    expected = false;
  };

  # ===== Comparison (case-insensitive) =====
  lt-yes = {
    expr = hostname.lt (p "alpha") (p "beta");
    expected = true;
  };
  lt-no = {
    expr = hostname.lt (p "beta") (p "alpha");
    expected = false;
  };
  lt-case-insens = {
    expr = hostname.lt (p "Alpha") (p "beta");
    expected = true;
  };
  compare-lt = {
    expr = hostname.compare (p "alpha") (p "beta");
    expected = -1;
  };
  compare-eq-case = {
    expr = hostname.compare (p "NAS") (p "nas");
    expected = 0;
  };
  compare-gt = {
    expr = hostname.compare (p "z") (p "a");
    expected = 1;
  };
  le-equal = {
    expr = hostname.le (p "nas") (p "nas");
    expected = true;
  };
  ge-equal = {
    expr = hostname.ge (p "nas") (p "nas");
    expected = true;
  };
  min-pick = {
    expr = (hostname.min (p "beta") (p "alpha")).value;
    expected = "alpha";
  };
  max-pick = {
    expr = (hostname.max (p "beta") (p "alpha")).value;
    expected = "beta";
  };
}
