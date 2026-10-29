/*
  libnet.socketUrl

  A socket address in URL form: `<scheme>://<endpoint>`. A bounded
  composition of `transport` and `endpoint`, *not* a general URL parser
  (no userinfo, query, fragment, percent-encoding, or relative
  resolution; see docs/adr/0011). For the TLS-secured peer
  (`tls`/`ssl`/`dtls`/`quic`), see `secureSocketUrl`.

  Schemes:
  - `tcp` / `udp` / `sctp` → an IP or DNS endpoint follows
    (`tcp://1.2.3.4:80`, `udp://[::]:53`, `sctp://pool.ntp.org:9999`).
  - `unix` → a socket path follows (`unix:///run/foo.sock`,
    `unix://@abstract`); no port.

  Schemes match case-insensitively and are emitted lowercase, and sort
  by name (sctp < tcp < udp < unix).

  Stored as the underlying `transport` + `endpoint` pair:

    { _type = "socketUrl"; transport = <transport | null>;
      endpoint = <endpoint>; }

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
  parsing = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  transport = import ./transport.nix;
  endpoint = import ./endpoint.nix;

  lowerAscii = dnsLabel.toLowerAscii;

  unixScheme = "unix";

  # Closed registry of socket schemes, `scheme -> { transport; secure; }`.
  # `unix` has no transport; no scheme is TLS-secured.
  schemes = {
    sctp = {
      transport = "sctp";
      secure = false;
    };
    tcp = {
      transport = "tcp";
      secure = false;
    };
    udp = {
      transport = "udp";
      secure = false;
    };
    unix = {
      transport = null;
      secure = false;
    };
  };

  mk = transportValue: endpointValue: {
    _type = "socketUrl";
    transport = transportValue;
    endpoint = endpointValue;
  };

  # ===== Parsing =====

  /*
    Parse a socket URL without throwing, for callers that want to report
    or recover from invalid input.

    `input`: `<scheme>://<endpoint>` string; `tcp`, `udp`, and `sctp`
    take `host:port`, `unix` takes a socket path;
    the scheme is matched case-insensitively.

    Returns a tryResult: `{ success = true; value; }` with a socketUrl
    value, or `{ success = false; error; }` describing the problem.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.socketUrl.parse: input must be a string"
    else
      let
        parts = parsing.splitOn "://" input;
      in
      if builtins.length parts < 2 then
        types.tryErr "libnet.socketUrl.parse: missing '<scheme>://': \"${input}\""
      else
        let
          rawScheme = builtins.elemAt parts 0;
          lowerScheme = lowerAscii rawScheme;
          # Rejoin the remainder so a stray '://' inside a path is kept.
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
          endpointResult = endpoint.tryParse rest;
        in
        if !endpointResult.success then
          types.tryErr "libnet.socketUrl.parse: invalid address in \"${input}\""
        else if !(schemes ? ${lowerScheme}) then
          types.tryErr "libnet.socketUrl.parse: unknown scheme \"${rawScheme}\" (expected tcp, udp, sctp, or unix)"
        else
          let
            endpointValue = endpointResult.value;
          in
          if lowerScheme == unixScheme then
            if types.isUnixSocket endpointValue then
              types.tryOk (mk null endpointValue)
            else
              types.tryErr "libnet.socketUrl.parse: 'unix://' requires a socket path: \"${input}\""
          else if types.isUnixSocket endpointValue then
            types.tryErr "libnet.socketUrl.parse: '${lowerScheme}://' requires host:port, not a socket path: \"${input}\""
          else
            types.tryOk (mk (transport.parse schemes.${lowerScheme}.transport) endpointValue);

  /*
    Parse a socket URL.

    `input`: `<scheme>://<endpoint>` string; `tcp`, `udp`, and `sctp`
    take `host:port`, `unix` takes a socket path;
    the scheme is matched case-insensitively.

    Returns a socketUrl value; throws on malformed input, an unknown
    scheme, or a scheme that does not match the address kind.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a socket URL in canonical text form.

    `socketUrl`: socketUrl value.

    Returns `<scheme>://<endpoint>`, such as "tcp://1.2.3.4:80" or
    "unix:///run/foo.sock".
  */
  toString = socketUrl: "${scheme socketUrl}://${endpoint.toString socketUrl.endpoint}";

  # ===== Construction =====

  /*
    Build a socket URL from already-parsed parts.

    `transportValue`: transport value, or null for a Unix socket.
    `endpointValue`: endpoint value (ipEndpoint, dnsEndpoint, or
    unixSocket).

    Returns a socketUrl value; throws when `endpointValue` is not an
    endpoint, or when the transport is not null exactly for a Unix
    socket.
  */
  make =
    transportValue: endpointValue:
    if !(endpoint.is endpointValue) then
      throw "libnet.socketUrl.make: expected an endpoint value"
    else if types.isUnixSocket endpointValue then
      (
        if transportValue != null then
          throw "libnet.socketUrl.make: a unix socket takes no transport (pass null)"
        else
          mk null endpointValue
      )
    else if !(types.isTransport transportValue) then
      throw "libnet.socketUrl.make: expected a transport value for an IP/DNS endpoint"
    else
      mk transportValue endpointValue;

  # ===== Predicates =====

  /*
    Check whether a string parses as a socket URL, without throwing.

    `input`: value to check.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a socketUrl value.

    `value`: any value; non-attrsets are accepted and yield false.

    Returns true for an attrset tagged `_type = "socketUrl"`, false
    otherwise; other fields are not checked.
  */
  is = value: types.isSocketUrl value;

  /*
    Check whether a socket URL addresses a Unix socket.

    `socketUrl`: socketUrl value.

    Returns true for the `unix` scheme.
  */
  isUnix = socketUrl: socketUrl.transport == null;

  /*
    Check whether a socket URL's scheme implies TLS, per the scheme
    registry.

    `socketUrl`: socketUrl value.

    Returns false; no socket scheme is TLS-secured (see `secureSocketUrl`).
  */
  isSecure = socketUrl: schemes.${scheme socketUrl}.secure;

  # ===== Accessors =====

  /*
    Get the canonical scheme of a socket URL.

    `socketUrl`: socketUrl value.

    Returns "sctp", "tcp", "udp", or "unix".
  */
  scheme =
    socketUrl:
    if socketUrl.transport == null then unixScheme else transport.toString socketUrl.transport;

  # ===== Comparison =====
  #
  # Sorted by scheme name (sctp < tcp < udp < unix), for determinism
  # only, then by endpoint.

  /*
    Compare two socket URLs for equality.

    `a`, `b`: socketUrl values.

    Returns true when the type tags, schemes, and endpoints match.
  */
  eq = a: b: types.hasSameTag a b && scheme a == scheme b && endpoint.eq a.endpoint b.endpoint;

  /*
    Order two socket URLs by scheme name (sctp < tcp < udp < unix), then
    by endpoint.

    `a`, `b`: socketUrl values.

    Returns -1, 0, or 1 when `a` sorts before, equal to, or after `b`.
  */
  compare =
    a: b:
    let
      schemeA = scheme a;
      schemeB = scheme b;
    in
    if schemeA < schemeB then
      -1
    else if schemeA > schemeB then
      1
    else
      endpoint.compare a.endpoint b.endpoint;

  /*
    Test whether `a` sorts strictly before `b`.

    `a`, `b`: socketUrl values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` sorts before or equal to `b`.

    `a`, `b`: socketUrl values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` sorts strictly after `b`.

    `a`, `b`: socketUrl values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` sorts after or equal to `b`.

    `a`, `b`: socketUrl values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two socket URLs.

    `a`, `b`: socketUrl values.

    Returns the one that sorts first; `a` when they are equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two socket URLs.

    `a`, `b`: socketUrl values.

    Returns the one that sorts last; `a` when they are equal.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    compare
    eq
    ge
    gt
    is
    isSecure
    isUnix
    isValid
    le
    lt
    make
    max
    min
    parse
    scheme
    schemes
    toString
    tryParse
    ;

  # Defined here rather than in `let`, where `transport` and `endpoint` name
  # the imported modules.
  /*
    Get the transport of a socket URL.

    `socketUrl`: socketUrl value.

    Returns the transport value, or null for a Unix socket.
  */
  transport = socketUrl: socketUrl.transport;

  /*
    Get the endpoint of a socket URL.

    `socketUrl`: socketUrl value.

    Returns the endpoint value (ipEndpoint, dnsEndpoint, or unixSocket).
  */
  endpoint = socketUrl: socketUrl.endpoint;
}
