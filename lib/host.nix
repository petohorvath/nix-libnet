/*
  libnet.host

  Pass-through union over Ipv4, Ipv6, Hostname, and Domain — the four
  shapes a service consumer might address. `parse` dispatches by
  string shape:
  - colons or dotted-quad → ip (ipv4 or ipv6)
  - no dots → hostname
  - dots → domain

  Returns the underlying typed value (no new `_type` tag); consumers
  branch on `value._type` to access family-specific operations. Same
  pattern as `libnet.ip` for the v4/v6 split.

  Example:
    libnet.host.parse "192.168.1.1"   # tagged ipv4
    libnet.host.parse "nas"            # tagged hostname
    libnet.host.parse "pool.ntp.org"   # tagged domain
*/
let
  types = import ./internal/types.nix;
  ip = import ./ip.nix;
  hostname = import ./hostname.nix;
  domain = import ./domain.nix;

  # ===== Parsing =====

  # Dispatch order: ip first (so dotted-quad strings parse as IPs
  # rather than as multi-label domains), then hostname (single-label),
  # then domain (multi-label). The orderings are non-overlapping
  # except for IP-shaped strings, which we intentionally classify
  # as IPs.
  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.host.parse: input must be a string"
    else
      let
        ipR = ip.tryParse s;
      in
      if ipR.success then
        ipR
      else
        let
          hnR = hostname.tryParse s;
        in
        if hnR.success then
          hnR
        else
          let
            dR = domain.tryParse s;
          in
          if dR.success then
            dR
          else
            types.tryErr "libnet.host.parse: \"${s}\" is not a valid IP, hostname, or domain";

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    h:
    if types.isIpv4 h || types.isIpv6 h then
      ip.toString h
    else if types.isHostname h then
      hostname.toString h
    else if types.isDomain h then
      domain.toString h
    else
      builtins.throw "libnet.host.toString: expected ip, hostname, or domain value";

  # ===== Predicates =====

  isIp = types.isIp;
  isHostname = types.isHostname;
  isDomain = types.isDomain;
  isName = v: types.isHostname v || types.isDomain v;
  is = v: types.isIp v || isName v;
  isValid = s: (tryParse s).success;

  # ===== Comparison =====
  #
  # Cross-family order: ip < hostname < domain. Within the IP family,
  # ipv4 < ipv6 (delegated to ip.compare). Within hostname / domain,
  # delegates to the family's own comparison (case-insensitive per
  # DNS semantics).

  familyRank =
    v:
    if types.isIp v then
      0
    else if types.isHostname v then
      1
    else if types.isDomain v then
      2
    else
      builtins.throw "libnet.host.compare: expected ip, hostname, or domain value";

  eq =
    a: b:
    if !(is a) || !(is b) then
      false
    else if types.isIp a && types.isIp b then
      ip.eq a b
    else if types.isHostname a && types.isHostname b then
      hostname.eq a b
    else if types.isDomain a && types.isDomain b then
      domain.eq a b
    else
      false;

  compare =
    a: b:
    let
      ra = familyRank a;
      rb = familyRank b;
    in
    if ra < rb then
      -1
    else if ra > rb then
      1
    else if ra == 0 then
      ip.compare a b
    else if ra == 1 then
      hostname.compare a b
    else
      domain.compare a b;

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
    ;
  inherit
    isValid
    is
    isIp
    isHostname
    isDomain
    isName
    ;
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
