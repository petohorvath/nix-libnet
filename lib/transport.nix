/*
  libnet.transport

  Validated transport-protocol enum. Tagged value parallel to
  libnet.port, restricted to TCP, UDP, and SCTP (the three transport
  protocols recognised by Linux netfilter / nftables). No ordering or
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

  mk = v: {
    _type = "transport";
    value = v;
  };

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.transport.parse: input must be a string"
    else if !(builtins.elem s values) then
      types.tryErr "libnet.transport.parse: unknown protocol \"${s}\" (expected one of: tcp, udp, sctp)"
    else
      types.tryOk (mk s);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString = p: p.value;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isTransport;

  isTcp = p: p.value == "tcp";
  isUdp = p: p.value == "udp";
  isSctp = p: p.value == "sctp";

  # ===== Comparison =====
  #
  # Only `eq` is provided. Transport protocols have no canonical order,
  # so `lt` / `compare` / `min` / `max` would have to invent one. Users
  # who need to sort a list of transports can sort on `.value` directly.

  eq = a: b: a.value == b.value;

  # ===== Constants =====

  tcp = mk "tcp";
  udp = mk "udp";
  sctp = mk "sctp";
in
{
  inherit
    parse
    tryParse
    toString
    ;
  inherit
    isValid
    is
    isTcp
    isUdp
    isSctp
    ;
  inherit eq;
  inherit
    tcp
    udp
    sctp
    values
    ;
}
