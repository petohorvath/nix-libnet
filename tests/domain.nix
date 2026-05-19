{ harness }:
let
  domain = import ../lib/domain.nix;
  hostname = import ../lib/hostname.nix;
  inherit (harness) throws;
  p = domain.parse;

  # 62 copies of "abc." = 248 chars; plus a 5/6-char final label.
  longPrefix = builtins.concatStringsSep "" (builtins.genList (_: "abc.") 62);
  len253 = longPrefix + "abcde"; # 248 + 5
  len254 = longPrefix + "abcdef"; # 248 + 6
in
{
  # ===== Parse =====
  parse-simple = {
    expr = (p "example.com").value;
    expected = "example.com";
  };
  parse-three-labels = {
    expr = (p "foo.example.com").value;
    expected = "foo.example.com";
  };
  parse-deep = {
    expr = (p "a.b.c.d.e.f.example.com").value;
    expected = "a.b.c.d.e.f.example.com";
  };
  parse-two-single-char = {
    expr = (p "a.b").value;
    expected = "a.b";
  };
  parse-mixed-case = {
    expr = (p "MyHost.Example.COM").value;
    expected = "MyHost.Example.COM";
  };
  parse-leading-digit = {
    expr = (p "3com.example.com").value;
    expected = "3com.example.com";
  };
  parse-with-hyphen = {
    expr = (p "my-server.example.com").value;
    expected = "my-server.example.com";
  };
  parse-max-len = {
    expr = (p len253).value;
    expected = len253;
  };
  parse-tagged = {
    expr = (p "example.com")._type;
    expected = "domain";
  };

  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-single-label = {
    expr = throws (p "example");
    expected = true;
  };
  reject-leading-dot = {
    expr = throws (p ".example.com");
    expected = true;
  };
  reject-trailing-dot = {
    expr = throws (p "example.com.");
    expected = true;
  };
  reject-consecutive-dots = {
    expr = throws (p "a..b");
    expected = true;
  };
  reject-underscore = {
    expr = throws (p "host_name.com");
    expected = true;
  };
  reject-leading-hyphen-label = {
    expr = throws (p "-foo.com");
    expected = true;
  };
  reject-trailing-hyphen-label = {
    expr = throws (p "foo-.com");
    expected = true;
  };
  reject-long-label = {
    # 64-char first label
    expr = throws (p "a123456789-123456789-123456789-123456789-123456789-123456789-xyz.com");
    expected = true;
  };
  reject-too-long-total = {
    expr = throws (p len254);
    expected = true;
  };
  reject-whitespace-leading = {
    expr = throws (p " example.com");
    expected = true;
  };
  reject-whitespace-middle = {
    expr = throws (p "ex ample.com");
    expected = true;
  };
  reject-non-ascii = {
    expr = throws (p "café.com");
    expected = true;
  };
  reject-not-string = {
    expr = throws (domain.parse 42);
    expected = true;
  };
  reject-slash = {
    expr = throws (p "foo/bar.com");
    expected = true;
  };

  tryParse-ok = {
    expr = (domain.tryParse "example.com").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (domain.tryParse "single").success;
    expected = false;
  };
  tryParse-bad-error = {
    expr = builtins.isString (domain.tryParse "single").error;
    expected = true;
  };
  tryParse-not-string = {
    expr = (domain.tryParse 42).success;
    expected = false;
  };

  # ===== fromLabels =====
  fromLabels-three = {
    expr =
      (domain.fromLabels [
        "foo"
        "example"
        "com"
      ]).value;
    expected = "foo.example.com";
  };
  fromLabels-two = {
    expr =
      (domain.fromLabels [
        "example"
        "com"
      ]).value;
    expected = "example.com";
  };
  fromLabels-single-throws = {
    expr = throws (domain.fromLabels [ "example" ]);
    expected = true;
  };
  fromLabels-empty-throws = {
    expr = throws (domain.fromLabels [ ]);
    expected = true;
  };
  fromLabels-bad-label-throws = {
    expr = throws (
      domain.fromLabels [
        "host_name"
        "com"
      ]
    );
    expected = true;
  };
  fromLabels-not-list-throws = {
    expr = throws (domain.fromLabels "example.com");
    expected = true;
  };

  # ===== Round-trip =====
  rt-toString = {
    expr = domain.toString (p "foo.example.com");
    expected = "foo.example.com";
  };
  rt-preserves-case = {
    expr = domain.toString (p "Example.COM");
    expected = "Example.COM";
  };

  # ===== Predicates =====
  is-parsed = {
    expr = domain.is (p "example.com");
    expected = true;
  };
  is-string = {
    expr = domain.is "example.com";
    expected = false;
  };
  is-hostname-value = {
    expr = domain.is (hostname.parse "nas");
    expected = false;
  };
  isValid-ok = {
    expr = domain.isValid "example.com";
    expected = true;
  };
  isValid-bad = {
    expr = domain.isValid "example";
    expected = false;
  };
  isValid-not-string = {
    expr = domain.isValid 42;
    expected = false;
  };

  # ===== Accessors =====
  labels-three = {
    expr = domain.labels (p "foo.example.com");
    expected = [
      "foo"
      "example"
      "com"
    ];
  };
  labels-two = {
    expr = domain.labels (p "example.com");
    expected = [
      "example"
      "com"
    ];
  };
  labelCount-three = {
    expr = domain.labelCount (p "foo.example.com");
    expected = 3;
  };
  labelCount-two = {
    expr = domain.labelCount (p "example.com");
    expected = 2;
  };

  # ===== parent =====
  parent-three = {
    expr = (domain.parent (p "foo.example.com")).value;
    expected = "example.com";
  };
  parent-deep = {
    expr = (domain.parent (p "a.b.c.example.com")).value;
    expected = "b.c.example.com";
  };
  parent-two-is-null = {
    expr = domain.parent (p "example.com");
    expected = null;
  };
  parent-preserves-tag = {
    expr = (domain.parent (p "foo.example.com"))._type;
    expected = "domain";
  };

  # ===== isSubdomainOf =====
  subdomain-direct = {
    expr = domain.isSubdomainOf (p "foo.example.com") (p "example.com");
    expected = true;
  };
  subdomain-deep = {
    expr = domain.isSubdomainOf (p "a.b.c.example.com") (p "example.com");
    expected = true;
  };
  subdomain-self = {
    expr = domain.isSubdomainOf (p "example.com") (p "example.com");
    expected = true;
  };
  subdomain-not-suffix = {
    expr = domain.isSubdomainOf (p "evil.foo.com") (p "example.com");
    expected = false;
  };
  subdomain-shorter = {
    expr = domain.isSubdomainOf (p "example.com") (p "foo.example.com");
    expected = false;
  };
  subdomain-different-tld = {
    expr = domain.isSubdomainOf (p "foo.example.org") (p "example.com");
    expected = false;
  };
  subdomain-case-insens = {
    expr = domain.isSubdomainOf (p "Foo.Example.COM") (p "EXAMPLE.com");
    expected = true;
  };
  # "example.com.foo" is NOT a subdomain of "example.com" — the suffix
  # has to align at the trailing edge.
  subdomain-not-prefix-match = {
    expr = domain.isSubdomainOf (p "example.com.foo") (p "example.com");
    expected = false;
  };

  # ===== toHostname =====
  toHostname-extracts-leftmost = {
    expr = (domain.toHostname (p "foo.example.com")).value;
    expected = "foo";
  };
  toHostname-two-labels = {
    expr = (domain.toHostname (p "example.com")).value;
    expected = "example";
  };
  toHostname-tagged-as-hostname = {
    expr = (domain.toHostname (p "foo.example.com"))._type;
    expected = "hostname";
  };
  toHostname-preserves-case = {
    expr = (domain.toHostname (p "Foo.example.com")).value;
    expected = "Foo";
  };

  # ===== Normalize =====
  normalize-upper = {
    expr = (domain.normalize (p "FOO.EXAMPLE.COM")).value;
    expected = "foo.example.com";
  };
  normalize-already-lower = {
    expr = (domain.normalize (p "foo.example.com")).value;
    expected = "foo.example.com";
  };
  normalize-mixed = {
    expr = (domain.normalize (p "MyHost.Example.com")).value;
    expected = "myhost.example.com";
  };
  normalize-preserves-tag = {
    expr = domain.is (domain.normalize (p "FOO.EXAMPLE.COM"));
    expected = true;
  };

  # ===== Equality (case-insensitive) =====
  eq-same = {
    expr = domain.eq (p "example.com") (p "example.com");
    expected = true;
  };
  eq-case-upper = {
    expr = domain.eq (p "EXAMPLE.COM") (p "example.com");
    expected = true;
  };
  eq-case-mixed = {
    expr = domain.eq (p "MyHost.example.COM") (p "myhost.EXAMPLE.com");
    expected = true;
  };
  eq-diff = {
    expr = domain.eq (p "example.com") (p "example.org");
    expected = false;
  };

  # ===== Comparison (case-insensitive) =====
  lt-yes = {
    expr = domain.lt (p "alpha.com") (p "beta.com");
    expected = true;
  };
  lt-no = {
    expr = domain.lt (p "beta.com") (p "alpha.com");
    expected = false;
  };
  lt-case-insens = {
    expr = domain.lt (p "Alpha.com") (p "beta.com");
    expected = true;
  };
  compare-lt = {
    expr = domain.compare (p "alpha.com") (p "beta.com");
    expected = -1;
  };
  compare-eq-case = {
    expr = domain.compare (p "EXAMPLE.COM") (p "example.com");
    expected = 0;
  };
  compare-gt = {
    expr = domain.compare (p "z.com") (p "a.com");
    expected = 1;
  };
  le-equal = {
    expr = domain.le (p "example.com") (p "example.com");
    expected = true;
  };
  ge-equal = {
    expr = domain.ge (p "example.com") (p "example.com");
    expected = true;
  };
  min-pick = {
    expr = (domain.min (p "beta.com") (p "alpha.com")).value;
    expected = "alpha.com";
  };
  max-pick = {
    expr = (domain.max (p "beta.com") (p "alpha.com")).value;
    expected = "beta.com";
  };
}
