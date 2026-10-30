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
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  ip = import ./ip.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  port = import ./port.nix;

  mk =
    addressValue: portValue:
    types.mkStrict "ipEndpoint" {
      address = addressValue;
      port = portValue;
    };

  # Check the endpoint argument of `function`, throwing for any other kind.
  ipEndpointArgument =
    function: endpoint: errors.expectKind "ipEndpoint.${function}" "ipEndpoint" endpoint;

  # ===== Parsing =====

  # Bracketed form: [<ipv6>]:<port>
  tryParseBracketed =
    input:
    let
      parts = parsing.splitOn "]:" input;
    in
    if builtins.length parts != 2 then
      types.tryErr "malformed bracketed form \"${input}\""
    else
      let
        left = builtins.elemAt parts 0;
        portString = builtins.elemAt parts 1;
        hasOpenBracket = builtins.stringLength left >= 1 && builtins.substring 0 1 left == "[";
        addressString =
          if hasOpenBracket then builtins.substring 1 (builtins.stringLength left - 1) left else null;
      in
      if addressString == null then
        types.tryErr "missing '[' in \"${input}\""
      else
        let
          addressResult = ipv6.tryParse addressString;
          portResult = port.tryParse portString;
        in
        if !addressResult.success then
          types.tryErr "invalid IPv6 in \"${input}\""
        else if !portResult.success then
          types.tryErr "invalid port in \"${input}\""
        else
          types.tryOk (mk addressResult.value portResult.value);

  # Unbracketed form: <ipv4>:<port>. Exactly one ':'.
  tryParseV4Form =
    input:
    let
      colons = parsing.countOccurrences ":" input;
    in
    if colons == 0 then
      types.tryErr "missing ':port' in \"${input}\""
    else if colons > 1 then
      types.tryErr "unbracketed IPv6 is ambiguous, use [addr]:port: \"${input}\""
    else
      let
        parts = parsing.splitOn ":" input;
        addressString = builtins.elemAt parts 0;
        portString = builtins.elemAt parts 1;
        addressResult = ipv4.tryParse addressString;
        portResult = port.tryParse portString;
      in
      if !addressResult.success then
        types.tryErr "invalid IPv4 in \"${input}\""
      else if !portResult.success then
        types.tryErr "invalid port in \"${input}\""
      else
        types.tryOk (mk addressResult.value portResult.value);

  /*
    Parse an IP endpoint: the detail parser of the parsing suite.

    `input`: `"<ipv4>:<port>"` or `"[<ipv6>]:<port>"`; IPv6 must be
    bracketed.

    Returns a tryResult holding an ipEndpoint value, or the detail of the
    failure.
  */
  tryParseDetail =
    input: if parsing.startsWith "[" input then tryParseBracketed input else tryParseV4Form input;

  parsers = parsing.suite "ipEndpoint" tryParseDetail;

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
    Test whether the endpoint's address is globally reachable.

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

  # By address, IPv4 first, then by port.
  compareFor =
    function: a: b:
    let
      left = ipEndpointArgument function a;
      right = ipEndpointArgument function b;
    in
    comparison.lexicographic [
      (ip.compare left.address right.address)
      (port.compare left.port right.port)
    ];

  ordering = comparison.suite compareFor;

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
in
{
  inherit
    address
    eq
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
    make
    toArpa
    toString
    tryParseDetail
    version
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

  # Defined here rather than in `let`, where `port` names the port module.
  /*
    Get the endpoint's port.

    `endpoint`: ipEndpoint value.

    Returns a port value.
  */
  port = endpoint: (ipEndpointArgument "port" endpoint).port;
}
