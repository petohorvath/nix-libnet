{ harness }:
let
  mtu = import ../lib/mtu.nix;
  _ = harness; # not used directly; tests are pure predicates.
in
{
  # ===== valid range =====
  isValid-min = {
    expr = mtu.isValid 68;
    expected = true;
  };
  isValid-ethernet = {
    expr = mtu.isValid 1500;
    expected = true;
  };
  isValid-ipv6-min = {
    expr = mtu.isValid 1280;
    expected = true;
  };
  isValid-wg-typical = {
    expr = mtu.isValid 1420;
    expected = true;
  };
  isValid-jumbo = {
    expr = mtu.isValid 9000;
    expected = true;
  };
  isValid-loopback = {
    expr = mtu.isValid 65536; # one above max
    expected = false;
  };
  isValid-max = {
    expr = mtu.isValid 65535;
    expected = true;
  };

  # ===== boundary rejects =====
  isValid-below-min = {
    expr = mtu.isValid 67;
    expected = false;
  };
  isValid-tiny = {
    expr = mtu.isValid 5;
    expected = false;
  };
  isValid-zero = {
    expr = mtu.isValid 0;
    expected = false;
  };
  isValid-negative = {
    expr = mtu.isValid (-1);
    expected = false;
  };
  isValid-huge = {
    expr = mtu.isValid 100000;
    expected = false;
  };

  # ===== type rejects =====
  isValid-string = {
    expr = mtu.isValid "1500";
    expected = false;
  };
  isValid-null = {
    expr = mtu.isValid null;
    expected = false;
  };
  isValid-float = {
    expr = mtu.isValid 1500.5;
    expected = false;
  };
  isValid-bool = {
    expr = mtu.isValid true;
    expected = false;
  };
  isValid-list = {
    expr = mtu.isValid [ 1500 ];
    expected = false;
  };

  # ===== Constants =====
  lowestValue = {
    expr = mtu.lowestValue;
    expected = 68;
  };
  highestValue = {
    expr = mtu.highestValue;
    expected = 65535;
  };
}
