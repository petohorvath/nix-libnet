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

  Userinfo is validated against the RFC 3986 grammar and stored
  verbatim — no percent-decoding or normalization.
  Bounded like the URL forms: no scheme, path, query, or fragment.

    { _type = "authority"; userinfo = <string | null>;
      host = <ipv4 | ipv6 | regName>; port = <port value | null>; }

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
  errors = import ./internal/errors.nix;
  comparison = import ./internal/comparison.nix;

  # Check the authority argument of `function`, throwing for any other
  # kind.
  authorityArgument =
    function: authority: errors.expectKind "authority.${function}" "authority" authority;

  # RFC 3986 §3.2.1: userinfo = *( unreserved / pct-encoded / sub-delims /
  # ":" ). The bracket expression admits only ASCII, so a non-ASCII byte,
  # a space or a control character fails the match.
  userinfoPattern = "([-A-Za-z0-9._~!$&'()*+,;=:]|%[0-9A-Fa-f][0-9A-Fa-f])*";

  isUserinfo = text: builtins.match userinfoPattern text != null;

  parseError = detail: types.tryErr (errors.message "authority.parse" detail);

  mk =
    userinfoValue: hostValue: portValue:
    types.mkStrict "authority" {
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
    multiple `@`, userinfo outside the RFC 3986 grammar, or a bad port.
    Never throws.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError (errors.notString input)
    else
      let
        atParts = parsing.splitOn "@" input;
        atPartCount = builtins.length atParts;
      in
      if atPartCount > 2 then
        parseError "malformed userinfo (multiple '@')"
      else
        let
          userinfoValue = if atPartCount == 2 then builtins.elemAt atParts 0 else null;
          hostPort = splitHostPort (builtins.elemAt atParts (atPartCount - 1));
        in
        if userinfoValue != null && !(isUserinfo userinfoValue) then
          parseError "invalid userinfo \"${userinfoValue}\""
        else if hostPort == null then
          parseError "malformed authority \"${input}\""
        else
          let
            hostResult = urlHost.tryParse hostPort.hostText;
            portResult = if hostPort.portText == null then null else port.tryParse hostPort.portText;
          in
          if !hostResult.success then
            parseError "invalid host \"${hostPort.hostText}\""
          else if portResult != null && !portResult.success then
            parseError "invalid port \"${hostPort.portText}\""
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
      checked = authorityArgument "toString" authority;
      userinfoPart = if checked.userinfo == null then "" else "${checked.userinfo}@";
      portPart = if checked.port == null then "" else ":${port.toString checked.port}";
    in
    "${userinfoPart}${urlHost.toString checked.host}${portPart}";

  # ===== Construction =====

  /*
    Build an authority from its parts; pass a whole authority string to
    `parse` instead.

    `host`: urlHost value (ipv4, ipv6, or regName).
    `userinfo`: raw userinfo string, or null (default). It must match the
    RFC 3986 userinfo grammar, as `parse` requires, and is stored as
    given.
    `port`: port value, or null (default) to omit it.

    Returns an authority value that `parse (toString …)` gives back;
    throws for a non-set argument, a missing or unexpected attribute, a
    non-urlHost host, invalid userinfo, or a non-port port.
  */
  make =
    arguments:
    let
      caller = "authority.make";
      checked = errors.expectFields caller {
        required = [ "host" ];
        optional = [
          "port"
          "userinfo"
        ];
      } arguments;
      hostValue = errors.expect caller "ip or regName value" types.isUrlHost checked.host;
      userinfoValue = errors.expect caller "string or null" (
        value: value == null || builtins.isString value
      ) (checked.userinfo or null);
      portValue = errors.expect caller "port value or null" (value: value == null || types.isPort value) (
        checked.port or null
      );
    in
    if userinfoValue != null && !(isUserinfo userinfoValue) then
      errors.fail caller "invalid userinfo \"${userinfoValue}\""
    else
      mk userinfoValue hostValue portValue;

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
  userinfo = authority: (authorityArgument "userinfo" authority).userinfo;

  /*
    Get the host of an authority.

    `authority`: an authority value.

    Returns the urlHost value: an ipv4, ipv6, or regName value.
  */
  host = authority: (authorityArgument "host" authority).host;

  # ===== Comparison =====
  #
  # Structural: host, then port, then userinfo. Unlike `url`, userinfo
  # *is* part of identity here — an authority is exactly
  # `[userinfo@]host[:port]` — and the port is compared as-stored, since
  # an authority has no scheme and therefore no default port.

  # Order nullable values with null first, the rest by `compareValues`.
  compareOptional =
    compareValues: a: b:
    if a == null && b == null then
      0
    else if a == null then
      -1
    else if b == null then
      1
    else
      compareValues a b;

  portEq =
    a: b:
    if a == null && b == null then
      true
    else if a == null || b == null then
      false
    else
      port.eq a b;

  /*
    Test two authorities for equality.

    `a`, `b`: values to compare.

    Returns true when userinfo matches exactly, hosts are equal, and
    ports match as stored (null equals only null); false for values of
    other kinds.
  */
  eq =
    a: b:
    types.bothHaveTag types.tags.authority a b
    && a.userinfo == b.userinfo
    && urlHost.eq a.host b.host
    && portEq a.port b.port;

  # Order by host, then port (null first), then userinfo (null first).
  # The operands are checked first, so the delegated comparisons cannot
  # fail and name themselves.
  ordering = comparison.suite (
    function: a: b:
    let
      left = authorityArgument function a;
      right = authorityArgument function b;
    in
    comparison.lexicographic [
      (urlHost.compare left.host right.host)
      (compareOptional port.compare left.port right.port)
      (compareOptional comparison.order left.userinfo right.userinfo)
    ]
  );
in
{
  inherit
    eq
    host
    is
    isValid
    make
    parse
    toString
    tryParse
    userinfo
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

  # Defined here rather than in `let`, where `port` names the
  # port module.
  /*
    Get the explicit port of an authority.

    `authority`: an authority value.

    Returns the port value, or null when omitted (no default applies).
  */
  port = authority: (authorityArgument "port" authority).port;
}
