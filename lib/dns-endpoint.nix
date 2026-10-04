/*
  libnet.dnsEndpoint

  A DNS name (hostname or domain) paired with a port — the name-only
  counterpart to libnet.ipEndpoint. The address is a `dnsName`, so IP
  literals are rejected (use `ipEndpoint`, or the `endpoint` union,
  for those).

  No IP-classification predicates (isLoopback, isGlobal, toArpa, …): a
  name has no resolved address until DNS runs, and libnet does no
  resolution.

  Example:
    libnet.dnsEndpoint.parse "pool.ntp.org:123"
    => { _type = "dnsEndpoint"; address = <domain>; port = <port 123>; }

    libnet.dnsEndpoint.parse "nas:22"
    => { _type = "dnsEndpoint"; address = <hostname>; port = <port 22>; }
*/
let
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  dnsName = import ./dns-name.nix;
  port = import ./port.nix;

  mk = addressValue: portValue: {
    _type = "dnsEndpoint";
    address = addressValue;
    port = portValue;
  };

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
      types.tryErr "libnet.dnsEndpoint.parse: input must be a string"
    else if parsing.startsWith "[" input then
      types.tryErr "libnet.dnsEndpoint.parse: bracketed form is for IPv6; a dnsEndpoint addresses a name: \"${input}\""
    else if parsing.countOccurrences ":" input != 1 then
      types.tryErr "libnet.dnsEndpoint.parse: expected exactly one ':' (name:port): \"${input}\""
    else
      let
        parts = parsing.splitOn ":" input;
        addressString = builtins.elemAt parts 0;
        portString = builtins.elemAt parts 1;
        addressResult = dnsName.tryParse addressString;
        portResult = port.tryParse portString;
      in
      if !addressResult.success then
        types.tryErr "libnet.dnsEndpoint.parse: ${addressResult.error}"
      else if !portResult.success then
        types.tryErr "libnet.dnsEndpoint.parse: invalid port in \"${input}\""
      else
        types.tryOk (mk addressResult.value portResult.value);

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

    Returns `"<name>:<port>"`, preserving the name's input case.
  */
  toString = endpoint: "${dnsName.toString endpoint.address}:${port.toString endpoint.port}";

  /*
    Combine an already-parsed DNS name and port into an endpoint.

    `addressValue`: hostname or domain value.
    `portValue`: port value.

    Returns a dnsEndpoint value; throws if either argument has the wrong
    type.
  */
  make =
    addressValue: portValue:
    if !(dnsName.is addressValue) then
      throw "libnet.dnsEndpoint.make: address must be a hostname or domain"
    else if !(types.isPort portValue) then
      throw "libnet.dnsEndpoint.make: expected port value"
    else
      mk addressValue portValue;

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
    Test whether the endpoint's address is a single-label hostname.

    `endpoint`: dnsEndpoint value.

    Returns a Boolean.
  */
  isHostname = endpoint: types.isHostname endpoint.address;

  /*
    Test whether the endpoint's address is a multi-label domain.

    `endpoint`: dnsEndpoint value.

    Returns a Boolean.
  */
  isDomain = endpoint: types.isDomain endpoint.address;

  # ===== Accessors =====

  /*
    Get the endpoint's name.

    `endpoint`: dnsEndpoint value.

    Returns a hostname or domain value.
  */
  address = endpoint: endpoint.address;

  # ===== Comparison =====
  #
  # Dispatch on the name address (case-insensitive per DNS), then port.

  /*
    Test two endpoints for equality of name (case-insensitive) and port.

    `a`, `b`: values to compare.

    Returns a Boolean; false across types.
  */
  eq = a: b: a._type == b._type && dnsName.eq a.address b.address && port.eq a.port b.port;

  /*
    Order two endpoints by name (case-insensitive), then port.

    `a`, `b`: dnsEndpoint values.

    Returns `-1`, `0`, or `1`.
  */
  compare =
    a: b:
    let
      addressOrder = dnsName.compare a.address b.address;
    in
    if addressOrder != 0 then addressOrder else port.compare a.port b.port;

  /*
    Test whether `a` orders strictly before `b` under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` orders before or equal to `b` under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` orders strictly after `b` under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` orders after or equal to `b` under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two endpoints under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns `a` when they order equal, otherwise the lesser value.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two endpoints under `compare`.

    `a`, `b`: dnsEndpoint values.

    Returns `a` when they order equal, otherwise the greater value.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    address
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
  port = endpoint: endpoint.port;
}
