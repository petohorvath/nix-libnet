/*
  libnet.unixSocket

  A Unix domain socket address — a complete connection target with no
  port (the path IS the address). Symmetric: the same value is used to
  bind (listen) and to dial (connect). A peer of `ipEndpoint` /
  `dnsEndpoint` at the complete-target level, and a member of both the
  `endpoint` and `bindpoint` unions.

  Two forms:
  - pathname: an absolute filesystem path (`/run/foo.sock`), ≤ 107
    bytes (Linux `sun_path` is 108 bytes including the NUL terminator).
  - abstract: a Linux abstract-namespace name shown with a leading `@`
    (`@foo`); the `@` stands for the leading NUL byte, so the displayed
    form is ≤ 108 bytes.

  No port, no arithmetic. Comparison is byte-wise on the path
  (case-sensitive — filesystem paths are).

  Example:
    libnet.unixSocket.parse "/run/postgresql/.s.PGSQL.5432"
    => { _type = "unixSocket"; value = "/run/postgresql/.s.PGSQL.5432"; }

    libnet.unixSocket.isAbstract (libnet.unixSocket.parse "@foo")
    => true
*/
let
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;

  # Linux sun_path is a 108-byte buffer. Pathname sockets need a NUL
  # terminator (path ≤ 107); an abstract socket spends the first byte
  # on the leading NUL the `@` represents (displayed form ≤ 108).
  pathnameMaxLength = 107;
  abstractMaxLength = 108;

  mk = value: {
    _type = "unixSocket";
    inherit value;
  };

  # Unwrap the socket argument of `function`, throwing for any other kind.
  valueOf =
    function: unixSocket: (errors.expectKind "unixSocket.${function}" "unixSocket" unixSocket).value;

  parseError = detail: types.tryErr (errors.message "unixSocket.parse" detail);

  isPathnameString =
    input:
    let
      length = builtins.stringLength input;
    in
    parsing.startsWith "/" input && length >= 2 && length <= pathnameMaxLength;

  isAbstractString =
    input:
    let
      length = builtins.stringLength input;
    in
    parsing.startsWith "@" input && length >= 2 && length <= abstractMaxLength;

  # ===== Parsing =====

  /*
    Parse a Unix socket address without throwing, for callers that want
    to report or recover from invalid input.

    `input`: an absolute path `/...` (2-107 bytes) or an abstract name
    `@...` (2-108 bytes).

    Returns a tryResult: `{ success = true; value; }` with a unixSocket
    value, or `{ success = false; error; }` describing the problem.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else if isPathnameString input || isAbstractString input then
      types.tryOk (mk input)
    else
      parseError "invalid socket \"${input}\" (expected an absolute path '/...' (<=107 bytes) or an abstract name '@...' (<=108 bytes))";

  /*
    Parse a Unix socket address.

    `input`: an absolute path `/...` (2-107 bytes) or an abstract name
    `@...` (2-108 bytes).

    Returns a unixSocket value; throws on a non-string or invalid path.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a Unix socket as its path.

    `unixSocket`: unixSocket value.

    Returns the path, with a leading `@` for abstract sockets.
  */
  toString = valueOf "toString";

  # ===== Predicates =====

  /*
    Check whether a string parses as a Unix socket, without throwing.

    `input`: value to check.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a unixSocket value.

    `value`: any value; non-attrsets are accepted and yield false.

    Returns true for an attrset tagged `_type = "unixSocket"`, false
    otherwise; other fields are not checked.
  */
  is = value: types.isUnixSocket value;

  /*
    Check whether a Unix socket is a filesystem pathname socket.

    `unixSocket`: unixSocket value.

    Returns true when the path starts with `/`.
  */
  isPathname = unixSocket: parsing.startsWith "/" (valueOf "isPathname" unixSocket);

  /*
    Check whether a Unix socket is in the Linux abstract namespace.

    `unixSocket`: unixSocket value.

    Returns true when the path starts with `@`.
  */
  isAbstract = unixSocket: parsing.startsWith "@" (valueOf "isAbstract" unixSocket);

  # ===== Comparison =====
  #
  # Byte-wise on the path; case-sensitive (filesystem paths are). Each
  # ordering function passes its own name, which its errors report.

  compareFor =
    function: a: b:
    comparison.order (valueOf function a) (valueOf function b);

  ordering = comparison.suite compareFor;

  /*
    Compare two Unix sockets for equality.

    `a`, `b`: unixSocket values.

    Returns true when both carry the same type tag and path.
  */
  eq = a: b: types.bothHaveTag types.tags.unixSocket a b && a.value == b.value;
in
{
  inherit
    eq
    is
    isAbstract
    isPathname
    isValid
    parse
    toString
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
