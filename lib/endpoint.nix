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

  The three members are heterogeneous — `ipEndpoint` has `address` +
  `port`, `dnsEndpoint` has `name` + `port`, `unixSocket` holds a path —
  so this union exposes predicates + `toString` + comparison rather
  than uniform accessors. Branch with `isIpEndpoint` / `isDnsEndpoint`
  / `isUnixSocket` and use the member module's accessors.

  Example:
    libnet.endpoint.parse "192.0.2.1:80"      # tagged ipEndpoint
    libnet.endpoint.parse "pool.ntp.org:123"   # tagged dnsEndpoint
    libnet.endpoint.parse "/run/foo.sock"      # tagged unixSocket
*/
let
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;
  ipEndpoint = import ./ip-endpoint.nix;
  dnsEndpoint = import ./dns-endpoint.nix;
  unixSocket = import ./unix-socket.nix;

  isMember = value: types.isIpEndpoint value || types.isDnsEndpoint value || types.isUnixSocket value;

  # Check the endpoint argument of `function`, throwing for a value of
  # any other kind.
  endpointArgument =
    function:
    errors.expect "endpoint.${function}" "ipEndpoint, dnsEndpoint or unixSocket value" isMember;

  # ===== Parsing =====

  /*
    Parse any connection target, classifying it by shape: the detail
    parser of the parsing suite.

    `input`: a unix socket path (leading `/` or `@`), `"<ip>:<port>"`,
    `"[<ipv6>]:<port>"`, or `"<name>:<port>"`. A leading `/` or `@`
    cannot start an address:port form, so it marks a unix socket. IP
    forms are tried before names so a literal address yields a full
    ipEndpoint rather than a dnsEndpoint.

    Returns a tryResult holding an ipEndpoint, dnsEndpoint, or unixSocket
    value; on failure, `error` is the detail of the member whose shape the
    text has.
  */
  tryParseDetail =
    input:
    if parsing.startsWith "/" input || parsing.startsWith "@" input then
      unixSocket.tryParseDetail input
    else
      let
        ipEndpointResult = ipEndpoint.tryParseDetail input;
      in
      if ipEndpointResult.success then
        ipEndpointResult
      else
        let
          dnsEndpointResult = dnsEndpoint.tryParseDetail input;
        in
        if dnsEndpointResult.success then
          dnsEndpointResult
        # Keep the detail of the member whose shape the text has: an IP
        # endpoint is bracketed, holds several colons or has an IPv4-shaped
        # host, and anything else reads as a DNS endpoint.
        else if
          parsing.startsWith "[" input
          || parsing.countOccurrences ":" input > 1
          || parsing.isDottedDigits (builtins.head (parsing.splitOn ":" input))
        then
          ipEndpointResult
        else
          dnsEndpointResult;

  parsers = parsing.suite "endpoint" tryParseDetail;

  /*
    Render any endpoint member in its canonical text form.

    `endpoint`: ipEndpoint, dnsEndpoint, or unixSocket value.

    Returns the member module's `toString` output; throws for other
    values.
  */
  toString =
    endpoint:
    let
      checked = endpointArgument "toString" endpoint;
    in
    if types.isIpEndpoint checked then
      ipEndpoint.toString checked
    else if types.isDnsEndpoint checked then
      dnsEndpoint.toString checked
    else
      unixSocket.toString checked;

  # ===== Predicates =====

  /*
    Test whether a value is an ipEndpoint, dnsEndpoint, or unixSocket.

    `value`: any value.

    Returns a Boolean.
  */
  is = isMember;

  /*
    Test whether a value is an ipEndpoint.

    `value`: any value.

    Returns a Boolean.
  */
  isIpEndpoint = value: types.isIpEndpoint value;

  /*
    Test whether a value is a dnsEndpoint.

    `value`: any value.

    Returns a Boolean.
  */
  isDnsEndpoint = value: types.isDnsEndpoint value;

  /*
    Test whether a value is a unixSocket.

    `value`: any value.

    Returns a Boolean.
  */
  isUnixSocket = value: types.isUnixSocket value;

  # ===== Comparison =====
  #
  # Cross-kind order: ipEndpoint < dnsEndpoint < unixSocket. Within a
  # kind, delegates to that kind's comparator. Each ordering function
  # passes its own name, which its errors report.

  rank =
    value:
    if types.isIpEndpoint value then
      0
    else if types.isDnsEndpoint value then
      1
    else
      2;

  compareFor =
    function: a: b:
    comparison.byRank rank (
      left: right:
      if types.isIpEndpoint left then
        ipEndpoint.compare left right
      else if types.isDnsEndpoint left then
        dnsEndpoint.compare left right
      else
        unixSocket.compare left right
    ) (endpointArgument function a) (endpointArgument function b);

  ordering = comparison.suite compareFor;

  /*
    Test two endpoints for equality using their member module's `eq`.

    `a`, `b`: values to compare.

    Returns a Boolean; false when the two are different kinds.
  */
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
in
{
  inherit
    eq
    is
    isDnsEndpoint
    isIpEndpoint
    isUnixSocket
    toString
    tryParseDetail
    ;
  inherit (parsers)
    isValid
    parse
    tryParse
    ;
  inherit (ordering)
    compare
    ge
    gt
    le
    lt
    max
    min
    ;
}
