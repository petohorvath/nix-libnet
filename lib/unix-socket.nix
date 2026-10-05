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
    => { _type = "unixSocket"; path = "/run/postgresql/.s.PGSQL.5432"; }

    libnet.unixSocket.isAbstract (libnet.unixSocket.parse "@foo")
    => true
*/
let
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;

  # Linux sun_path is a 108-byte buffer. Pathname sockets need a NUL
  # terminator (path ≤ 107); an abstract socket spends the first byte
  # on the leading NUL the `@` represents (displayed form ≤ 108).
  sunPathMax = 108;

  mk = socketPath: {
    _type = "unixSocket";
    path = socketPath;
  };

  isPathnameString =
    input:
    let
      length = builtins.stringLength input;
    in
    parsing.startsWith "/" input && length >= 2 && length <= sunPathMax - 1;

  isAbstractString =
    input:
    let
      length = builtins.stringLength input;
    in
    parsing.startsWith "@" input && length >= 2 && length <= sunPathMax;

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
      types.tryErr "libnet.unixSocket.parse: input must be a string"
    else if isPathnameString input || isAbstractString input then
      types.tryOk (mk input)
    else
      types.tryErr "libnet.unixSocket.parse: invalid socket \"${input}\" (expected an absolute path '/...' (<=107 bytes) or an abstract name '@...' (<=108 bytes))";

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
  toString = unixSocket: unixSocket.path;

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
  isPathname = unixSocket: parsing.startsWith "/" unixSocket.path;

  /*
    Check whether a Unix socket is in the Linux abstract namespace.

    `unixSocket`: unixSocket value.

    Returns true when the path starts with `@`.
  */
  isAbstract = unixSocket: parsing.startsWith "@" unixSocket.path;

  # ===== Accessor =====

  /*
    Get the socket path.

    `unixSocket`: unixSocket value.

    Returns the path string, with a leading `@` for abstract sockets.
  */
  path = unixSocket: unixSocket.path;

  # ===== Comparison =====
  #
  # Byte-wise on the path; case-sensitive (filesystem paths are).

  /*
    Compare two Unix sockets for equality.

    `a`, `b`: unixSocket values.

    Returns true when both carry the same type tag and path.
  */
  eq = a: b: types.hasSameTag a b && a.path == b.path;

  /*
    Order two Unix sockets byte-wise by path.

    `a`, `b`: unixSocket values.

    Returns -1, 0, or 1 when `a` sorts before, equal to, or after `b`.
  */
  compare =
    a: b:
    if a.path < b.path then
      -1
    else if a.path > b.path then
      1
    else
      0;

  /*
    Test whether `a` sorts strictly before `b`.

    `a`, `b`: unixSocket values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` sorts before or equal to `b`.

    `a`, `b`: unixSocket values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` sorts strictly after `b`.

    `a`, `b`: unixSocket values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` sorts after or equal to `b`.

    `a`, `b`: unixSocket values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two Unix sockets.

    `a`, `b`: unixSocket values.

    Returns the one that sorts first; `a` when they are equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two Unix sockets.

    `a`, `b`: unixSocket values.

    Returns the one that sorts last; `a` when they are equal.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    compare
    eq
    ge
    gt
    is
    isAbstract
    isPathname
    isValid
    le
    lt
    max
    min
    parse
    path
    sunPathMax
    toString
    tryParse
    ;
}
