/*
  libnet.bindUrl

  A bind address in URL form: `<scheme>://<bindpoint>`. The bind-side
  peer of `socketUrl` — a bounded composition of a socket scheme and a
  `bindpoint`, *not* a general URL parser (no userinfo, query, fragment,
  percent-encoding, or relative resolution; see docs/adr/0011).

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

  Schemes match case-insensitively and are emitted lowercase, and sort
  by name (sctp < tcp < udp < unix).

  Stored as the canonical scheme and the bindpoint, like every URL form;
  `transport` derives from the scheme:

    { _type = "bindUrl"; scheme = <"sctp" | "tcp" | "udp" | "unix">;
      bindpoint = <bindpoint>; }

  Invariant: `scheme == "unix"` iff `bindpoint` is a `unixSocket`. A
  Unix socket has no L4 transport.

  Example:
    libnet.bindUrl.parse "tcp://:8080"
    => { _type = "bindUrl"; scheme = "tcp"; bindpoint = <ipBindpoint>; }

    libnet.bindUrl.toString (libnet.bindUrl.parse "unix:///run/foo.sock")
    => "unix:///run/foo.sock"
*/
let
  errors = import ./internal/errors.nix;
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  transport = import ./transport.nix;
  bindpoint = import ./bindpoint.nix;
  socketUrl = import ./socket-url.nix;

  lowerAscii = dnsLabel.toLowerAscii;

  unixScheme = "unix";

  # The socket URL registry: a bind URL takes the same schemes.
  inherit (socketUrl) schemes;

  schemeHint = "expected tcp, udp, sctp, or unix";

  mk = schemeName: bindpointValue: {
    _type = "bindUrl";
    scheme = schemeName;
    bindpoint = bindpointValue;
  };

  # Check the bindUrl argument of `function`, throwing for any other kind.
  bindUrlOf = function: errors.expectKind "bindUrl.${function}" "bindUrl";

  parseError = detail: types.tryErr (errors.message "bindUrl.parse" detail);

  # ===== Parsing =====

  /*
    Parse a bind URL without throwing, for callers that want to report
    or recover from invalid input.

    `input`: `<scheme>://<bindpoint>` string; `tcp`, `udp`, and `sctp`
    take `[address]:port` or a port range, `unix` takes a socket path;
    the scheme is matched case-insensitively.

    Returns a tryResult: `{ success = true; value; }` with a bindUrl
    value, or `{ success = false; error; }` naming `bindUrl.parse`. An
    unknown scheme is reported before an invalid bind address.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else
      let
        parts = parsing.splitOn "://" input;
      in
      if builtins.length parts < 2 then
        parseError "missing '<scheme>://': \"${input}\""
      else
        let
          rawScheme = builtins.elemAt parts 0;
          schemeName = lowerAscii rawScheme;
          # Rejoin the remainder so a stray '://' inside a path is kept.
          rest = builtins.concatStringsSep "://" (builtins.tail parts);
        in
        if !(schemes ? ${schemeName}) then
          parseError "unknown scheme \"${rawScheme}\" (${schemeHint})"
        else
          let
            bindpointResult = bindpoint.tryParse rest;
            bindpointValue = bindpointResult.value;
          in
          if !bindpointResult.success then
            parseError (errors.detail "bindpoint.parse" bindpointResult.error)
          else if schemeName == unixScheme then
            if types.isUnixSocket bindpointValue then
              types.tryOk (mk schemeName bindpointValue)
            else
              parseError "'unix://' requires a socket path: \"${input}\""
          else if types.isUnixSocket bindpointValue then
            parseError "'${schemeName}://' requires [addr]:port, not a socket path: \"${input}\""
          else
            types.tryOk (mk schemeName bindpointValue);

  /*
    Parse a bind URL.

    `input`: `<scheme>://<bindpoint>` string; `tcp`, `udp`, and `sctp`
    take `[address]:port` or a port range, `unix` takes a socket path;
    the scheme is matched case-insensitively.

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
      checked = bindUrlOf "toString" bindUrl;
    in
    "${checked.scheme}://${bindpoint.toString checked.bindpoint}";

  # ===== Construction =====

  /*
    Build a bind URL from a scheme and an already-parsed bindpoint, as
    `parse` would.

    `schemeName`: `tcp`, `udp`, `sctp`, or `unix`, matched
    case-insensitively and stored lowercase.
    `bindpointValue`: a unixSocket value for `unix`, otherwise an
    ipBindpoint value.

    Returns a bindUrl value; throws on a non-string or unknown scheme, a
    non-bindpoint value, or a bindpoint that does not match the scheme.
  */
  make =
    schemeName: bindpointValue:
    let
      caller = "bindUrl.make";
      canonicalScheme = lowerAscii (errors.expectType caller "string" schemeName);
      checked = errors.expect caller "ipBindpoint or unixSocket value" bindpoint.is bindpointValue;
      expectedBindpoint =
        if canonicalScheme == unixScheme then "unixSocket value" else "ipBindpoint value";
    in
    if !(schemes ? ${canonicalScheme}) then
      errors.fail caller "unknown scheme \"${schemeName}\" (${schemeHint})"
    else if (canonicalScheme == unixScheme) != types.isUnixSocket checked then
      errors.fail caller "expected ${expectedBindpoint} for scheme \"${canonicalScheme}\", got ${errors.describe checked}"
    else
      mk canonicalScheme checked;

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
  isUnix = bindUrl: (bindUrlOf "isUnix" bindUrl).scheme == unixScheme;

  /*
    Check whether a bind URL's scheme is secure: its protocol encrypts
    the connection, per the scheme registry.

    `bindUrl`: bindUrl value.

    Returns false; no bind scheme encrypts.
  */
  isSecure = bindUrl: schemes.${(bindUrlOf "isSecure" bindUrl).scheme}.secure;

  # ===== Accessors =====

  /*
    Get the canonical scheme of a bind URL.

    `bindUrl`: bindUrl value.

    Returns "sctp", "tcp", "udp", or "unix".
  */
  scheme = bindUrl: (bindUrlOf "scheme" bindUrl).scheme;

  # ===== Comparison =====
  #
  # Sorted by scheme name (sctp < tcp < udp < unix), for determinism
  # only, then by bindpoint. Each ordering function passes its own name,
  # which its errors report.

  compareFor =
    function: a: b:
    let
      left = bindUrlOf function a;
      right = bindUrlOf function b;
    in
    if left.scheme < right.scheme then
      -1
    else if left.scheme > right.scheme then
      1
    else
      bindpoint.compare left.bindpoint right.bindpoint;

  /*
    Compare two bind URLs for equality.

    `a`, `b`: values to compare.

    Returns true when the type tags, schemes, and bindpoints match; false
    for any other value.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.bindUrl a b
    && a.scheme == b.scheme
    && bindpoint.eq a.bindpoint b.bindpoint;

  /*
    Order two bind URLs by scheme name (sctp < tcp < udp < unix), then
    by bindpoint.

    `a`, `b`: bindUrl values.

    Returns -1, 0, or 1 when `a` sorts before, equal to, or after `b`.
  */
  compare = compareFor "compare";

  /*
    Test whether `a` sorts strictly before `b`.

    `a`, `b`: bindUrl values.

    Returns a Boolean.
  */
  lt = a: b: compareFor "lt" a b == -1;

  /*
    Test whether `a` sorts before or equal to `b`.

    `a`, `b`: bindUrl values.

    Returns a Boolean.
  */
  le = a: b: compareFor "le" a b <= 0;

  /*
    Test whether `a` sorts strictly after `b`.

    `a`, `b`: bindUrl values.

    Returns a Boolean.
  */
  gt = a: b: compareFor "gt" a b == 1;

  /*
    Test whether `a` sorts after or equal to `b`.

    `a`, `b`: bindUrl values.

    Returns a Boolean.
  */
  ge = a: b: compareFor "ge" a b >= 0;

  /*
    Pick the lesser of two bind URLs.

    `a`, `b`: bindUrl values.

    Returns the one that sorts first; `a` when they are equal.
  */
  min = a: b: if compareFor "min" a b <= 0 then a else b;

  /*
    Pick the greater of two bind URLs.

    `a`, `b`: bindUrl values.

    Returns the one that sorts last; `a` when they are equal.
  */
  max = a: b: if compareFor "max" a b >= 0 then a else b;
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

  # Defined here rather than in `let`, where `transport` and `bindpoint` name
  # the imported modules.
  /*
    Get the transport of a bind URL, derived from its scheme.

    `bindUrl`: bindUrl value.

    Returns the transport value, or null for the `unix` scheme.
  */
  transport =
    bindUrl:
    let
      transportName = schemes.${(bindUrlOf "transport" bindUrl).scheme}.transport;
    in
    if transportName == null then null else transport.parse transportName;

  /*
    Get the bindpoint of a bind URL.

    `bindUrl`: bindUrl value.

    Returns the bindpoint value (ipBindpoint or unixSocket).
  */
  bindpoint = bindUrl: (bindUrlOf "bindpoint" bindUrl).bindpoint;
}
