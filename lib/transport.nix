/*
  libnet.transport

  Validated transport-protocol enum. Tagged value parallel to
  libnet.port, restricted to TCP, UDP, and SCTP — the three most
  common port-bearing L4 transports. DCCP and UDP-Lite are also
  netfilter-matchable but intentionally omitted. Transports sort by
  name (`sctp < tcp < udp`) for determinism only; there is no
  arithmetic.

  Example:
    libnet.transport.parse "tcp"
    => { _type = "transport"; value = "tcp"; }

    libnet.transport.isUdp libnet.transport.udp
    => true
*/
let
  types = import ./internal/types.nix;

  names = [
    "sctp"
    "tcp"
    "udp"
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
    else if !(builtins.elem input names) then
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
  # Transport protocols have no natural order, so they sort by name
  # (`sctp < tcp < udp`), for determinism only.

  /*
    Compare two transports for equality.

    `a`, `b`: transport values.

    Returns true when both carry the same type tag and protocol.
  */
  eq = a: b: types.hasSameTag a b && a.value == b.value;

  /*
    Order two transports by name (`sctp < tcp < udp`).

    `a`, `b`: transport values.

    Returns -1, 0, or 1.
  */
  compare =
    a: b:
    if a.value < b.value then
      -1
    else if a.value > b.value then
      1
    else
      0;

  /*
    Check whether one transport sorts before another.

    `a`, `b`: transport values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Check whether one transport sorts before or equal to another.

    `a`, `b`: transport values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Check whether one transport sorts after another.

    `a`, `b`: transport values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Check whether one transport sorts after or equal to another.

    `a`, `b`: transport values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two transports by `compare`.

    `a`, `b`: transport values.

    Returns `a` when it sorts first or equal, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two transports by `compare`.

    `a`, `b`: transport values.

    Returns `a` when it sorts last or equal, otherwise `b`.
  */
  max = a: b: if ge a b then a else b;

  # ===== Constants =====

  tcp = mk "tcp";
  udp = mk "udp";
  sctp = mk "sctp";

  # Every transport, in `compare` order.
  values = map mk names;
in
{
  inherit
    compare
    eq
    ge
    gt
    is
    isSctp
    isTcp
    isUdp
    isValid
    le
    lt
    max
    min
    parse
    sctp
    tcp
    toString
    tryParse
    udp
    values
    ;
}
