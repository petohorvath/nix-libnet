/*
  libnet.ipBindpoint

  An IP bind target: an optional IP address paired with a port
  range. Parses bare-port (":8080"), address+port ("192.0.2.1:80"),
  bracketed v6 ("[::1]:80"), and range ("192.0.2.1:8000-8100") forms.

  The IP-only bind spec. `libnet.bindpoint` is the union that also
  accepts a Unix socket path.

  Example:
    libnet.ipBindpoint.parse "192.0.2.1:8000-8100"
    => { _type = "ipBindpoint"; address = <ipv4>; portRange = <8000-8100>; }

    builtins.length
      (libnet.ipBindpoint.endpoints (libnet.ipBindpoint.parse ":80-82"))
    => 3
*/
let
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  port = import ./port.nix;
  portRange = import ./port-range.nix;
  ipEndpoint = import ./ip-endpoint.nix;

  # Force both fields, so a constructor throws for a bad argument when
  # it builds the value rather than when a field is read.
  mk =
    addressValue: portRangeValue:
    builtins.seq addressValue (
      builtins.seq portRangeValue {
        _type = "ipBindpoint";
        address = addressValue;
        portRange = portRangeValue;
      }
    );

  # Check the bindpoint argument of `function`, throwing for any other
  # kind.
  bindpointOf =
    function: bindpoint: errors.expectKind "ipBindpoint.${function}" "ipBindpoint" bindpoint;

  parseError = detail: types.tryErr (errors.message "ipBindpoint.parse" detail);

  isV4 = addressValue: addressValue._type == "ipv4";
  isV6 = addressValue: addressValue._type == "ipv6";

  # ===== Port-field parser =====

  # Decimal port number, or null when invalid.
  parsePort = parsing.decimal port.maxValue;

  # Hyphen form only: the iptables colon form (`8000:8100`) would collide
  # with the address:port separator. Returns a portRange, or null.
  parsePortField =
    input:
    let
      parts = parsing.splitOn "-" input;
    in
    if builtins.length parts == 1 then
      let
        n = parsePort input;
      in
      if n == null then null else portRange.fromPort (port.fromInt n)
    else if builtins.length parts == 2 then
      let
        from = parsePort (builtins.elemAt parts 0);
        to = parsePort (builtins.elemAt parts 1);
      in
      if from == null || to == null then
        null
      else if from > to then
        null
      else
        portRange.make (port.fromInt from) (port.fromInt to)
    else
      null;

  # ===== Parsing =====

  tryParseNullAddress =
    portString:
    let
      portRangeOrNull = parsePortField portString;
    in
    if portRangeOrNull == null then
      parseError "invalid port field \"${portString}\""
    else
      types.tryOk (mk null portRangeOrNull);

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
          portRangeOrNull = parsePortField portString;
        in
        if !addressResult.success then
          parseError "invalid IPv6 in \"${input}\""
        else if portRangeOrNull == null then
          parseError "invalid port field in \"${input}\""
        else
          types.tryOk (mk addressResult.value portRangeOrNull);

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
        portRangeOrNull = parsePortField portString;
      in
      if !addressResult.success then
        parseError "invalid IPv4 in \"${input}\""
      else if portRangeOrNull == null then
        parseError "invalid port field in \"${input}\""
      else
        types.tryOk (mk addressResult.value portRangeOrNull);

  /*
    Parse an IP bindpoint without throwing, for validating untrusted text.

    `input`: `[address]:from[-to]`, such as `":8080"`, `"*:80"`,
    `"any:80"`, `"0.0.0.0:80"`, `"192.0.2.1:8000-8100"`, or
    `"[::1]:80"`. IPv6 must be bracketed. `*:`, `any:`, and a bare `:`
    all mean "any interface" and give `address = null`, so
    `toString (parse s)` emits the canonical `:PORT` for all three.

    Returns a tryResult: `{ success = true; value; }` with an
    ipBindpoint, or `{ success = false; error; }` for non-strings and
    malformed input.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else if parsing.startsWith "*:" input then
      tryParseNullAddress (parsing.stripPrefix "*:" input)
    else if parsing.startsWith "any:" input then
      tryParseNullAddress (parsing.stripPrefix "any:" input)
    else if parsing.startsWith ":" input then
      tryParseNullAddress (parsing.stripPrefix ":" input)
    else if parsing.startsWith "[" input then
      tryParseBracketed input
    else
      tryParseV4Form input;

  /*
    Parse an IP bindpoint from its text form.

    `input`: `[address]:from[-to]`; see `tryParse` for accepted forms.

    Returns an ipBindpoint value; throws on malformed input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render an IP bindpoint in canonical form.

    `bindpoint`: ipBindpoint value.

    Returns `":<range>"` for a null address, `"<ipv4>:<range>"`, or
    `"[<ipv6>]:<range>"`; `<range>` omits `-to` for a single port.
  */
  toString =
    bindpoint:
    let
      checked = bindpointOf "toString" bindpoint;
      inherit (checked) address;
      portRangeString = portRange.toString checked.portRange;
    in
    if address == null then
      ":${portRangeString}"
    else if isV4 address then
      "${ipv4.toString address}:${portRangeString}"
    else
      "[${ipv6.toString address}]:${portRangeString}";

  /*
    Combine an already-parsed address and port range into a bindpoint.

    `addressValue`: ipv4 or ipv6 value, or null for any interface.
    `portRangeValue`: portRange value.

    Returns an ipBindpoint value; throws if either argument has the wrong
    kind.
  */
  make =
    addressValue: portRangeValue:
    mk (errors.expect "ipBindpoint.make" "ipv4 or ipv6 value or null" (
      value: value == null || types.isIp value
    ) addressValue) (errors.expectKind "ipBindpoint.make" "portRange" portRangeValue);

  # ===== Predicates =====

  /*
    Test whether a string parses as an IP bindpoint.

    `input`: value to test; non-strings yield false.

    Returns a Boolean.
  */
  isValid = input: (tryParse input).success;

  /*
    Test whether a value is an ipBindpoint.

    `value`: any value.

    Returns a Boolean.
  */
  is = value: types.isIpBindpoint value;

  /*
    Test whether the bindpoint binds on every interface: its address is
    the wildcard address.

    `bindpoint`: ipBindpoint value.

    Returns true iff the address is null, `0.0.0.0`, or `::`.
  */
  isWildcard =
    bindpoint:
    let
      inherit (bindpointOf "isWildcard" bindpoint) address;
    in
    address == null
    || (isV4 address && address.value == 0)
    || (
      isV6 address
      &&
        address.words == [
          0
          0
          0
          0
        ]
    );

  /*
    Test whether the bindpoint has an IPv4 address.

    `bindpoint`: ipBindpoint value.

    Returns a Boolean; false for a null address.
  */
  isIpv4 =
    bindpoint:
    let
      inherit (bindpointOf "isIpv4" bindpoint) address;
    in
    address != null && isV4 address;

  /*
    Test whether the bindpoint has an IPv6 address.

    `bindpoint`: ipBindpoint value.

    Returns a Boolean; false for a null address.
  */
  isIpv6 =
    bindpoint:
    let
      inherit (bindpointOf "isIpv6" bindpoint) address;
    in
    address != null && isV6 address;

  # ===== Forwarded predicates (apply to address) =====
  #
  # Null-address bindpoints (wildcard binds) don't denote a specific
  # address, so boolean predicates return false rather than throwing —
  # consistent with isIpv4/isIpv6. toArpa has no sensible value without
  # an address and throws, matching endpoints/network/netmask.

  forwardToAddress =
    function: ipv4Function: ipv6Function: bindpoint:
    let
      inherit (bindpointOf function bindpoint) address;
    in
    if address == null then
      false
    else if isV4 address then
      ipv4Function address
    else
      ipv6Function address;

  /*
    Test whether the bindpoint's address is a loopback address.

    `bindpoint`: ipBindpoint value.

    Returns a Boolean; false for a null address.
  */
  isLoopback = forwardToAddress "isLoopback" ipv4.isLoopback ipv6.isLoopback;

  /*
    Test whether the bindpoint's address is the unspecified address.

    `bindpoint`: ipBindpoint value.

    Returns a Boolean; false for a null address.
  */
  isUnspecified = forwardToAddress "isUnspecified" ipv4.isUnspecified ipv6.isUnspecified;

  /*
    Test whether the bindpoint's address is link-local.

    `bindpoint`: ipBindpoint value.

    Returns a Boolean; false for a null address.
  */
  isLinkLocal = forwardToAddress "isLinkLocal" ipv4.isLinkLocal ipv6.isLinkLocal;

  /*
    Test whether the bindpoint's address is multicast.

    `bindpoint`: ipBindpoint value.

    Returns a Boolean; false for a null address.
  */
  isMulticast = forwardToAddress "isMulticast" ipv4.isMulticast ipv6.isMulticast;

  /*
    Test whether the bindpoint's address is reserved for documentation.

    `bindpoint`: ipBindpoint value.

    Returns a Boolean; false for a null address.
  */
  isDocumentation = forwardToAddress "isDocumentation" ipv4.isDocumentation ipv6.isDocumentation;

  /*
    Test whether the bindpoint's address is globally routable.

    `bindpoint`: ipBindpoint value.

    Returns a Boolean; false for a null address.
  */
  isGlobal = forwardToAddress "isGlobal" ipv4.isGlobal ipv6.isGlobal;

  /*
    Test whether the bindpoint's address is a bogon (not expected on the
    public internet).

    `bindpoint`: ipBindpoint value.

    Returns a Boolean; false for a null address.
  */
  isBogon = forwardToAddress "isBogon" ipv4.isBogon ipv6.isBogon;

  /*
    Render the bindpoint's address as a reverse-DNS name; the port range
    is ignored.

    `bindpoint`: ipBindpoint value.

    Returns an `in-addr.arpa` or `ip6.arpa` name string; throws for a
    null address.
  */
  toArpa =
    bindpoint:
    let
      inherit (bindpointOf "toArpa" bindpoint) address;
    in
    if address == null then
      errors.fail "ipBindpoint.toArpa" "null address has no reverse-DNS form"
    else if isV4 address then
      ipv4.toArpa address
    else
      ipv6.toArpa address;

  # ===== Accessors =====

  /*
    Get the bindpoint's address.

    `bindpoint`: ipBindpoint value.

    Returns an ipv4 or ipv6 value, or null for any interface.
  */
  address = bindpoint: (bindpointOf "address" bindpoint).address;

  /*
    Get the IP family of the bindpoint's address.

    `bindpoint`: ipBindpoint value.

    Returns `4`, `6`, or null for a null address.
  */
  version =
    bindpoint:
    let
      inherit (bindpointOf "version" bindpoint) address;
    in
    if address == null then
      null
    else if isV4 address then
      4
    else
      6;

  # ===== Expansion =====

  # Every port of the range as an endpoint, for `function`'s errors.
  endpointsFor =
    function: bindpoint:
    if bindpoint.address == null then
      errors.fail "ipBindpoint.${function}" "null address cannot be materialized into endpoints"
    else
      map (portValue: ipEndpoint.make bindpoint.address portValue) (
        portRange.portsUnbounded bindpoint.portRange
      );

  /*
    Materialize every port in the range as a concrete endpoint, without
    the size guard of `endpoints`.

    `bindpoint`: ipBindpoint value with a non-null address.

    Returns a list of ipEndpoint values in port order; throws for a null
    address.
  */
  endpointsUnbounded =
    bindpoint: endpointsFor "endpointsUnbounded" (bindpointOf "endpointsUnbounded" bindpoint);

  /*
    Materialize every port in the range as a concrete endpoint.

    `bindpoint`: ipBindpoint value with a non-null address and at most
    4096 ports.

    Returns a list of ipEndpoint values in port order; throws for a null
    address or a larger range (use `endpointsUnbounded` instead).
  */
  endpoints =
    bindpoint:
    let
      checked = bindpointOf "endpoints" bindpoint;
      size = portRange.size checked.portRange;
    in
    if size > 4096 then
      errors.fail "ipBindpoint.endpoints" "range too large (${builtins.toString size} > 4096); use endpointsUnbounded"
    else
      endpointsFor "endpoints" checked;

  /*
    Pick one port from the range as a concrete endpoint.

    `n`: zero-based index into the range; negative counts from the end.
    `bindpoint`: ipBindpoint value with a non-null address.

    Returns an ipEndpoint value; throws for a non-integer index, a null
    address or an index outside the range.
  */
  endpointAt =
    n: bindpoint:
    let
      offset = errors.expectType "ipBindpoint.endpointAt" "int" n;
      checked = bindpointOf "endpointAt" bindpoint;
    in
    if checked.address == null then
      errors.fail "ipBindpoint.endpointAt" "null address cannot be materialized"
    else
      let
        size = portRange.size checked.portRange;
        index = if offset < 0 then size + offset else offset;
      in
      if index < 0 || index >= size then
        errors.fail "ipBindpoint.endpointAt" "index out of range [0, ${builtins.toString size})"
      else
        ipEndpoint.make checked.address (port.add index checked.portRange.from);

  # ===== Comparison =====

  # The order behind `compare`; each ordering function passes its own
  # name, which its errors report.
  compareFor =
    function: a: b:
    let
      left = bindpointOf function a;
      right = bindpointOf function b;
    in
    if left.address == null && right.address != null then
      -1
    else if left.address != null && right.address == null then
      1
    else if
      left.address == null # both null
    then
      portRange.compare left.portRange right.portRange
    else if isV4 left.address && isV6 right.address then
      -1
    else if isV6 left.address && isV4 right.address then
      1
    else
      let
        addressOrder =
          if isV4 left.address then
            ipv4.compare left.address right.address
          else
            ipv6.compare left.address right.address;
      in
      if addressOrder != 0 then addressOrder else portRange.compare left.portRange right.portRange;

  /*
    Test two bindpoints for equality of address and port range.

    `a`, `b`: values to compare.

    Returns a Boolean; false across types or address families, and
    between a null and a non-null address.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.ipBindpoint a b
    && (
      a.address == null && b.address == null
      || (
        a.address != null
        && b.address != null
        && a.address._type == b.address._type
        && (if isV4 a.address then ipv4.eq a.address b.address else ipv6.eq a.address b.address)
      )
    )
    && portRange.eq a.portRange b.portRange;

  /*
    Order two bindpoints: null address first, then IPv4 before IPv6,
    then address, then port range.

    `a`, `b`: ipBindpoint values.

    Returns `-1`, `0`, or `1`.
  */
  compare = compareFor "compare";

  /*
    Test whether `a` orders strictly before `b` under `compare`.

    `a`, `b`: ipBindpoint values.

    Returns a Boolean.
  */
  lt = a: b: compareFor "lt" a b == -1;

  /*
    Test whether `a` orders before or equal to `b` under `compare`.

    `a`, `b`: ipBindpoint values.

    Returns a Boolean.
  */
  le = a: b: compareFor "le" a b <= 0;

  /*
    Test whether `a` orders strictly after `b` under `compare`.

    `a`, `b`: ipBindpoint values.

    Returns a Boolean.
  */
  gt = a: b: compareFor "gt" a b == 1;

  /*
    Test whether `a` orders after or equal to `b` under `compare`.

    `a`, `b`: ipBindpoint values.

    Returns a Boolean.
  */
  ge = a: b: compareFor "ge" a b >= 0;

  /*
    Pick the lesser of two bindpoints under `compare`.

    `a`, `b`: ipBindpoint values.

    Returns `a` when they order equal, otherwise the lesser value.
  */
  min = a: b: if compareFor "min" a b <= 0 then a else b;

  /*
    Pick the greater of two bindpoints under `compare`.

    `a`, `b`: ipBindpoint values.

    Returns `a` when they order equal, otherwise the greater value.
  */
  max = a: b: if compareFor "max" a b >= 0 then a else b;
in
{
  inherit
    address
    compare
    endpointAt
    endpoints
    endpointsUnbounded
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
    isWildcard
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

  # Defined here rather than in `let`, where `portRange` names the
  # port-range module.
  /*
    Get the bindpoint's port range.

    `bindpoint`: ipBindpoint value.

    Returns a portRange value.
  */
  portRange = bindpoint: (bindpointOf "portRange" bindpoint).portRange;
}
