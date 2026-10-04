/*
  libnet.transport

  Validated transport-protocol enum. Tagged value parallel to
  libnet.port, restricted to TCP, UDP, and SCTP — the three most
  common port-bearing L4 transports. DCCP and UDP-Lite are also
  netfilter-matchable but intentionally omitted. No ordering or
  arithmetic — transport protocols have no canonical order.

  Example:
    libnet.transport.parse "tcp"
    => { _type = "transport"; value = "tcp"; }

    libnet.transport.isUdp libnet.transport.udp
    => true
*/
let
  types = import ./internal/types.nix;

  values = [
    "tcp"
    "udp"
    "sctp"
  ];

  mk = value: {
    _type = "transport";
    inherit value;
  };

  # ===== Parsing =====

  /*
    Parse a transport protocol name without throwing, for callers that
    want to report or recover from invalid input.

    `input`: protocol name, one of "tcp", "udp", or "sctp"
    (case-sensitive).

    Returns a tryResult: `{ success = true; value; }` with a transport
    value, or `{ success = false; error; }` describing the problem.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.transport.parse: input must be a string"
    else if !(builtins.elem input values) then
      types.tryErr "libnet.transport.parse: unknown protocol \"${input}\" (expected one of: tcp, udp, sctp)"
    else
      types.tryOk (mk input);

  /*
    Parse a transport protocol name.

    `input`: protocol name, one of "tcp", "udp", or "sctp"
    (case-sensitive).

    Returns a transport value; throws on a non-string or unknown name.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a transport as its protocol name.

    `transport`: transport value.

    Returns "tcp", "udp", or "sctp".
  */
  toString = transport: transport.value;

  # ===== Predicates =====

  /*
    Check whether a protocol name parses, without throwing.

    `input`: value to check.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a transport value.

    `value`: any value; non-attrsets are accepted and yield false.

    Returns true for an attrset tagged `_type = "transport"`, false
    otherwise; other fields are not checked.
  */
  is = value: types.isTransport value;

  /*
    Check whether a transport is TCP.

    `transport`: transport value.

    Returns true for `tcp`.
  */
  isTcp = transport: transport.value == "tcp";

  /*
    Check whether a transport is UDP.

    `transport`: transport value.

    Returns true for `udp`.
  */
  isUdp = transport: transport.value == "udp";

  /*
    Check whether a transport is SCTP.

    `transport`: transport value.

    Returns true for `sctp`.
  */
  isSctp = transport: transport.value == "sctp";

  # ===== Comparison =====
  #
  # Only `eq` is provided. Transport protocols have no canonical order,
  # so `lt` / `compare` / `min` / `max` would have to invent one. Users
  # who need to sort a list of transports can sort on `.value` directly.

  /*
    Compare two transports for equality.

    `a`, `b`: transport values.

    Returns true when both carry the same type tag and protocol.
  */
  eq = a: b: a._type == b._type && a.value == b.value;

  # ===== Constants =====

  tcp = mk "tcp";
  udp = mk "udp";
  sctp = mk "sctp";
in
{
  inherit
    eq
    is
    isSctp
    isTcp
    isUdp
    isValid
    parse
    sctp
    tcp
    toString
    tryParse
    udp
    values
    ;
}
