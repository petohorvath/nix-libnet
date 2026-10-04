/*
  libnet.authority

  The authority component of a URL (RFC 3986 §3.2):
  `[userinfo@]<host>[:port]`. The shared core of `libnet.url`, which is
  `<scheme>://<authority>[/path][?query][#fragment]`; extracted so the
  authority can be parsed and compared on its own.

  - `host` is a `libnet.urlHost` (RFC 3986 IP-literal / IPv4 / reg-name;
    looser than `libnet.host`).
  - `userinfo` is kept raw and opaque (may carry credentials).
  - `port` is an explicit `port` value, or null when omitted.

  Components are stored verbatim — no percent-decoding or normalization.
  Bounded like the URL forms: no scheme, path, query, or fragment.

    { _type = "authority"; userinfo = <string | null>;
      host = <urlHost value>; port = <port value | null>; }

  Example:
    libnet.authority.parse "user@example.com:8443"
    => { _type = "authority"; userinfo = "user";
         host = <urlHost example.com>; port = <port 8443>; }
*/
let
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;
  urlHost = import ./url-host.nix;
  port = import ./port.nix;

  mkPort = port.fromInt;

  mk = userinfoValue: hostValue: portValue: {
    _type = "authority";
    userinfo = userinfoValue;
    host = hostValue;
    port = portValue;
  };

  # ===== Parsing =====

  # Split "host[:port]" into { hostText; portText }, or null if malformed.
  # A bracketed IPv6 literal (`[::1]:80`) is handled so the colons inside
  # it are not mistaken for the port separator.
  splitHostPort =
    hostPort:
    if parsing.startsWith "[" hostPort then
      let
        parts = parsing.splitOn "]" hostPort;
      in
      if builtins.length parts < 2 then
        null
      else
        let
          hostText = (builtins.elemAt parts 0) + "]";
          after = builtins.concatStringsSep "]" (builtins.tail parts);
        in
        if after == "" then
          {
            inherit hostText;
            portText = null;
          }
        else if parsing.startsWith ":" after then
          {
            inherit hostText;
            portText = parsing.stripPrefix ":" after;
          }
        else
          null
    else
      let
        parts = parsing.splitOn ":" hostPort;
        n = builtins.length parts;
      in
      if n == 1 then
        {
          hostText = hostPort;
          portText = null;
        }
      else if n == 2 then
        {
          hostText = builtins.elemAt parts 0;
          portText = builtins.elemAt parts 1;
        }
      else
        null;

  /*
    Parse an authority without throwing, for callers that branch on
    validity.

    `input`: `[userinfo@]host[:port]` text; the host may be a bracketed IPv6
    literal.

    Returns a tryResult: `{ success = true; value = <authority>; }` or
    `{ success = false; error = <string>; }` for an empty or invalid host,
    multiple `@`, or a bad port. Never throws.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.authority.parse: input must be a string"
    else
      let
        atParts = parsing.splitOn "@" input;
        atPartCount = builtins.length atParts;
      in
      if atPartCount > 2 then
        types.tryErr "libnet.authority.parse: malformed userinfo (multiple '@')"
      else
        let
          userinfoValue = if atPartCount == 2 then builtins.elemAt atParts 0 else null;
          hostPort = splitHostPort (builtins.elemAt atParts (atPartCount - 1));
        in
        if hostPort == null then
          types.tryErr "libnet.authority.parse: malformed authority \"${input}\""
        else
          let
            hostResult = urlHost.tryParse hostPort.hostText;
            portResult = if hostPort.portText == null then null else port.tryParse hostPort.portText;
          in
          if !hostResult.success then
            types.tryErr "libnet.authority.parse: invalid host \"${hostPort.hostText}\""
          else if portResult != null && !portResult.success then
            types.tryErr "libnet.authority.parse: invalid port \"${hostPort.portText}\""
          else
            types.tryOk (
              mk userinfoValue hostResult.value (if portResult == null then null else portResult.value)
            );

  /*
    Parse an authority, for values that must be valid.

    `input`: `[userinfo@]host[:port]` text as accepted by `tryParse`.

    Returns an authority value; throws on invalid input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render an authority as `[userinfo@]host[:port]`.

    `authority`: an authority value.

    Returns the text, omitting userinfo and port when they are null.
  */
  toString =
    authority:
    let
      userinfoPart = if authority.userinfo == null then "" else "${authority.userinfo}@";
      portPart = if authority.port == null then "" else ":${port.toString authority.port}";
    in
    "${userinfoPart}${urlHost.toString authority.host}${portPart}";

  # ===== Construction =====

  /*
    Build an authority from its textual parts; pass a whole authority string
    to `parse` instead.

    `host`: URL host text, parsed with `urlHost.parse` rules.
    `userinfo`: raw userinfo string, or null (default).
    `port`: integer port, or null (default) to omit it.

    Returns an authority value; throws on an invalid host or a non-int port.
  */
  make =
    {
      host,
      userinfo ? null,
      port ? null,
    }:
    let
      hostResult = urlHost.tryParse host;
    in
    if !hostResult.success then
      throw "libnet.authority.make: invalid host \"${host}\""
    else if port != null && !(builtins.isInt port) then
      throw "libnet.authority.make: port must be an int or null"
    else
      mk userinfo hostResult.value (if port == null then null else mkPort port);

  # ===== Predicates =====

  /*
    Check whether a string parses as an authority.

    `input`: candidate authority text.

    Returns true when `tryParse` succeeds.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is an authority value.

    `value`: any value.

    Returns true for an authority-tagged attrset.
  */
  is = value: types.isAuthority value;

  # ===== Accessors =====

  /*
    Get the userinfo of an authority.

    `authority`: an authority value.

    Returns the raw userinfo string, or null when absent.
  */
  userinfo = authority: authority.userinfo;

  /*
    Get the host of an authority.

    `authority`: an authority value.

    Returns the urlHost value.
  */
  host = authority: authority.host;

  # ===== Comparison =====
  #
  # Structural: host (case-folded), then port, then userinfo. Unlike
  # `url`, userinfo *is* part of identity here — an authority is exactly
  # `[userinfo@]host[:port]` — and the port is compared as-stored, since
  # an authority has no scheme and therefore no default port.

  compareStrings =
    a: b:
    if a < b then
      -1
    else if a > b then
      1
    else
      0;

  # Order nullable strings with null first.
  compareOptionalStrings =
    a: b:
    if a == null && b == null then
      0
    else if a == null then
      -1
    else if b == null then
      1
    else
      compareStrings a b;

  portEq =
    a: b:
    if a == null && b == null then
      true
    else if a == null || b == null then
      false
    else
      port.eq a b;

  portCompare =
    a: b:
    if a == null && b == null then
      0
    else if a == null then
      -1
    else if b == null then
      1
    else
      port.compare a b;

  /*
    Test two authorities for equality.

    `a`, `b`: authority values.

    Returns true when userinfo matches exactly, hosts are equal
    (case-folded), and ports match as stored (null equals only null).
  */
  eq =
    a: b:
    a._type == b._type && a.userinfo == b.userinfo && urlHost.eq a.host b.host && portEq a.port b.port;

  /*
    Order two authorities by host, then port (null first), then userinfo
    (null first).

    `a`, `b`: authority values.

    Returns -1, 0, or 1.
  */
  compare =
    a: b:
    let
      hostOrder = urlHost.compare a.host b.host;
    in
    if hostOrder != 0 then
      hostOrder
    else
      let
        portOrder = portCompare a.port b.port;
      in
      if portOrder != 0 then portOrder else compareOptionalStrings a.userinfo b.userinfo;

  /*
    Check whether one authority sorts before another.

    `a`, `b`: authority values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Check whether one authority sorts before or equal to another.

    `a`, `b`: authority values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Check whether one authority sorts after another.

    `a`, `b`: authority values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Check whether one authority sorts after or equal to another.

    `a`, `b`: authority values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two authorities by `compare`.

    `a`, `b`: authority values.

    Returns `a` when it sorts first or equal, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two authorities by `compare`.

    `a`, `b`: authority values.

    Returns `a` when it sorts last or equal, otherwise `b`.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    compare
    eq
    ge
    gt
    host
    is
    isValid
    le
    lt
    make
    max
    min
    parse
    toString
    tryParse
    userinfo
    ;

  /*
    Get the explicit port of an authority.

    `authority`: an authority value.

    Returns the port value, or null when omitted (no default applies).
  */
  port = authority: authority.port;
}
