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
  parsing = import ./internal/parse.nix;
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

  # The protocol name of a transport argument of `function`.
  valueOf =
    function: transport: (errors.expectKind "transport.${function}" "transport" transport).value;

  # ===== Parsing =====

  /*
    Parse a transport protocol name: the detail parser of the parsing
    suite.

    `input`: protocol name, one of "tcp", "udp", or "sctp"
    (case-sensitive).

    Returns a tryResult holding a transport value, or the detail of the
    failure.
  */
  tryParseDetail =
    input:
    if !(builtins.elem input names) then
      types.tryErr "unknown protocol \"${input}\" (expected one of: tcp, udp, sctp)"
    else
      types.tryOk (mk input);

  parsers = parsing.suite "transport" tryParseDetail;

  /*
    Render a transport as its protocol name.

    `transport`: transport value.

    Returns "tcp", "udp", or "sctp".
  */
  toString = valueOf "toString";

  # ===== Predicates =====

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
  isTcp = transport: valueOf "isTcp" transport == "tcp";

  /*
    Check whether a transport is UDP.

    `transport`: transport value.

    Returns true for `udp`.
  */
  isUdp = transport: valueOf "isUdp" transport == "udp";

  /*
    Check whether a transport is SCTP.

    `transport`: transport value.

    Returns true for `sctp`.
  */
  isSctp = transport: valueOf "isSctp" transport == "sctp";

  # ===== Comparison =====
  #
  # Transport protocols have no natural order, so they sort by name
  # (`sctp < tcp < udp`), for determinism only.

  /*
    Compare two transports for equality.

    `a`, `b`: transport values.

    Returns true when both carry the same type tag and protocol.
  */
  eq = a: b: types.bothHaveTag types.tags.transport a b && a.value == b.value;

  ordering = comparison.suite (
    function: a: b:
    comparison.order (valueOf function a) (valueOf function b)
  );

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
    sctp
    tcp
    toString
    udp
    values
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
}
