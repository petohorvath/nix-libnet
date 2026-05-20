/*
  libnet.socketUrl

  A socket address in URL form: `<scheme>://<endpoint>`. A bounded
  composition of `transport` and `endpoint`, *not* a general URL parser
  (no userinfo, query, fragment, percent-encoding, or relative
  resolution; see `url` in SPEC Non-Goals). For the TLS-secured peer
  (`tls`/`ssl`/`dtls`/`quic`), see `secureSocketUrl`.

  Schemes:
  - `tcp` / `udp` / `sctp` → an IP or DNS endpoint follows
    (`tcp://1.2.3.4:80`, `udp://[::]:53`, `sctp://pool.ntp.org:9999`).
  - `unix` → a socket path follows (`unix:///run/foo.sock`,
    `unix://@abstract`); no port.

  Stored as the underlying `transport` + `endpoint` pair:

    { _type = "socketUrl"; transport = <transport | null>; endpoint = <endpoint>; }

  Invariant: `transport == null` iff `endpoint` is a `unixSocket` — a
  Unix socket has no L4 transport, its scheme is the literal `unix`.

  Example:
    libnet.socketUrl.parse "tcp://1.2.3.4:80"
    => { _type = "socketUrl"; transport = <tcp>; endpoint = <ipEndpoint>; }

    libnet.socketUrl.toString (libnet.socketUrl.parse "unix:///run/foo.sock")
    => "unix:///run/foo.sock"
*/
let
  types = import ./internal/types.nix;
  parse' = import ./internal/parse.nix;
  transport = import ./transport.nix;
  endpoint = import ./endpoint.nix;

  unixScheme = "unix";

  mk = tr: ep: {
    _type = "socketUrl";
    transport = tr;
    endpoint = ep;
  };

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.socketUrl.parse: input must be a string"
    else
      let
        parts = parse'.splitOn "://" s;
      in
      if builtins.length parts < 2 then
        types.tryErr "libnet.socketUrl.parse: missing '<scheme>://': \"${s}\""
      else
        let
          scheme = builtins.elemAt parts 0;
          # Rejoin the remainder so a stray '://' inside a path is kept.
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
          epRes = endpoint.tryParse rest;
        in
        if !epRes.success then
          types.tryErr "libnet.socketUrl.parse: invalid address in \"${s}\""
        else
          let
            ep = epRes.value;
          in
          if scheme == unixScheme then
            if types.isUnixSocket ep then
              types.tryOk (mk null ep)
            else
              types.tryErr "libnet.socketUrl.parse: 'unix://' requires a socket path: \"${s}\""
          else
            let
              trRes = transport.tryParse scheme;
            in
            if !trRes.success then
              types.tryErr "libnet.socketUrl.parse: unknown scheme \"${scheme}\" (expected tcp, udp, sctp, or unix)"
            else if types.isUnixSocket ep then
              types.tryErr "libnet.socketUrl.parse: '${scheme}://' requires host:port, not a socket path: \"${s}\""
            else
              types.tryOk (mk trRes.value ep);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    su:
    let
      scheme = if su.transport == null then unixScheme else transport.toString su.transport;
    in
    "${scheme}://${endpoint.toString su.endpoint}";

  # ===== Construction =====

  make =
    tr: ep:
    if !(endpoint.is ep) then
      builtins.throw "libnet.socketUrl.make: expected an endpoint value"
    else if types.isUnixSocket ep then
      (
        if tr != null then
          builtins.throw "libnet.socketUrl.make: a unix socket takes no transport (pass null)"
        else
          mk null ep
      )
    else if !(types.isTransport tr) then
      builtins.throw "libnet.socketUrl.make: expected a transport value for an IP/DNS endpoint"
    else
      mk tr ep;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isSocketUrl;
  isUnix = su: su.transport == null;

  # ===== Comparison =====
  #
  # `transport` itself has no canonical order, so sockets sort by a
  # fixed scheme rank (tcp < udp < sctp < unix), then by endpoint.

  schemeRank =
    tr:
    if tr == null then
      3
    else if transport.isTcp tr then
      0
    else if transport.isUdp tr then
      1
    else
      2;

  transportEq =
    a: b:
    if a == null && b == null then
      true
    else if a == null || b == null then
      false
    else
      transport.eq a b;

  eq = a: b: transportEq a.transport b.transport && endpoint.eq a.endpoint b.endpoint;

  compare =
    a: b:
    let
      ra = schemeRank a.transport;
      rb = schemeRank b.transport;
    in
    if ra < rb then
      -1
    else if ra > rb then
      1
    else
      endpoint.compare a.endpoint b.endpoint;

  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;

  schemes = [
    "tcp"
    "udp"
    "sctp"
    "unix"
  ];
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
    isUnix
    ;
  # `transport` / `endpoint` accessors declared inline to avoid
  # shadowing the imported modules of the same name.
  transport = su: su.transport;
  endpoint = su: su.endpoint;
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
  inherit schemes;
}
