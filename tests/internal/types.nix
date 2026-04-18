{ harness }:
let
  types = import ../../lib/internal/types.nix;
  inherit (harness) throws;

  # Minimal tagged fixtures — only _type matters for this module.
  ipv4 = {
    _type = "ipv4";
    value = 0;
  };
  ipv6 = {
    _type = "ipv6";
    words = [
      0
      0
      0
      0
    ];
  };
  mac = {
    _type = "mac";
    value = 0;
  };
  cidr = {
    _type = "cidr";
    address = ipv4;
    prefix = 24;
  };
  port = {
    _type = "port";
    value = 80;
  };
  portRange = {
    _type = "portRange";
    from = port;
    to = port;
  };
  endpoint = {
    _type = "endpoint";
    address = ipv4;
    port = port;
  };
  listener = {
    _type = "listener";
    address = ipv4;
    portRange = portRange;
  };
  ipRange = {
    _type = "ipRange";
    from = ipv4;
    to = ipv4;
  };
  interface = {
    _type = "interface";
    address = ipv4;
    prefix = 24;
  };

  untagged = {
    value = 0;
  };
in
{
  # ===== tags =====
  tags-ipv4 = {
    expr = types.tags.ipv4;
    expected = "ipv4";
  };
  tags-ipv6 = {
    expr = types.tags.ipv6;
    expected = "ipv6";
  };
  tags-mac = {
    expr = types.tags.mac;
    expected = "mac";
  };
  tags-cidr = {
    expr = types.tags.cidr;
    expected = "cidr";
  };
  tags-port = {
    expr = types.tags.port;
    expected = "port";
  };
  tags-portRange = {
    expr = types.tags.portRange;
    expected = "portRange";
  };
  tags-endpoint = {
    expr = types.tags.endpoint;
    expected = "endpoint";
  };
  tags-listener = {
    expr = types.tags.listener;
    expected = "listener";
  };
  tags-ipRange = {
    expr = types.tags.ipRange;
    expected = "ipRange";
  };
  tags-interface = {
    expr = types.tags.interface;
    expected = "interface";
  };

  # ===== hasTag =====
  hasTag-match = {
    expr = types.hasTag "ipv4" ipv4;
    expected = true;
  };
  hasTag-mismatch = {
    expr = types.hasTag "ipv6" ipv4;
    expected = false;
  };
  hasTag-untagged = {
    expr = types.hasTag "ipv4" untagged;
    expected = false;
  };
  hasTag-string = {
    expr = types.hasTag "ipv4" "1.2.3.4";
    expected = false;
  };
  hasTag-int = {
    expr = types.hasTag "ipv4" 42;
    expected = false;
  };
  hasTag-null = {
    expr = types.hasTag "ipv4" null;
    expected = false;
  };

  # ===== is* predicates: positive =====
  isIpv4-yes = {
    expr = types.isIpv4 ipv4;
    expected = true;
  };
  isIpv6-yes = {
    expr = types.isIpv6 ipv6;
    expected = true;
  };
  isMac-yes = {
    expr = types.isMac mac;
    expected = true;
  };
  isCidr-yes = {
    expr = types.isCidr cidr;
    expected = true;
  };
  isPort-yes = {
    expr = types.isPort port;
    expected = true;
  };
  isPortRange-yes = {
    expr = types.isPortRange portRange;
    expected = true;
  };
  isEndpoint-yes = {
    expr = types.isEndpoint endpoint;
    expected = true;
  };
  isListener-yes = {
    expr = types.isListener listener;
    expected = true;
  };
  isIpRange-yes = {
    expr = types.isIpRange ipRange;
    expected = true;
  };
  isInterface-yes = {
    expr = types.isInterface interface;
    expected = true;
  };

  # ===== is* predicates: cross-tag negative =====
  isIpv4-not-v6 = {
    expr = types.isIpv4 ipv6;
    expected = false;
  };
  isIpv6-not-v4 = {
    expr = types.isIpv6 ipv4;
    expected = false;
  };
  isCidr-not-range = {
    expr = types.isCidr ipRange;
    expected = false;
  };

  # ===== is* predicates: non-attrs =====
  isIpv4-string = {
    expr = types.isIpv4 "1.2.3.4";
    expected = false;
  };
  isMac-int = {
    expr = types.isMac 42;
    expected = false;
  };
  isPort-null = {
    expr = types.isPort null;
    expected = false;
  };
  isEndpoint-untagged = {
    expr = types.isEndpoint untagged;
    expected = false;
  };

  # ===== isIp (union) =====
  isIp-v4 = {
    expr = types.isIp ipv4;
    expected = true;
  };
  isIp-v6 = {
    expr = types.isIp ipv6;
    expected = true;
  };
  isIp-mac = {
    expr = types.isIp mac;
    expected = false;
  };
  isIp-string = {
    expr = types.isIp "1.2.3.4";
    expected = false;
  };

  # ===== tryOk / tryErr =====
  tryOk-success = {
    expr = (types.tryOk 42).success;
    expected = true;
  };
  tryOk-value = {
    expr = (types.tryOk 42).value;
    expected = 42;
  };
  tryOk-error = {
    expr = (types.tryOk 42).error;
    expected = null;
  };
  tryErr-success = {
    expr = (types.tryErr "boom").success;
    expected = false;
  };
  tryErr-value = {
    expr = (types.tryErr "boom").value;
    expected = null;
  };
  tryErr-error = {
    expr = (types.tryErr "boom").error;
    expected = "boom";
  };

  # ===== ensureTag =====
  ensureTag-returns-input = {
    expr = types.ensureTag "ipv4" "libnet.test" ipv4 == ipv4;
    expected = true;
  };
  ensureTag-wrong-tag-throws = {
    expr = throws (types.ensureTag "ipv4" "libnet.test" ipv6);
    expected = true;
  };
  ensureTag-untagged-throws = {
    expr = throws (types.ensureTag "ipv4" "libnet.test" untagged);
    expected = true;
  };
  ensureTag-non-attrs-throws = {
    expr = throws (types.ensureTag "ipv4" "libnet.test" 42);
    expected = true;
  };
  ensureTag-string-throws = {
    expr = throws (types.ensureTag "ipv4" "libnet.test" "1.2.3.4");
    expected = true;
  };
}
