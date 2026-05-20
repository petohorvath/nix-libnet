/*
  libnet.host

  Pass-through union over Ipv4, Ipv6, Hostname, and Domain — the
  shapes a service consumer might address. Composed as `ip | dnsName`:
  `parse` tries an IP first (so dotted-quad strings classify as IPs),
  then falls back to a DNS name (single-label hostname or multi-label
  domain).

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
  dnsName = import ./dns-name.nix;

  # ===== Parsing =====

  # Dispatch order: ip first (so dotted-quad strings parse as IPs
  # rather than as multi-label domains), then dnsName (hostname or
  # domain). dnsName rejects IP literals, but since ip is tried first
  # that branch is only reached for non-IP strings.
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
          nR = dnsName.tryParse s;
        in
        if nR.success then
          nR
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
    if types.isIp h then
      ip.toString h
    else if dnsName.is h then
      dnsName.toString h
    else
      builtins.throw "libnet.host.toString: expected ip, hostname, or domain value";

  # ===== Predicates =====

  isIp = types.isIp;
  isHostname = types.isHostname;
  isDomain = types.isDomain;
  isName = dnsName.is;
  is = v: types.isIp v || dnsName.is v;
  isValid = s: (tryParse s).success;

  # ===== Comparison =====
  #
  # Cross-family order: ip < name (hostname < domain within names).
  # Within the IP family, ipv4 < ipv6 (delegated to ip.compare); among
  # names, delegated to dnsName.compare (case-insensitive per DNS).

  rank = v: if types.isIp v then 0 else 1;

  eq =
    a: b:
    if types.isIp a && types.isIp b then
      ip.eq a b
    else if dnsName.is a && dnsName.is b then
      dnsName.eq a b
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
      ip.compare a b
    else
      dnsName.compare a b;

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
