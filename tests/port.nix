{ harness }:
let
  port = import ../lib/port.nix;
  inherit (harness) throws;
  p = port.parse;
in
{
  # ===== Parse =====
  parse-zero = {
    expr = port.toInt (p "0");
    expected = 0;
  };
  parse-one = {
    expr = port.toInt (p "1");
    expected = 1;
  };
  parse-http = {
    expr = port.toInt (p "80");
    expected = 80;
  };
  parse-max = {
    expr = port.toInt (p "65535");
    expected = 65535;
  };

  reject-neg = {
    expr = throws (p "-1");
    expected = true;
  };
  reject-plus = {
    expr = throws (p "+80");
    expected = true;
  };
  reject-over = {
    expr = throws (p "65536");
    expected = true;
  };
  reject-hex = {
    expr = throws (p "0x50");
    expected = true;
  };
  reject-empty = {
    expr = throws (p "");
    expected = true;
  };
  reject-whitespace = {
    expr = throws (p " 80");
    expected = true;
  };
  reject-trailing = {
    expr = throws (p "80 ");
    expected = true;
  };
  reject-not-string = {
    expr = throws (port.parse 80);
    expected = true;
  };

  tryParse-ok = {
    expr = (port.tryParse "80").success;
    expected = true;
  };
  tryParse-bad = {
    expr = (port.tryParse "65536").success;
    expected = false;
  };

  # ===== Round-trip =====
  rt-string = {
    expr = port.toString (p "80");
    expected = "80";
  };
  rt-int = {
    expr = port.toInt (port.fromInt 80);
    expected = 80;
  };

  fromInt-neg = {
    expr = throws (port.fromInt (-1));
    expected = true;
  };
  fromInt-over = {
    expr = throws (port.fromInt 65536);
    expected = true;
  };

  # ===== Predicates =====
  is-parsed = {
    expr = port.is (p "80");
    expected = true;
  };
  is-int = {
    expr = port.is 80;
    expected = false;
  };
  isValid-ok = {
    expr = port.isValid "80";
    expected = true;
  };
  isValid-bad = {
    expr = port.isValid "0x50";
    expected = false;
  };

  isWellKnown-22 = {
    expr = port.isWellKnown (p "22");
    expected = true;
  };
  isWellKnown-1024 = {
    expr = port.isWellKnown (p "1024");
    expected = false;
  };
  isRegistered-1024 = {
    expr = port.isRegistered (p "1024");
    expected = true;
  };
  isRegistered-49152 = {
    expr = port.isRegistered (p "49152");
    expected = false;
  };
  isDynamic-49152 = {
    expr = port.isDynamic (p "49152");
    expected = true;
  };
  isDynamic-49151 = {
    expr = port.isDynamic (p "49151");
    expected = false;
  };
  isReserved-0 = {
    expr = port.isReserved (p "0");
    expected = true;
  };
  isReserved-1 = {
    expr = port.isReserved (p "1");
    expected = false;
  };
  isEphemeral-alias = {
    expr = port.isEphemeral (p "49152");
    expected = true;
  };

  # ===== Arithmetic =====
  add-one = {
    expr = port.toInt (port.add 1 (p "80"));
    expected = 81;
  };
  sub-one = {
    expr = port.toInt (port.sub 1 (p "80"));
    expected = 79;
  };
  diff = {
    expr = port.diff (p "80") (p "90");
    expected = 10;
  };
  next-ok = {
    expr = port.toInt (port.next (p "80"));
    expected = 81;
  };
  prev-ok = {
    expr = port.toInt (port.prev (p "80"));
    expected = 79;
  };
  add-overflow = {
    expr = throws (port.add 1 (p "65535"));
    expected = true;
  };
  sub-underflow = {
    expr = throws (port.sub 1 (p "0"));
    expected = true;
  };

  # ===== Comparison =====
  eq-same = {
    expr = port.eq (p "80") (p "80");
    expected = true;
  };
  eq-diff = {
    expr = port.eq (p "80") (p "81");
    expected = false;
  };
  lt-yes = {
    expr = port.lt (p "80") (p "81");
    expected = true;
  };
  compare-lt = {
    expr = port.compare (p "80") (p "81");
    expected = -1;
  };
  compare-eq = {
    expr = port.compare (p "80") (p "80");
    expected = 0;
  };
  compare-gt = {
    expr = port.compare (p "81") (p "80");
    expected = 1;
  };
  min-smaller = {
    expr = port.toInt (port.min (p "80") (p "81"));
    expected = 80;
  };
  max-larger = {
    expr = port.toInt (port.max (p "80") (p "81"));
    expected = 81;
  };

  # ===== Well-known constants =====
  const-http = {
    expr = port.toInt port.http;
    expected = 80;
  };
  const-https = {
    expr = port.toInt port.https;
    expected = 443;
  };
  const-ssh = {
    expr = port.toInt port.ssh;
    expected = 22;
  };
  const-dns = {
    expr = port.toInt port.dns;
    expected = 53;
  };
  const-smtp = {
    expr = port.toInt port.smtp;
    expected = 25;
  };
  const-postgres = {
    expr = port.toInt port.postgres;
    expected = 5432;
  };
  const-redis = {
    expr = port.toInt port.redis;
    expected = 6379;
  };
  const-mongodb = {
    expr = port.toInt port.mongodb;
    expected = 27017;
  };
  const-is-valid = {
    expr = port.is port.http;
    expected = true;
  };
  const-isWellKnown = {
    expr = port.isWellKnown port.http;
    expected = true;
  };
  const-registered = {
    expr = port.isRegistered port.postgres;
    expected = true;
  };

  # Boundary-value ints
  wellKnownMax = {
    expr = port.wellKnownMax;
    expected = 1023;
  };
  registeredMax = {
    expr = port.registeredMax;
    expected = 49151;
  };
  lowestValue = {
    expr = port.lowestValue;
    expected = 0;
  };
  highestValue = {
    expr = port.highestValue;
    expected = 65535;
  };
}
