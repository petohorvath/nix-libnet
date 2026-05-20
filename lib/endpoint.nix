/*
  libnet.endpoint

  Pass-through union over the three complete connection targets:
  `ipEndpoint` (ip:port), `dnsEndpoint` (name:port), and `unixSocket`
  (a socket path). `parse` dispatches by shape:
  - leading `/` or `@` → unixSocket
  - bracketed `[ipv6]:port` or `addr:port` parsing as an IP → ipEndpoint
  - otherwise `name:port` → dnsEndpoint

  Returns the underlying typed value (no new `_type` tag); consumers
  branch on `value._type`. When the target is an IP, the result is a
  full `ipEndpoint` with all its IP-classification predicates available.

    endpoint = ipEndpoint | dnsEndpoint | unixSocket

  The three members are heterogeneous — `ipEndpoint`/`dnsEndpoint` have
  `address` + `port`, `unixSocket` has `path` — so this union exposes
  predicates + `toString` + comparison rather than uniform accessors.
  Branch with `isIpEndpoint` / `isDnsEndpoint` / `isUnixSocket` and use
  the member module's accessors.

  Example:
    libnet.endpoint.parse "192.0.2.1:80"      # tagged ipEndpoint
    libnet.endpoint.parse "pool.ntp.org:123"   # tagged dnsEndpoint
    libnet.endpoint.parse "/run/foo.sock"      # tagged unixSocket
*/
let
  types = import ./internal/types.nix;
  parse' = import ./internal/parse.nix;
  ipEndpoint = import ./ip-endpoint.nix;
  dnsEndpoint = import ./dns-endpoint.nix;
  unixSocket = import ./unix-socket.nix;

  # ===== Parsing =====

  # A leading `/` or `@` unambiguously marks a unix socket (no addr:port
  # form starts that way). Otherwise ipEndpoint is tried before
  # dnsEndpoint so an IP literal (or bracketed IPv6) classifies as a
  # concrete ipEndpoint rather than a domain.
  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.endpoint.parse: input must be a string"
    else if parse'.startsWith "/" s || parse'.startsWith "@" s then
      unixSocket.tryParse s
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
          types.tryErr "libnet.endpoint.parse: \"${s}\" is not a valid IP, name, or unix-socket endpoint";

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
    else if types.isUnixSocket ep then
      unixSocket.toString ep
    else
      builtins.throw "libnet.endpoint.toString: expected ipEndpoint, dnsEndpoint, or unixSocket value";

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = v: types.isIpEndpoint v || types.isDnsEndpoint v || types.isUnixSocket v;
  isIpEndpoint = types.isIpEndpoint;
  isDnsEndpoint = types.isDnsEndpoint;
  isUnixSocket = types.isUnixSocket;

  # ===== Comparison =====
  #
  # Cross-kind order: ipEndpoint < dnsEndpoint < unixSocket. Within a
  # kind, delegates to that kind's comparator.

  rank =
    v:
    if types.isIpEndpoint v then
      0
    else if types.isDnsEndpoint v then
      1
    else if types.isUnixSocket v then
      2
    else
      builtins.throw "libnet.endpoint.compare: expected ipEndpoint, dnsEndpoint, or unixSocket value";

  eq =
    a: b:
    if types.isIpEndpoint a && types.isIpEndpoint b then
      ipEndpoint.eq a b
    else if types.isDnsEndpoint a && types.isDnsEndpoint b then
      dnsEndpoint.eq a b
    else if types.isUnixSocket a && types.isUnixSocket b then
      unixSocket.eq a b
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
    else if ra == 1 then
      dnsEndpoint.compare a b
    else
      unixSocket.compare a b;

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
    isIpEndpoint
    isDnsEndpoint
    isUnixSocket
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
