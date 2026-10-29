/*
  libnet.dnsEndpoint

  A DNS name (hostname or domain) paired with a port — the name-only
  counterpart to libnet.ipEndpoint. The name is a `dnsName`, so IP
  literals and names that read as an IPv4 address are rejected (use
  `ipEndpoint`, or the `endpoint` union, for addresses).

  No IP-classification predicates (isLoopback, isGlobal, toArpa, …): a
  name has no resolved address until DNS runs, and libnet does no
  resolution.

  Example:
    libnet.dnsEndpoint.parse "pool.ntp.org:123"
    => { _type = "dnsEndpoint"; name = <domain>; port = <port 123>; }

    libnet.dnsEndpoint.parse "nas:22"
    => { _type = "dnsEndpoint"; name = <hostname>; port = <port 22>; }
*/
let
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  dnsName = import ./dns-name.nix;
  port = import ./port.nix;

  mk = nameValue: portValue: {
    _type = "dnsEndpoint";
    name = nameValue;
    port = portValue;
  };

  # Check the endpoint argument of `function`, throwing for any other kind.
  endpointOf = function: endpoint: errors.expectKind "dnsEndpoint.${function}" "dnsEndpoint" endpoint;

  parseError = detail: types.tryErr (errors.message "dnsEndpoint.parse" detail);

  # ===== Parsing =====

  /*
    Parse a DNS endpoint without throwing, for validating untrusted text.

    `input`: `"<name>:<port>"` with exactly one `:` (DNS names contain no
    colons). The bracketed form is rejected: brackets denote an IPv6
    literal, which is an IP, not a name.

    Returns a tryResult: `{ success = true; value; }` with a dnsEndpoint,
    or `{ success = false; error; }` for non-strings and malformed input.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else if parsing.startsWith "[" input then
      parseError "bracketed form is for IPv6; a dnsEndpoint holds a DNS name: \"${input}\""
    else if parsing.countOccurrences ":" input != 1 then
      parseError "expected exactly one ':' (name:port): \"${input}\""
    else
      let
        parts = parsing.splitOn ":" input;
        nameString = builtins.elemAt parts 0;
        portString = builtins.elemAt parts 1;
        nameResult = dnsName.tryParse nameString;
        portResult = port.tryParse portString;
      in
      if !nameResult.success then
        parseError (errors.detail "dnsName.parse" nameResult.error)
      else if !portResult.success then
        parseError "invalid port in \"${input}\""
      else
        types.tryOk (mk nameResult.value portResult.value);

  /*
    Parse a DNS endpoint from its text form.

    `input`: `"<name>:<port>"` with exactly one `:` and no brackets.

    Returns a dnsEndpoint value; throws on IP literals, an invalid name,
    or an invalid port.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a DNS endpoint as text.

    `endpoint`: dnsEndpoint value.

    Returns `"<name>:<port>"`, with the name in lowercase.
  */
  toString =
    endpoint:
    let
      checked = endpointOf "toString" endpoint;
    in
    "${dnsName.toString checked.name}:${port.toString checked.port}";

  /*
    Combine an already-parsed DNS name and port into an endpoint.

    `nameValue`: hostname or domain value.
    `portValue`: port value.

    Returns a dnsEndpoint value; throws if either argument has the wrong
    kind, or if the name is not a valid DNS name, such as the hostname
    `1234`, which reads as an IPv4 address.
  */
  make =
    nameValue: portValue:
    let
      caller = "dnsEndpoint.make";
      # Recheck the name against `dnsName`'s full rule, since a hostname
      # value may be numeric, so that `make` builds only what `parse`
      # accepts.
      nameResult = dnsName.tryParse (
        dnsName.toString (errors.expect caller "hostname or domain value" dnsName.is nameValue)
      );
    in
    if nameResult.success then
      mk nameResult.value (errors.expectKind caller "port" portValue)
    else
      errors.fail caller (errors.detail "dnsName.parse" nameResult.error);

  # ===== Predicates =====

  /*
    Test whether a string parses as a DNS endpoint.

    `input`: value to test; non-strings yield false.

    Returns a Boolean.
  */
  isValid = input: (tryParse input).success;

  /*
    Test whether a value is a dnsEndpoint.

    `value`: any value.

    Returns a Boolean.
  */
  is = value: types.isDnsEndpoint value;

  /*
    Test whether the endpoint's name is a single-label hostname.

    `endpoint`: dnsEndpoint value.

    Returns a Boolean.
  */
  isHostname = endpoint: types.isHostname (endpointOf "isHostname" endpoint).name;

  /*
    Test whether the endpoint's name is a multi-label domain.

    `endpoint`: dnsEndpoint value.

    Returns a Boolean.
  */
  isDomain = endpoint: types.isDomain (endpointOf "isDomain" endpoint).name;

  # ===== Accessors =====

  /*
    Get the endpoint's name.

    `endpoint`: dnsEndpoint value.

    Returns a hostname or domain value.
  */
  name = endpoint: (endpointOf "name" endpoint).name;

  # ===== Comparison =====
  #
  # Order by name, then port. Each ordering function passes its own name,
  # which its errors report.

  compareFor =
    function: a: b:
    let
      left = endpointOf function a;
      right = endpointOf function b;
      nameOrder = dnsName.compare left.name right.name;
    in
    if nameOrder != 0 then nameOrder else port.compare left.port right.port;

  /*
    Test two endpoints for equality of name and port.

    `a`, `b`: values to compare.

    Returns a Boolean; false across types.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.dnsEndpoint a b && dnsName.eq a.name b.name && port.eq a.port b.port;

  /*
    Order two endpoints by name, hostnames before domains and then by
    name, then by port.

    `a`, `b`: dnsEndpoint values.

    Returns `-1`, `0`, or `1`.
  */
  compare = compareFor "compare";

  /*
    Test whether `a` orders strictly before `b` under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns a Boolean.
  */
  lt = a: b: compareFor "lt" a b == -1;

  /*
    Test whether `a` orders before or equal to `b` under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns a Boolean.
  */
  le = a: b: compareFor "le" a b <= 0;

  /*
    Test whether `a` orders strictly after `b` under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns a Boolean.
  */
  gt = a: b: compareFor "gt" a b == 1;

  /*
    Test whether `a` orders after or equal to `b` under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns a Boolean.
  */
  ge = a: b: compareFor "ge" a b >= 0;

  /*
    Pick the lesser of two endpoints under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns `a` when they order equal, otherwise the lesser value.
  */
  min = a: b: if compareFor "min" a b <= 0 then a else b;

  /*
    Pick the greater of two endpoints under `compare`.

    `a`, `b`: dnsEndpoint values.

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
    isDomain
    isHostname
    isValid
    le
    lt
    make
    max
    min
    name
    parse
    toString
    tryParse
    ;

  # Defined here rather than in `let`, where `port` names the port module.
  /*
    Get the endpoint's port.

    `endpoint`: dnsEndpoint value.

    Returns a port value.
  */
  port = endpoint: (endpointOf "port" endpoint).port;
}
