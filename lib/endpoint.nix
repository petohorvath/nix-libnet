/*
  libnet.endpoint

  Pass-through union over IpEndpoint and DnsEndpoint — an ADDR:PORT
  where ADDR may be an IP literal or a DNS name. Composed as
  `ipEndpoint | dnsEndpoint`: an IP endpoint (including the bracketed
  `[ipv6]:port` form) is tried first, then a name endpoint.

  Returns the underlying typed value (no new `_type` tag); consumers
  branch on `value._type`. When the address is an IP, the result is a
  full `ipEndpoint` with all its IP-classification predicates
  available — only genuinely named endpoints come back as the
  predicate-free `dnsEndpoint`.

    endpoint = ipEndpoint | dnsEndpoint

  Example:
    libnet.endpoint.parse "192.0.2.1:80"      # tagged ipEndpoint
    libnet.endpoint.parse "[::1]:443"          # tagged ipEndpoint
    libnet.endpoint.parse "pool.ntp.org:123"   # tagged dnsEndpoint
*/
let
  types = import ./internal/types.nix;
  ipEndpoint = import ./ip-endpoint.nix;
  dnsEndpoint = import ./dns-endpoint.nix;

  # ===== Parsing =====

  # Dispatch order: ipEndpoint first, so an IP literal (or bracketed
  # IPv6) classifies as a concrete ipEndpoint rather than a domain.
  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.endpoint.parse: input must be a string"
    else
      let
        ipR = ipEndpoint.tryParse s;
      in
      if ipR.success then
        ipR
      else
        let
          dR = dnsEndpoint.tryParse s;
        in
        if dR.success then
          dR
        else
          types.tryErr "libnet.endpoint.parse: \"${s}\" is not a valid IP or name endpoint";

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    ep:
    if types.isIpEndpoint ep then
      ipEndpoint.toString ep
    else if types.isDnsEndpoint ep then
      dnsEndpoint.toString ep
    else
      builtins.throw "libnet.endpoint.toString: expected ipEndpoint or dnsEndpoint value";

  toUri = toString;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = v: types.isIpEndpoint v || types.isDnsEndpoint v;
  isIpEndpoint = types.isIpEndpoint;
  isDnsEndpoint = types.isDnsEndpoint;

  # ===== Accessors =====
  #
  # Both members store `{ address; port }`, so these work uniformly.

  address = ep: ep.address;

  # ===== Comparison =====
  #
  # Cross-kind order: ipEndpoint < dnsEndpoint. Within a kind,
  # delegates to that kind's comparator.

  rank =
    v:
    if types.isIpEndpoint v then
      0
    else if types.isDnsEndpoint v then
      1
    else
      builtins.throw "libnet.endpoint.compare: expected ipEndpoint or dnsEndpoint value";

  eq =
    a: b:
    if types.isIpEndpoint a && types.isIpEndpoint b then
      ipEndpoint.eq a b
    else if types.isDnsEndpoint a && types.isDnsEndpoint b then
      dnsEndpoint.eq a b
    else
      false;

  compare =
    a: b:
    let
      ra = rank a;
      rb = rank b;
    in
    if ra < rb then
      -1
    else if ra > rb then
      1
    else if ra == 0 then
      ipEndpoint.compare a b
    else
      dnsEndpoint.compare a b;

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
    toUri
    ;
  inherit
    isValid
    is
    isIpEndpoint
    isDnsEndpoint
    ;
  inherit address;
  # `port` accessor declared inline to mirror the member modules.
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
