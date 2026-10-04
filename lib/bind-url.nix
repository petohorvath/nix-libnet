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

    { _type = "bindUrl"; transport = <transport | null>;
      bindpoint = <bindpoint>; }

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
  parsing = import ./internal/parse.nix;
  transport = import ./transport.nix;
  bindpoint = import ./bindpoint.nix;

  unixScheme = "unix";

  mk = transportValue: bindpointValue: {
    _type = "bindUrl";
    transport = transportValue;
    bindpoint = bindpointValue;
  };

  # ===== Parsing =====

  /*
    Parse a bind URL without throwing, for callers that want to report
    or recover from invalid input.

    `input`: `<scheme>://<bindpoint>` string; `tcp`, `udp`, and `sctp`
    take `[address]:port` or a port range, `unix` takes a socket path.

    Returns a tryResult: `{ success = true; value; }` with a bindUrl
    value, or `{ success = false; error; }` describing the problem.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.bindUrl.parse: input must be a string"
    else
      let
        parts = parsing.splitOn "://" input;
      in
      if builtins.length parts < 2 then
        types.tryErr "libnet.bindUrl.parse: missing '<scheme>://': \"${input}\""
      else
        let
          scheme = builtins.elemAt parts 0;
          # Rejoin the remainder so a stray '://' inside a path is kept.
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
          bindpointResult = bindpoint.tryParse rest;
        in
        if !bindpointResult.success then
          types.tryErr "libnet.bindUrl.parse: invalid bind address in \"${input}\""
        else
          let
            bindpointValue = bindpointResult.value;
          in
          if scheme == unixScheme then
            if types.isUnixSocket bindpointValue then
              types.tryOk (mk null bindpointValue)
            else
              types.tryErr "libnet.bindUrl.parse: 'unix://' requires a socket path: \"${input}\""
          else
            let
              transportResult = transport.tryParse scheme;
            in
            if !transportResult.success then
              types.tryErr "libnet.bindUrl.parse: unknown scheme \"${scheme}\" (expected tcp, udp, sctp, or unix)"
            else if types.isUnixSocket bindpointValue then
              types.tryErr "libnet.bindUrl.parse: '${scheme}://' requires [addr]:port, not a socket path: \"${input}\""
            else
              types.tryOk (mk transportResult.value bindpointValue);

  /*
    Parse a bind URL.

    `input`: `<scheme>://<bindpoint>` string; `tcp`, `udp`, and `sctp`
    take `[address]:port` or a port range, `unix` takes a socket path.

    Returns a bindUrl value; throws on malformed input, an unknown
    scheme, or a scheme that does not match the address kind.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a bind URL in canonical text form.

    `bindUrl`: bindUrl value.

    Returns `<scheme>://<bindpoint>`, such as "tcp://:8080" or
    "unix:///run/foo.sock".
  */
  toString =
    bindUrl:
    let
      scheme = if bindUrl.transport == null then unixScheme else transport.toString bindUrl.transport;
    in
    "${scheme}://${bindpoint.toString bindUrl.bindpoint}";

  # ===== Construction =====

  /*
    Build a bind URL from already-parsed parts.

    `transportValue`: transport value, or null for a Unix socket.
    `bindpointValue`: bindpoint value (ipBindpoint or unixSocket).

    Returns a bindUrl value; throws when `bindpointValue` is not a
    bindpoint, or when the transport is not null exactly for a Unix
    socket.
  */
  make =
    transportValue: bindpointValue:
    if !(bindpoint.is bindpointValue) then
      throw "libnet.bindUrl.make: expected a bindpoint value"
    else if types.isUnixSocket bindpointValue then
      (
        if transportValue != null then
          throw "libnet.bindUrl.make: a unix socket takes no transport (pass null)"
        else
          mk null bindpointValue
      )
    else if !(types.isTransport transportValue) then
      throw "libnet.bindUrl.make: expected a transport value for an IP bindpoint"
    else
      mk transportValue bindpointValue;

  # ===== Predicates =====

  /*
    Check whether a string parses as a bind URL, without throwing.

    `input`: value to check.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a bindUrl value.

    `value`: any value; non-attrsets are accepted and yield false.

    Returns true for an attrset tagged `_type = "bindUrl"`, false
    otherwise; other fields are not checked.
  */
  is = value: types.isBindUrl value;

  /*
    Check whether a bind URL addresses a Unix socket.

    `bindUrl`: bindUrl value.

    Returns true for the `unix` scheme.
  */
  isUnix = bindUrl: bindUrl.transport == null;

  # ===== Accessors =====

  # ===== Comparison =====
  #
  # `transport` itself has no canonical order, so binds sort by a fixed
  # scheme rank (tcp < udp < sctp < unix), then by bindpoint.

  schemeRank =
    transportValue:
    if transportValue == null then
      3
    else if transport.isTcp transportValue then
      0
    else if transport.isUdp transportValue then
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

  /*
    Compare two bind URLs for equality.

    `a`, `b`: bindUrl values.

    Returns true when the type tags, transports, and bindpoints match.
  */
  eq =
    a: b:
    a._type == b._type && transportEq a.transport b.transport && bindpoint.eq a.bindpoint b.bindpoint;

  /*
    Order two bind URLs by scheme (tcp < udp < sctp < unix), then by
    bindpoint.

    `a`, `b`: bindUrl values.

    Returns -1, 0, or 1 when `a` sorts before, equal to, or after `b`.
  */
  compare =
    a: b:
    let
      rankA = schemeRank a.transport;
      rankB = schemeRank b.transport;
    in
    if rankA < rankB then
      -1
    else if rankA > rankB then
      1
    else
      bindpoint.compare a.bindpoint b.bindpoint;

  /*
    Test whether `a` sorts strictly before `b`.

    `a`, `b`: bindUrl values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` sorts before or equal to `b`.

    `a`, `b`: bindUrl values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` sorts strictly after `b`.

    `a`, `b`: bindUrl values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` sorts after or equal to `b`.

    `a`, `b`: bindUrl values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two bind URLs.

    `a`, `b`: bindUrl values.

    Returns the one that sorts first; `a` when they are equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two bind URLs.

    `a`, `b`: bindUrl values.

    Returns the one that sorts last; `a` when they are equal.
  */
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
    compare
    eq
    ge
    gt
    is
    isUnix
    isValid
    le
    lt
    make
    max
    min
    parse
    schemes
    toString
    tryParse
    ;

  # Defined here rather than in `let`, where `transport` and `bindpoint` name
  # the imported modules.
  /*
    Get the transport of a bind URL.

    `bindUrl`: bindUrl value.

    Returns the transport value, or null for a Unix socket.
  */
  transport = bindUrl: bindUrl.transport;

  /*
    Get the bindpoint of a bind URL.

    `bindUrl`: bindUrl value.

    Returns the bindpoint value (ipBindpoint or unixSocket).
  */
  bindpoint = bindUrl: bindUrl.bindpoint;
}
