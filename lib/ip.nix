let
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.ip.parse: input must be a string"
    else if parse'.countOccurrences ":" s > 0 then
      ipv6.tryParse s
    else
      ipv4.tryParse s;

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    ip:
    if types.isIpv4 ip then
      ipv4.toString ip
    else if types.isIpv6 ip then
      ipv6.toString ip
    else
      builtins.throw "libnet.ip.toString: expected ipv4 or ipv6 value";

  version =
    ip:
    if types.isIpv4 ip then
      4
    else if types.isIpv6 ip then
      6
    else
      builtins.throw "libnet.ip.version: expected ipv4 or ipv6 value";

  isValid = s: (tryParse s).success;
  is = types.isIp;
  isIpv4 = types.isIpv4;
  isIpv6 = types.isIpv6;

  # ===== Forwarded predicates =====

  dispatch =
    ctx: v4Fn: v6Fn: ip:
    if types.isIpv4 ip then
      v4Fn ip
    else if types.isIpv6 ip then
      v6Fn ip
    else
      builtins.throw "libnet.ip.${ctx}: expected ipv4 or ipv6 value";

  isLoopback = dispatch "isLoopback" ipv4.isLoopback ipv6.isLoopback;
  isUnspecified = dispatch "isUnspecified" ipv4.isUnspecified ipv6.isUnspecified;
  isLinkLocal = dispatch "isLinkLocal" ipv4.isLinkLocal ipv6.isLinkLocal;
  isMulticast = dispatch "isMulticast" ipv4.isMulticast ipv6.isMulticast;
  isDocumentation = dispatch "isDocumentation" ipv4.isDocumentation ipv6.isDocumentation;
  isGlobal = dispatch "isGlobal" ipv4.isGlobal ipv6.isGlobal;
  isBogon = dispatch "isBogon" ipv4.isBogon ipv6.isBogon;
  toArpa = dispatch "toArpa" ipv4.toArpa ipv6.toArpa;

  # ===== Comparison (lenient cross-family) =====

  eq =
    a: b:
    if a._type != b._type then
      false
    else if types.isIpv4 a then
      ipv4.eq a b
    else
      ipv6.eq a b;

  compare =
    a: b:
    if types.isIpv4 a && types.isIpv6 b then
      -1
    else if types.isIpv6 a && types.isIpv4 b then
      1
    else if types.isIpv4 a then
      ipv4.compare a b
    else
      ipv6.compare a b;

  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;

  # ===== Arithmetic (dispatched) =====

  add = n: dispatch "add" (ipv4.add n) (ipv6.add n);
  sub = n: dispatch "sub" (ipv4.sub n) (ipv6.sub n);
  next = dispatch "next" ipv4.next ipv6.next;
  prev = dispatch "prev" ipv4.prev ipv6.prev;

  diff =
    a: b:
    if a._type != b._type then
      builtins.throw "libnet.ip.diff: cross-family difference is undefined"
    else if types.isIpv4 a then
      ipv4.diff a b
    else
      ipv6.diff a b;
in
{
  inherit
    parse
    tryParse
    toString
    version
    ;
  inherit
    isValid
    is
    isIpv4
    isIpv6
    ;
  inherit
    isLoopback
    isUnspecified
    isLinkLocal
    isMulticast
    isDocumentation
    isGlobal
    isBogon
    toArpa
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
  inherit
    add
    sub
    diff
    next
    prev
    ;
}
