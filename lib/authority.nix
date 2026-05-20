/*
  libnet.authority

  The authority component of a URL (RFC 3986 §3.2):
  `[userinfo@]<host>[:port]`. The shared core of `libnet.url`, which is
  `<scheme>://<authority>[/path][?query][#fragment]`; extracted so the
  authority can be parsed and compared on its own.

  - `host` is a `libnet.urlHost` (RFC 3986 IP-literal / IPv4 / reg-name;
    looser than `libnet.host`).
  - `userinfo` is kept raw and opaque (may carry credentials).
  - `port` is an explicit `port` value, or null when omitted.

  Components are stored verbatim — no percent-decoding or normalization.
  Bounded like the URL forms: no scheme, path, query, or fragment.

    { _type = "authority"; userinfo = <string | null>;
      host = <urlHost value>; port = <port value | null>; }

  Example:
    libnet.authority.parse "user@example.com:8443"
    => { _type = "authority"; userinfo = "user";
         host = <urlHost example.com>; port = <port 8443>; }
*/
let
  types = import ./internal/types.nix;
  parse' = import ./internal/parse.nix;
  urlHost = import ./url-host.nix;
  port = import ./port.nix;

  mkPort = port.fromInt;

  mk = userinfo: host: portVal: {
    _type = "authority";
    inherit userinfo host;
    port = portVal;
  };

  # ===== Parsing =====

  # Split "host[:port]" into { host; portStr }, or null if malformed. A
  # bracketed IPv6 literal (`[::1]:80`) is handled so the colons inside
  # it are not mistaken for the port separator.
  splitHostPort =
    hp:
    if parse'.startsWith "[" hp then
      let
        parts = parse'.splitOn "]" hp;
      in
      if builtins.length parts < 2 then
        null
      else
        let
          host = (builtins.elemAt parts 0) + "]";
          after = builtins.concatStringsSep "]" (builtins.tail parts);
        in
        if after == "" then
          {
            inherit host;
            portStr = null;
          }
        else if parse'.startsWith ":" after then
          {
            inherit host;
            portStr = parse'.stripPrefix ":" after;
          }
        else
          null
    else
      let
        parts = parse'.splitOn ":" hp;
        n = builtins.length parts;
      in
      if n == 1 then
        {
          host = hp;
          portStr = null;
        }
      else if n == 2 then
        {
          host = builtins.elemAt parts 0;
          portStr = builtins.elemAt parts 1;
        }
      else
        null;

  tryParse =
    a:
    if !(builtins.isString a) then
      types.tryErr "libnet.authority.parse: input must be a string"
    else
      let
        atParts = parse'.splitOn "@" a;
        nAt = builtins.length atParts;
      in
      if nAt > 2 then
        types.tryErr "libnet.authority.parse: malformed userinfo (multiple '@')"
      else
        let
          userinfo = if nAt == 2 then builtins.elemAt atParts 0 else null;
          hostport = builtins.elemAt atParts (nAt - 1);
          hp = splitHostPort hostport;
        in
        if hp == null then
          types.tryErr "libnet.authority.parse: malformed authority \"${a}\""
        else
          let
            hostRes = urlHost.tryParse hp.host;
            portRes = if hp.portStr == null then null else port.tryParse hp.portStr;
          in
          if !hostRes.success then
            types.tryErr "libnet.authority.parse: invalid host \"${hp.host}\""
          else if portRes != null && !portRes.success then
            types.tryErr "libnet.authority.parse: invalid port \"${hp.portStr}\""
          else
            types.tryOk (mk userinfo hostRes.value (if portRes == null then null else portRes.value));

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    au:
    let
      ui = if au.userinfo == null then "" else "${au.userinfo}@";
      pt = if au.port == null then "" else ":${port.toString au.port}";
    in
    "${ui}${urlHost.toString au.host}${pt}";

  # ===== Construction =====

  # `make` takes primitives (strings + an int port), not tagged values:
  # an authority is built from its textual parts. Pass a string to
  # `parse` if you already have one.
  make =
    {
      host,
      userinfo ? null,
      port ? null,
    }:
    let
      h = urlHost.tryParse host;
    in
    if !h.success then
      builtins.throw "libnet.authority.make: invalid host \"${host}\""
    else if port != null && !(builtins.isInt port) then
      builtins.throw "libnet.authority.make: port must be an int or null"
    else
      mk userinfo h.value (if port == null then null else mkPort port);

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isAuthority;

  # ===== Comparison =====
  #
  # Structural: host (case-folded), then port, then userinfo. Unlike
  # `url`, userinfo *is* part of identity here — an authority is exactly
  # `[userinfo@]host[:port]` — and the port is compared as-stored, since
  # an authority has no scheme and therefore no default port.

  cmpStr =
    x: y:
    if x < y then
      -1
    else if x > y then
      1
    else
      0;

  cmpOpt =
    x: y:
    if x == null && y == null then
      0
    else if x == null then
      -1
    else if y == null then
      1
    else
      cmpStr x y;

  portEq =
    a: b:
    if a == null && b == null then
      true
    else if a == null || b == null then
      false
    else
      port.eq a b;

  portCompare =
    a: b:
    if a == null && b == null then
      0
    else if a == null then
      -1
    else if b == null then
      1
    else
      port.compare a b;

  eq = a: b: a.userinfo == b.userinfo && urlHost.eq a.host b.host && portEq a.port b.port;

  compare =
    a: b:
    let
      hc = urlHost.compare a.host b.host;
    in
    if hc != 0 then
      hc
    else
      let
        pc = portCompare a.port b.port;
      in
      if pc != 0 then pc else cmpOpt a.userinfo b.userinfo;

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
  inherit isValid is;
  # `userinfo` / `host` / `port` accessors declared inline to avoid
  # shadowing the imported modules of the same name.
  userinfo = au: au.userinfo;
  host = au: au.host;
  port = au: au.port;
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
