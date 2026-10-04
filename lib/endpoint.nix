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
  parsing = import ./internal/parse.nix;
  ipEndpoint = import ./ip-endpoint.nix;
  dnsEndpoint = import ./dns-endpoint.nix;
  unixSocket = import ./unix-socket.nix;

  # ===== Parsing =====

  /*
    Parse any connection target without throwing, classifying it by shape.

    `input`: a unix socket path (leading `/` or `@`), `"<ip>:<port>"`,
    `"[<ipv6>]:<port>"`, or `"<name>:<port>"`. A leading `/` or `@`
    cannot start an address:port form, so it marks a unix socket. IP
    forms are tried before names so a literal address yields a full
    ipEndpoint rather than a dnsEndpoint.

    Returns a tryResult whose value is an ipEndpoint, dnsEndpoint, or
    unixSocket; on failure, `error` explains why no member matched.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.endpoint.parse: input must be a string"
    else if parsing.startsWith "/" input || parsing.startsWith "@" input then
      unixSocket.tryParse input
    else
      let
        ipEndpointResult = ipEndpoint.tryParse input;
      in
      if ipEndpointResult.success then
        ipEndpointResult
      else
        let
          dnsEndpointResult = dnsEndpoint.tryParse input;
        in
        if dnsEndpointResult.success then
          dnsEndpointResult
        else
          types.tryErr "libnet.endpoint.parse: \"${input}\" is not a valid IP, name, or unix-socket endpoint";

  /*
    Parse any connection target, classifying it by shape as `tryParse`
    does.

    `input`: a unix socket path, `"<ip>:<port>"`, `"[<ipv6>]:<port>"`,
    or `"<name>:<port>"`.

    Returns an ipEndpoint, dnsEndpoint, or unixSocket value; throws if
    no member matches.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render any endpoint member in its canonical text form.

    `endpoint`: ipEndpoint, dnsEndpoint, or unixSocket value.

    Returns the member module's `toString` output; throws for other
    values.
  */
  toString =
    endpoint:
    if types.isIpEndpoint endpoint then
      ipEndpoint.toString endpoint
    else if types.isDnsEndpoint endpoint then
      dnsEndpoint.toString endpoint
    else if types.isUnixSocket endpoint then
      unixSocket.toString endpoint
    else
      throw "libnet.endpoint.toString: expected ipEndpoint, dnsEndpoint, or unixSocket value";

  # ===== Predicates =====

  /*
    Test whether a string parses as any endpoint member.

    `input`: value to test; non-strings yield false.

    Returns a Boolean.
  */
  isValid = input: (tryParse input).success;

  /*
    Test whether a value is an ipEndpoint, dnsEndpoint, or unixSocket.

    `value`: any value.

    Returns a Boolean.
  */
  is = value: types.isIpEndpoint value || types.isDnsEndpoint value || types.isUnixSocket value;

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
  # kind, delegates to that kind's comparator.

  rank =
    value:
    if types.isIpEndpoint value then
      0
    else if types.isDnsEndpoint value then
      1
    else if types.isUnixSocket value then
      2
    else
      throw "libnet.endpoint.compare: expected ipEndpoint, dnsEndpoint, or unixSocket value";

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

  /*
    Order two endpoints by kind (ipEndpoint < dnsEndpoint < unixSocket),
    then by the member module's `compare`.

    `a`, `b`: endpoint member values.

    Returns `-1`, `0`, or `1`; throws if either is not an endpoint
    member.
  */
  compare =
    a: b:
    let
      rankA = rank a;
      rankB = rank b;
    in
    if rankA < rankB then
      -1
    else if rankA > rankB then
      1
    else if rankA == 0 then
      ipEndpoint.compare a b
    else if rankA == 1 then
      dnsEndpoint.compare a b
    else
      unixSocket.compare a b;

  /*
    Test whether `a` orders strictly before `b` under `compare`.

    `a`, `b`: endpoint member values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` orders before or equal to `b` under `compare`.

    `a`, `b`: endpoint member values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` orders strictly after `b` under `compare`.

    `a`, `b`: endpoint member values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` orders after or equal to `b` under `compare`.

    `a`, `b`: endpoint member values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two endpoints under `compare`.

    `a`, `b`: endpoint member values.

    Returns `a` when they order equal, otherwise the lesser value.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two endpoints under `compare`.

    `a`, `b`: endpoint member values.

    Returns `a` when they order equal, otherwise the greater value.
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
    isDnsEndpoint
    isIpEndpoint
    isUnixSocket
    isValid
    le
    lt
    max
    min
    parse
    toString
    tryParse
    ;
}
