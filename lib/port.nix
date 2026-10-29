/*
  libnet.port

  Validate and manipulate TCP/UDP port numbers (0..65535). Predicates
  classify ports as well-known (0..1023), registered (1024..49151),
  or dynamic / ephemeral (49152..65535).

  The bounded-integer suite (parsing, comparison, arithmetic) comes from
  `internal/bounded-int.nix`, shared with `vlanId`, `mtu` and `icmpType`;
  this module adds the RFC 6335 classes.

  Note: `diff a b` returns `toInt b - toInt a` (second arg minus first),
  matching the other scalar modules (ipv4, ipv6, mac) for consistency.

  Example:
    libnet.port.parse "8080"
    => { _type = "port"; value = 8080; }

    libnet.port.isDynamic (libnet.port.parse "50000")
    => true
*/
let
  errors = import ./internal/errors.nix;

  boundedInt = import ./internal/bounded-int.nix {
    typeName = "port";
    minValue = 0;
    maxValue = 65535;
    arithmetic = true;
  };

  # Upper ends of the RFC 6335 well-known and registered ranges.
  wellKnownMax = 1023;
  registeredMax = 49151;

  # Unwrap the port argument of `function`, throwing for any other kind.
  valueOf = function: port: (errors.expectKind "port.${function}" "port" port).value;

  # ===== Predicates =====

  /*
    Check whether a port is in the RFC 6335 well-known range.

    `port`: port value.

    Returns true for ports 0..1023.
  */
  isWellKnown = port: valueOf "isWellKnown" port <= wellKnownMax;

  /*
    Check whether a port is in the RFC 6335 registered range.

    `port`: port value.

    Returns true for ports 1024..49151.
  */
  isRegistered =
    port:
    let
      value = valueOf "isRegistered" port;
    in
    value > wellKnownMax && value <= registeredMax;

  /*
    Check whether a port is in the RFC 6335 dynamic (ephemeral) range.

    `port`: port value.

    Returns true for ports 49152..65535.
  */
  isDynamic = port: valueOf "isDynamic" port > registeredMax;

  /*
    Check whether a port is the reserved port 0 (RFC 6335). Port 0 also
    satisfies `isWellKnown`; these classes are not a partition.

    `port`: port value.

    Returns true only for port 0.
  */
  isReserved = port: valueOf "isReserved" port == 0;
in
boundedInt
// {
  inherit
    isDynamic
    isRegistered
    isReserved
    isWellKnown
    ;
}
