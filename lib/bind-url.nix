/*
  libnet.bindUrl

  A bind address in URL form: `<scheme>://<bindpoint>`. The bind-side
  peer of `socketUrl` — a bounded composition of `transport` and
  `bindpoint`, *not* a general URL parser (no userinfo, query, fragment,
  percent-encoding, or relative resolution; see `url` in SPEC Non-Goals).

  Where `socketUrl` tags a connect `endpoint` (concrete host, single
  port), `bindUrl` tags a `bindpoint` — so it keeps the bind-side
  affordances `endpoint` lacks: an optional/wildcard address (`:8080`)
  and port ranges (`8000-8100`).

  Schemes:
  - `tcp` / `udp` / `sctp` → an IP bindpoint follows (optional address;
    single port or range): `tcp://:8080`, `udp://0.0.0.0:53`,
    `tcp://[::]:8000-8100`.
  - `unix` → a socket path follows (`unix:///run/foo.sock`,
    `unix://@abstract`); no port.

  Stored as the underlying `transport` + `bindpoint` pair:

    { _type = "bindUrl"; transport = <transport | null>; bindpoint = <bindpoint>; }

  Invariant: `transport == null` iff `bindpoint` is a `unixSocket` — a
  Unix socket has no L4 transport, its scheme is the literal `unix`.

  Example:
    libnet.bindUrl.parse "tcp://:8080"
    => { _type = "bindUrl"; transport = <tcp>; bindpoint = <ipBindpoint>; }

    libnet.bindUrl.toString (libnet.bindUrl.parse "unix:///run/foo.sock")
    => "unix:///run/foo.sock"
*/
let
  types = import ./internal/types.nix;
  parse' = import ./internal/parse.nix;
  transport = import ./transport.nix;
  bindpoint = import ./bindpoint.nix;

  unixScheme = "unix";

  mk = tr: bp: {
    _type = "bindUrl";
    transport = tr;
    bindpoint = bp;
  };

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.bindUrl.parse: input must be a string"
    else
      let
        parts = parse'.splitOn "://" s;
      in
      if builtins.length parts < 2 then
        types.tryErr "libnet.bindUrl.parse: missing '<scheme>://': \"${s}\""
      else
        let
          scheme = builtins.elemAt parts 0;
          # Rejoin the remainder so a stray '://' inside a path is kept.
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
          bpRes = bindpoint.tryParse rest;
        in
        if !bpRes.success then
          types.tryErr "libnet.bindUrl.parse: invalid bind address in \"${s}\""
        else
          let
            bp = bpRes.value;
          in
          if scheme == unixScheme then
            if types.isUnixSocket bp then
              types.tryOk (mk null bp)
            else
              types.tryErr "libnet.bindUrl.parse: 'unix://' requires a socket path: \"${s}\""
          else
            let
              trRes = transport.tryParse scheme;
            in
            if !trRes.success then
              types.tryErr "libnet.bindUrl.parse: unknown scheme \"${scheme}\" (expected tcp, udp, sctp, or unix)"
            else if types.isUnixSocket bp then
              types.tryErr "libnet.bindUrl.parse: '${scheme}://' requires [addr]:port, not a socket path: \"${s}\""
            else
              types.tryOk (mk trRes.value bp);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    bu:
    let
      scheme = if bu.transport == null then unixScheme else transport.toString bu.transport;
    in
    "${scheme}://${bindpoint.toString bu.bindpoint}";

  # ===== Construction =====

  make =
    tr: bp:
    if !(bindpoint.is bp) then
      builtins.throw "libnet.bindUrl.make: expected a bindpoint value"
    else if types.isUnixSocket bp then
      (
        if tr != null then
          builtins.throw "libnet.bindUrl.make: a unix socket takes no transport (pass null)"
        else
          mk null bp
      )
    else if !(types.isTransport tr) then
      builtins.throw "libnet.bindUrl.make: expected a transport value for an IP bindpoint"
    else
      mk tr bp;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isBindUrl;
  isUnix = bu: bu.transport == null;

  # ===== Comparison =====
  #
  # `transport` itself has no canonical order, so binds sort by a fixed
  # scheme rank (tcp < udp < sctp < unix), then by bindpoint.

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

  eq = a: b: transportEq a.transport b.transport && bindpoint.eq a.bindpoint b.bindpoint;

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
      bindpoint.compare a.bindpoint b.bindpoint;

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
  # `transport` / `bindpoint` accessors declared inline to avoid
  # shadowing the imported modules of the same name.
  transport = bu: bu.transport;
  bindpoint = bu: bu.bindpoint;
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
