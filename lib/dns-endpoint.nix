/*
  libnet.dnsEndpoint

  A DNS name (hostname or domain) paired with a port — the name-only
  counterpart to libnet.ipEndpoint. The address is a `dnsName`, so IP
  literals are rejected (use `ipEndpoint`, or the `endpoint` union,
  for those).

  No IP-classification predicates (isLoopback, isGlobal, toArpa, …): a
  name has no resolved address until DNS runs, and libnet does no
  resolution.

  Example:
    libnet.dnsEndpoint.parse "pool.ntp.org:123"
    => { _type = "dnsEndpoint"; address = <domain>; port = <port 123>; }

    libnet.dnsEndpoint.parse "nas:22"
    => { _type = "dnsEndpoint"; address = <hostname>; port = <port 22>; }
*/
let
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  dnsName = import ./dns-name.nix;
  port = import ./port.nix;

  mk = addr: pt: {
    _type = "dnsEndpoint";
    address = addr;
    port = pt;
  };

  # ===== Parsing =====

  # name:port — exactly one ':' (DNS names contain no colons), no
  # bracket form (brackets denote an IPv6 literal, which is an IP, not
  # a name).
  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.dnsEndpoint.parse: input must be a string"
    else if parse'.startsWith "[" s then
      types.tryErr "libnet.dnsEndpoint.parse: bracketed form is for IPv6; a dnsEndpoint addresses a name: \"${s}\""
    else if parse'.countOccurrences ":" s != 1 then
      types.tryErr "libnet.dnsEndpoint.parse: expected exactly one ':' (name:port): \"${s}\""
    else
      let
        parts = parse'.splitOn ":" s;
        addrStr = builtins.elemAt parts 0;
        portStr = builtins.elemAt parts 1;
        addrRes = dnsName.tryParse addrStr;
        portRes = port.tryParse portStr;
      in
      if !addrRes.success then
        types.tryErr "libnet.dnsEndpoint.parse: ${addrRes.error}"
      else if !portRes.success then
        types.tryErr "libnet.dnsEndpoint.parse: invalid port in \"${s}\""
      else
        types.tryOk (mk addrRes.value portRes.value);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString = ep: "${dnsName.toString ep.address}:${port.toString ep.port}";

  make =
    addr: pt:
    if !(dnsName.is addr) then
      builtins.throw "libnet.dnsEndpoint.make: address must be a hostname or domain"
    else if !(types.isPort pt) then
      builtins.throw "libnet.dnsEndpoint.make: expected port value"
    else
      mk addr pt;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isDnsEndpoint;
  isHostname = ep: types.isHostname ep.address;
  isDomain = ep: types.isDomain ep.address;

  # ===== Accessors =====

  address = ep: ep.address;

  # ===== Comparison =====
  #
  # Dispatch on the name address (case-insensitive per DNS), then port.

  eq = a: b: dnsName.eq a.address b.address && port.eq a.port b.port;

  compare =
    a: b:
    let
      addrCmp = dnsName.compare a.address b.address;
    in
    if addrCmp != 0 then addrCmp else port.compare a.port b.port;

  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;
in
{
  inherit
    parse
    tryParse
    toString
    make
    ;
  inherit
    isValid
    is
    isHostname
    isDomain
    ;
  inherit address;
  # `port` accessor declared inline to avoid shadowing the imported
  # `port` module used above.
  port = ep: ep.port;
  inherit
    eq
    lt
    le
    gt
    ge
    compare
    min
    max
    ;
}
