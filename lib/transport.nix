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
  errors = import ./internal/errors.nix;
  comparison = import ./internal/comparison.nix;

  names = [
    "sctp"
    "tcp"
    "udp"
  ];

  mk = value: {
    _type = "transport";
    inherit value;
  };

  # The protocol name of a transport argument of `caller`.
  valueOf = caller: transport: (errors.expectKind caller "transport" transport).value;

  parseError = detail: types.tryErr (errors.message "transport.parse" detail);

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
      parseError "expected string, got ${errors.describe input}"
    else if !(builtins.elem input names) then
      parseError "unknown protocol \"${input}\" (expected one of: tcp, udp, sctp)"
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
  toString = valueOf "transport.toString";

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
  isTcp = transport: valueOf "transport.isTcp" transport == "tcp";

  /*
    Check whether a transport is UDP.

    `transport`: transport value.

    Returns true for `udp`.
  */
  isUdp = transport: valueOf "transport.isUdp" transport == "udp";

  /*
    Check whether a transport is SCTP.

    `transport`: transport value.

    Returns true for `sctp`.
  */
  isSctp = transport: valueOf "transport.isSctp" transport == "sctp";

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

  ordering = comparison.suite {
    namespace = "transport";
    compareFor =
      caller: a: b:
      comparison.order (valueOf caller a) (valueOf caller b);
  };

  # ===== Constants =====

  tcp = mk "tcp";
  udp = mk "udp";
  sctp = mk "sctp";

  # Every transport, in `compare` order.
  values = map mk names;
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
  inherit (ordering)
    compare
    ge
    gt
    le
    lt
    max
    min
    ;
}
