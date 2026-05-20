/*
  libnet.dnsName

  Pass-through union over Hostname and Domain — a DNS name that is not
  an IP literal. This is the "name" half of `host` (host = ip |
  dnsName). `parse` dispatches by label count: a single label parses
  as a hostname, multiple labels as a domain. IP literals are rejected
  (use `libnet.ip` for those) — that is what distinguishes a dnsName
  from a bare `domain`, which accepts all-numeric dotted forms.

  No new `_type` tag: the result is the underlying hostname or domain
  value; consumers branch on `value._type`. Same pattern as
  `libnet.ip` and `libnet.host`.

  Example:
    libnet.dnsName.parse "nas"            # tagged hostname
    libnet.dnsName.parse "pool.ntp.org"   # tagged domain
    libnet.dnsName.parse "192.0.2.1"      # throws — that's an IP
*/
let
  types = import ./internal/types.nix;
  ip = import ./ip.nix;
  hostname = import ./hostname.nix;
  domain = import ./domain.nix;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.dnsName.parse: input must be a string"
    else if ip.isValid s then
      types.tryErr "libnet.dnsName.parse: \"${s}\" is an IP address, not a DNS name"
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
          types.tryErr "libnet.dnsName.parse: \"${s}\" is not a valid hostname or domain";

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    n:
    if types.isHostname n then
      hostname.toString n
    else if types.isDomain n then
      domain.toString n
    else
      builtins.throw "libnet.dnsName.toString: expected hostname or domain value";

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = v: types.isHostname v || types.isDomain v;
  isHostname = types.isHostname;
  isDomain = types.isDomain;

  # ===== Normalization =====

  normalize =
    n:
    if types.isHostname n then
      hostname.normalize n
    else if types.isDomain n then
      domain.normalize n
    else
      builtins.throw "libnet.dnsName.normalize: expected hostname or domain value";

  # ===== Comparison =====
  #
  # Cross-family order: hostname (single label) sorts before domain
  # (multi label). Within a family, dispatches to that family's own
  # case-insensitive comparison.

  familyRank =
    v:
    if types.isHostname v then
      0
    else if types.isDomain v then
      1
    else
      builtins.throw "libnet.dnsName.compare: expected hostname or domain value";

  eq =
    a: b:
    if types.isHostname a && types.isHostname b then
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
    isHostname
    isDomain
    ;
  inherit normalize;
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
