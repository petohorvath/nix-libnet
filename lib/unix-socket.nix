/*
  libnet.unixSocket

  A Unix domain socket address — a complete connection target with no
  port (the path IS the address). Symmetric: the same value is used to
  bind (listen) and to dial (connect). A peer of `ipEndpoint` /
  `dnsEndpoint` at the complete-target level, and a member of both the
  `endpoint` and `listener` unions.

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
  parse' = import ./internal/parse.nix;

  # Linux sun_path is a 108-byte buffer. Pathname sockets need a NUL
  # terminator (path ≤ 107); an abstract socket spends the first byte
  # on the leading NUL the `@` represents (displayed form ≤ 108).
  sunPathMax = 108;

  mk = p: {
    _type = "unixSocket";
    path = p;
  };

  isPathnameStr =
    s:
    let
      len = builtins.stringLength s;
    in
    parse'.startsWith "/" s && len >= 2 && len <= sunPathMax - 1;

  isAbstractStr =
    s:
    let
      len = builtins.stringLength s;
    in
    parse'.startsWith "@" s && len >= 2 && len <= sunPathMax;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.unixSocket.parse: input must be a string"
    else if isPathnameStr s || isAbstractStr s then
      types.tryOk (mk s)
    else
      types.tryErr "libnet.unixSocket.parse: invalid socket \"${s}\" (expected an absolute path '/...' (<=107 bytes) or an abstract name '@...' (<=108 bytes))";

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString = sock: sock.path;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isUnixSocket;
  isPathname = sock: parse'.startsWith "/" sock.path;
  isAbstract = sock: parse'.startsWith "@" sock.path;

  # ===== Accessor =====

  path = sock: sock.path;

  # ===== Comparison =====
  #
  # Byte-wise on the path; case-sensitive (filesystem paths are).

  eq = a: b: a.path == b.path;

  compare =
    a: b:
    if a.path < b.path then
      -1
    else if a.path > b.path then
      1
    else
      0;

  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;
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
    isPathname
    isAbstract
    ;
  inherit path;
  inherit
    eq
    lt
    le
    gt
    ge
    compare
    min
    max
    ;
  inherit sunPathMax;
}
