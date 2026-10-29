/*
  libnet.ipEndpoint

  An IP address paired with a port. Parses the v4 dotted form
  ("host:port") and the v6 bracketed form ("[host]:port").

  Example:
    libnet.ipEndpoint.parse "192.0.2.1:8080"
    => { _type = "ipEndpoint"; address = <ipv4>; port = <port 8080>; }

    libnet.ipEndpoint.toString (libnet.ipEndpoint.parse "[2001:db8::1]:80")
    => "[2001:db8::1]:80"
*/
let
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  port = import ./port.nix;

  # Force both fields, so a constructor throws for a bad argument when
  # it builds the value rather than when a field is read.
  mk =
    addressValue: portValue:
    builtins.seq addressValue (
      builtins.seq portValue {
        _type = "ipEndpoint";
        address = addressValue;
        port = portValue;
      }
    );

  # Check the endpoint argument of `function`, throwing for any other kind.
  ipEndpointArgument =
    function: endpoint: errors.expectKind "ipEndpoint.${function}" "ipEndpoint" endpoint;

  parseError = detail: types.tryErr (errors.message "ipEndpoint.parse" detail);

  # ===== Parsing =====

  # Bracketed form: [<ipv6>]:<port>
  tryParseBracketed =
    input:
    let
      parts = parsing.splitOn "]:" input;
    in
    if builtins.length parts != 2 then
      parseError "malformed bracketed form \"${input}\""
    else
      let
        left = builtins.elemAt parts 0;
        portString = builtins.elemAt parts 1;
        hasOpenBracket = builtins.stringLength left >= 1 && builtins.substring 0 1 left == "[";
        addressString =
          if hasOpenBracket then builtins.substring 1 (builtins.stringLength left - 1) left else null;
      in
      if addressString == null then
        parseError "missing '[' in \"${input}\""
      else
        let
          addressResult = ipv6.tryParse addressString;
          portResult = port.tryParse portString;
        in
        if !addressResult.success then
          parseError "invalid IPv6 in \"${input}\""
        else if !portResult.success then
          parseError "invalid port in \"${input}\""
        else
          types.tryOk (mk addressResult.value portResult.value);

  # Unbracketed form: <ipv4>:<port>. Exactly one ':'.
  tryParseV4Form =
    input:
    let
      colons = parsing.countOccurrences ":" input;
    in
    if colons == 0 then
      parseError "missing ':port' in \"${input}\""
    else if colons > 1 then
      parseError "unbracketed IPv6 is ambiguous, use [addr]:port: \"${input}\""
    else
      let
        parts = parsing.splitOn ":" input;
        addressString = builtins.elemAt parts 0;
        portString = builtins.elemAt parts 1;
        addressResult = ipv4.tryParse addressString;
        portResult = port.tryParse portString;
      in
      if !addressResult.success then
        parseError "invalid IPv4 in \"${input}\""
      else if !portResult.success then
        parseError "invalid port in \"${input}\""
      else
        types.tryOk (mk addressResult.value portResult.value);

  /*
    Parse an IP endpoint without throwing, for validating untrusted text.

    `input`: `"<ipv4>:<port>"` or `"[<ipv6>]:<port>"`; IPv6 must be
    bracketed.

    Returns a tryResult: `{ success = true; value; }` with an ipEndpoint,
    or `{ success = false; error; }` for non-strings and malformed input.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else if parsing.startsWith "[" input then
      tryParseBracketed input
    else
      tryParseV4Form input;

  /*
    Parse an IP endpoint from its text form.

    `input`: `"<ipv4>:<port>"` or `"[<ipv6>]:<port>"`; IPv6 must be
    bracketed.

    Returns an ipEndpoint value; throws on unbracketed IPv6, a missing
    port, or an invalid address or port.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render an IP endpoint in canonical RFC 3986 form.

    `endpoint`: ipEndpoint value.

    Returns `"<ipv4>:<port>"` for IPv4 or `"[<ipv6>]:<port>"` for IPv6.
  */
  toString =
    endpoint:
    let
      checked = ipEndpointArgument "toString" endpoint;
      portString = port.toString checked.port;
    in
    if types.isIpv4 checked.address then
      "${ipv4.toString checked.address}:${portString}"
    else
      "[${ipv6.toString checked.address}]:${portString}";

  /*
    Combine an already-parsed address and port into an endpoint.

    `addressValue`: ipv4 or ipv6 value.
    `portValue`: port value.

    Returns an ipEndpoint value; throws if either argument has the wrong
    kind.
  */
  make =
    addressValue: portValue:
    mk (errors.expect "ipEndpoint.make" "ipv4 or ipv6 value" types.isIp addressValue) (
      errors.expectKind "ipEndpoint.make" "port" portValue
    );

  # ===== Predicates =====

  /*
    Test whether a string parses as an IP endpoint.

    `input`: value to test; non-strings yield false.

    Returns a Boolean.
  */
  isValid = input: (tryParse input).success;

  /*
    Test whether a value is an ipEndpoint.

    `value`: any value.

    Returns a Boolean.
  */
  is = value: types.isIpEndpoint value;

  /*
    Test whether the endpoint's address is IPv4.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isIpv4 = endpoint: types.isIpv4 (ipEndpointArgument "isIpv4" endpoint).address;

  /*
    Test whether the endpoint's address is IPv6.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isIpv6 = endpoint: types.isIpv6 (ipEndpointArgument "isIpv6" endpoint).address;

  # ===== Accessors =====

  /*
    Get the endpoint's address.

    `endpoint`: ipEndpoint value.

    Returns an ipv4 or ipv6 value.
  */
  address = endpoint: (ipEndpointArgument "address" endpoint).address;

  /*
    Get the IP family of the endpoint's address.

    `endpoint`: ipEndpoint value.

    Returns `4` or `6`.
  */
  version = endpoint: if types.isIpv4 (ipEndpointArgument "version" endpoint).address then 4 else 6;

  # ===== Forwarded predicates (apply to address) =====

  # Apply the family's function to the address; `function` names the
  # public function for the argument-kind error.
  forwardToAddress =
    function: ipv4Function: ipv6Function: endpoint:
    let
      inherit (ipEndpointArgument function endpoint) address;
    in
    if types.isIpv4 address then ipv4Function address else ipv6Function address;

  /*
    Test whether the endpoint's address is a loopback address.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isLoopback = forwardToAddress "isLoopback" ipv4.isLoopback ipv6.isLoopback;

  /*
    Test whether the endpoint's address is the unspecified address.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isUnspecified = forwardToAddress "isUnspecified" ipv4.isUnspecified ipv6.isUnspecified;

  /*
    Test whether the endpoint's address is link-local.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isLinkLocal = forwardToAddress "isLinkLocal" ipv4.isLinkLocal ipv6.isLinkLocal;

  /*
    Test whether the endpoint's address is multicast.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isMulticast = forwardToAddress "isMulticast" ipv4.isMulticast ipv6.isMulticast;

  /*
    Test whether the endpoint's address is reserved for documentation.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isDocumentation = forwardToAddress "isDocumentation" ipv4.isDocumentation ipv6.isDocumentation;

  /*
    Test whether the endpoint's address is globally routable.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isGlobal = forwardToAddress "isGlobal" ipv4.isGlobal ipv6.isGlobal;

  /*
    Test whether the endpoint's address is a bogon (not expected on the
    public internet).

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isBogon = forwardToAddress "isBogon" ipv4.isBogon ipv6.isBogon;

  /*
    Render the endpoint's address as a reverse-DNS name; the port is
    ignored.

    `endpoint`: ipEndpoint value.

    Returns an `in-addr.arpa` or `ip6.arpa` name string.
  */
  toArpa = forwardToAddress "toArpa" ipv4.toArpa ipv6.toArpa;

  # ===== Comparison =====

  # The order behind `compare`; each ordering function passes its own
  # name, which its errors report.
  compareFor =
    function: a: b:
    let
      left = ipEndpointArgument function a;
      right = ipEndpointArgument function b;
    in
    if types.isIpv4 left.address && types.isIpv6 right.address then
      -1
    else if types.isIpv6 left.address && types.isIpv4 right.address then
      1
    else
      let
        addressOrder =
          if types.isIpv4 left.address then
            ipv4.compare left.address right.address
          else
            ipv6.compare left.address right.address;
      in
      if addressOrder != 0 then addressOrder else port.compare left.port right.port;

  /*
    Test two endpoints for equality of family, address, and port.

    `a`, `b`: values to compare.

    Returns a Boolean; false across types or address families.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.ipEndpoint a b
    && a.address._type == b.address._type
    && (if types.isIpv4 a.address then ipv4.eq a.address b.address else ipv6.eq a.address b.address)
    && port.eq a.port b.port;

  /*
    Order two endpoints by family (IPv4 first), then address, then port.

    `a`, `b`: ipEndpoint values.

    Returns `-1`, `0`, or `1`.
  */
  compare = compareFor "compare";

  /*
    Test whether `a` orders strictly before `b` under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns a Boolean.
  */
  lt = a: b: compareFor "lt" a b == -1;

  /*
    Test whether `a` orders before or equal to `b` under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns a Boolean.
  */
  le = a: b: compareFor "le" a b <= 0;

  /*
    Test whether `a` orders strictly after `b` under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns a Boolean.
  */
  gt = a: b: compareFor "gt" a b == 1;

  /*
    Test whether `a` orders after or equal to `b` under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns a Boolean.
  */
  ge = a: b: compareFor "ge" a b >= 0;

  /*
    Pick the lesser of two endpoints under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns `a` when they order equal, otherwise the lesser value.
  */
  min = a: b: if compareFor "min" a b <= 0 then a else b;

  /*
    Pick the greater of two endpoints under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns `a` when they order equal, otherwise the greater value.
  */
  max = a: b: if compareFor "max" a b >= 0 then a else b;
in
{
  inherit
    address
    compare
    eq
    ge
    gt
    is
    isBogon
    isDocumentation
    isGlobal
    isIpv4
    isIpv6
    isLinkLocal
    isLoopback
    isMulticast
    isUnspecified
    isValid
    le
    lt
    make
    max
    min
    parse
    toArpa
    toString
    tryParse
    version
    ;

  # Defined here rather than in `let`, where `port` names the port module.
  /*
    Get the endpoint's port.

    `endpoint`: ipEndpoint value.

    Returns a port value.
  */
  port = endpoint: (ipEndpointArgument "port" endpoint).port;
}
