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
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  port = import ./port.nix;

  mk = addressValue: portValue: {
    _type = "ipEndpoint";
    address = addressValue;
    port = portValue;
  };

  # ===== Parsing =====

  # Bracketed form: [<ipv6>]:<port>
  tryParseBracketed =
    input:
    let
      parts = parsing.splitOn "]:" input;
    in
    if builtins.length parts != 2 then
      types.tryErr "libnet.ipEndpoint.parse: malformed bracketed form \"${input}\""
    else
      let
        left = builtins.elemAt parts 0;
        portString = builtins.elemAt parts 1;
        hasOpenBracket = builtins.stringLength left >= 1 && builtins.substring 0 1 left == "[";
        addressString =
          if hasOpenBracket then builtins.substring 1 (builtins.stringLength left - 1) left else null;
      in
      if addressString == null then
        types.tryErr "libnet.ipEndpoint.parse: missing '[' in \"${input}\""
      else
        let
          addressResult = ipv6.tryParse addressString;
          portResult = port.tryParse portString;
        in
        if !addressResult.success then
          types.tryErr "libnet.ipEndpoint.parse: invalid IPv6 in \"${input}\""
        else if !portResult.success then
          types.tryErr "libnet.ipEndpoint.parse: invalid port in \"${input}\""
        else
          types.tryOk (mk addressResult.value portResult.value);

  # Unbracketed form: <ipv4>:<port>. Exactly one ':'.
  tryParseV4Form =
    input:
    let
      colons = parsing.countOccurrences ":" input;
    in
    if colons == 0 then
      types.tryErr "libnet.ipEndpoint.parse: missing ':port' in \"${input}\""
    else if colons > 1 then
      types.tryErr "libnet.ipEndpoint.parse: unbracketed IPv6 is ambiguous, use [addr]:port: \"${input}\""
    else
      let
        parts = parsing.splitOn ":" input;
        addressString = builtins.elemAt parts 0;
        portString = builtins.elemAt parts 1;
        addressResult = ipv4.tryParse addressString;
        portResult = port.tryParse portString;
      in
      if !addressResult.success then
        types.tryErr "libnet.ipEndpoint.parse: invalid IPv4 in \"${input}\""
      else if !portResult.success then
        types.tryErr "libnet.ipEndpoint.parse: invalid port in \"${input}\""
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
      types.tryErr "libnet.ipEndpoint.parse: input must be a string"
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
      portString = port.toString endpoint.port;
    in
    if types.isIpv4 endpoint.address then
      "${ipv4.toString endpoint.address}:${portString}"
    else
      "[${ipv6.toString endpoint.address}]:${portString}";

  /*
    Combine an already-parsed address and port into an endpoint.

    `addressValue`: ipv4 or ipv6 value.
    `portValue`: port value.

    Returns an ipEndpoint value; throws if either argument has the wrong
    type.
  */
  make =
    addressValue: portValue:
    if !(types.isIp addressValue) then
      throw "libnet.ipEndpoint.make: address must be ipv4 or ipv6"
    else if !(types.isPort portValue) then
      throw "libnet.ipEndpoint.make: expected port value"
    else
      mk addressValue portValue;

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
  isIpv4 = endpoint: types.isIpv4 endpoint.address;

  /*
    Test whether the endpoint's address is IPv6.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isIpv6 = endpoint: types.isIpv6 endpoint.address;

  # ===== Accessors =====

  /*
    Get the endpoint's address.

    `endpoint`: ipEndpoint value.

    Returns an ipv4 or ipv6 value.
  */
  address = endpoint: endpoint.address;

  /*
    Get the IP family of the endpoint's address.

    `endpoint`: ipEndpoint value.

    Returns `4` or `6`.
  */
  version = endpoint: if types.isIpv4 endpoint.address then 4 else 6;

  # ===== Forwarded predicates (apply to address) =====

  forwardToAddress =
    ipv4Function: ipv6Function: endpoint:
    if types.isIpv4 endpoint.address then
      ipv4Function endpoint.address
    else
      ipv6Function endpoint.address;

  /*
    Test whether the endpoint's address is a loopback address.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isLoopback = endpoint: forwardToAddress ipv4.isLoopback ipv6.isLoopback endpoint;

  /*
    Test whether the endpoint's address is the unspecified address.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isUnspecified = endpoint: forwardToAddress ipv4.isUnspecified ipv6.isUnspecified endpoint;

  /*
    Test whether the endpoint's address is link-local.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isLinkLocal = endpoint: forwardToAddress ipv4.isLinkLocal ipv6.isLinkLocal endpoint;

  /*
    Test whether the endpoint's address is multicast.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isMulticast = endpoint: forwardToAddress ipv4.isMulticast ipv6.isMulticast endpoint;

  /*
    Test whether the endpoint's address is reserved for documentation.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isDocumentation = endpoint: forwardToAddress ipv4.isDocumentation ipv6.isDocumentation endpoint;

  /*
    Test whether the endpoint's address is globally routable.

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isGlobal = endpoint: forwardToAddress ipv4.isGlobal ipv6.isGlobal endpoint;

  /*
    Test whether the endpoint's address is a bogon (not expected on the
    public internet).

    `endpoint`: ipEndpoint value.

    Returns a Boolean.
  */
  isBogon = endpoint: forwardToAddress ipv4.isBogon ipv6.isBogon endpoint;

  /*
    Render the endpoint's address as a reverse-DNS name; the port is
    ignored.

    `endpoint`: ipEndpoint value.

    Returns an `in-addr.arpa` or `ip6.arpa` name string.
  */
  toArpa = endpoint: forwardToAddress ipv4.toArpa ipv6.toArpa endpoint;

  # ===== Comparison =====

  /*
    Test two endpoints for equality of family, address, and port.

    `a`, `b`: values to compare.

    Returns a Boolean; false across types or address families.
  */
  eq =
    a: b:
    types.hasSameTag a b
    && a.address._type == b.address._type
    && (if types.isIpv4 a.address then ipv4.eq a.address b.address else ipv6.eq a.address b.address)
    && port.eq a.port b.port;

  /*
    Order two endpoints by family (IPv4 first), then address, then port.

    `a`, `b`: ipEndpoint values.

    Returns `-1`, `0`, or `1`.
  */
  compare =
    a: b:
    if types.isIpv4 a.address && types.isIpv6 b.address then
      -1
    else if types.isIpv6 a.address && types.isIpv4 b.address then
      1
    else
      let
        addressOrder =
          if types.isIpv4 a.address then
            ipv4.compare a.address b.address
          else
            ipv6.compare a.address b.address;
      in
      if addressOrder != 0 then addressOrder else port.compare a.port b.port;

  /*
    Test whether `a` orders strictly before `b` under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` orders before or equal to `b` under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` orders strictly after `b` under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` orders after or equal to `b` under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two endpoints under `compare`.

    `a`, `b`: ipEndpoint values.

    Returns `a` when they order equal, otherwise the lesser value.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two endpoints under `compare`.

    `a`, `b`: ipEndpoint values.

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
  port = endpoint: endpoint.port;
}
