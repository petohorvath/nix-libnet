let
  tags = {
    ipv4 = "ipv4";
    ipv6 = "ipv6";
    mac = "mac";
    cidr = "cidr";
    port = "port";
    portRange = "portRange";
    endpoint = "endpoint";
    listener = "listener";
    range = "range";
    interface = "interface";
  };

  hasTag = tag: v: builtins.isAttrs v && v ? _type && v._type == tag;

  isIpv4 = hasTag tags.ipv4;
  isIpv6 = hasTag tags.ipv6;
  isMac = hasTag tags.mac;
  isCidr = hasTag tags.cidr;
  isPort = hasTag tags.port;
  isPortRange = hasTag tags.portRange;
  isEndpoint = hasTag tags.endpoint;
  isListener = hasTag tags.listener;
  isRange = hasTag tags.range;
  isInterface = hasTag tags.interface;
  isIp = v: isIpv4 v || isIpv6 v;

  tryOk = value: {
    success = true;
    inherit value;
    error = null;
  };
  tryErr = error: {
    success = false;
    value = null;
    inherit error;
  };

  ensureTag =
    tag: ctx: v:
    if hasTag tag v then
      v
    else
      builtins.throw "libnet: ${ctx}: expected ${tag} value, got ${
        if builtins.isAttrs v && v ? _type then "${v._type} value" else builtins.typeOf v
      }";
in
{
  inherit tags hasTag;
  inherit
    isIpv4
    isIpv6
    isMac
    isCidr
    isPort
    isPortRange
    isEndpoint
    isListener
    isRange
    isInterface
    isIp
    ;
  inherit tryOk tryErr ensureTag;
}
