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
  errors = import ./internal/errors.nix;
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;
  ipEndpoint = import ./ip-endpoint.nix;
  dnsEndpoint = import ./dns-endpoint.nix;
  unixSocket = import ./unix-socket.nix;

  isMember = value: types.isIpEndpoint value || types.isDnsEndpoint value || types.isUnixSocket value;

  # Check the endpoint argument of `function`, throwing for a value of
  # any other kind.
  memberOf =
    function:
    errors.expect "endpoint.${function}" "ipEndpoint, dnsEndpoint or unixSocket value" isMember;

  parseError = detail: types.tryErr (errors.message "endpoint.parse" detail);

  # ===== Parsing =====

  /*
    Parse any connection target without throwing, classifying it by shape.

    `input`: a unix socket path (leading `/` or `@`), `"<ip>:<port>"`,
    `"[<ipv6>]:<port>"`, or `"<name>:<port>"`. A leading `/` or `@`
    cannot start an address:port form, so it marks a unix socket. IP
    forms are tried before names so a literal address yields a full
    ipEndpoint rather than a dnsEndpoint.

    Returns a tryResult whose value is an ipEndpoint, dnsEndpoint, or
    unixSocket; on failure, `error` names `endpoint.parse` and explains
    why no member matched.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else if parsing.startsWith "/" input || parsing.startsWith "@" input then
      let
        result = unixSocket.tryParse input;
      in
      if result.success then result else parseError (errors.detail "unixSocket.parse" result.error)
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
          parseError "\"${input}\" is not a valid IP, name, or unix-socket endpoint";

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
    let
      checked = memberOf "toString" endpoint;
    in
    if types.isIpEndpoint checked then
      ipEndpoint.toString checked
    else if types.isDnsEndpoint checked then
      dnsEndpoint.toString checked
    else
      unixSocket.toString checked;

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
    let
      left = memberOf function a;
      right = memberOf function b;
      rankA = rank left;
      rankB = rank right;
    in
    if rankA < rankB then
      -1
    else if rankA > rankB then
      1
    else if rankA == 0 then
      ipEndpoint.compare left right
    else if rankA == 1 then
      dnsEndpoint.compare left right
    else
      unixSocket.compare left right;

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
  compare = compareFor "compare";

  /*
    Test whether `a` orders strictly before `b` under `compare`.

    `a`, `b`: endpoint member values.

    Returns a Boolean.
  */
  lt = a: b: compareFor "lt" a b == -1;

  /*
    Test whether `a` orders before or equal to `b` under `compare`.

    `a`, `b`: endpoint member values.

    Returns a Boolean.
  */
  le = a: b: compareFor "le" a b <= 0;

  /*
    Test whether `a` orders strictly after `b` under `compare`.

    `a`, `b`: endpoint member values.

    Returns a Boolean.
  */
  gt = a: b: compareFor "gt" a b == 1;

  /*
    Test whether `a` orders after or equal to `b` under `compare`.

    `a`, `b`: endpoint member values.

    Returns a Boolean.
  */
  ge = a: b: compareFor "ge" a b >= 0;

  /*
    Pick the lesser of two endpoints under `compare`.

    `a`, `b`: endpoint member values.

    Returns `a` when they order equal, otherwise the lesser value.
  */
  min = a: b: if compareFor "min" a b <= 0 then a else b;

  /*
    Pick the greater of two endpoints under `compare`.

    `a`, `b`: endpoint member values.

    Returns `a` when they order equal, otherwise the greater value.
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
