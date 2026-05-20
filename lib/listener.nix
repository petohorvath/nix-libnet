/*
  libnet.listener

  Pass-through union over the two bind targets: `ipListener` (an
  optional IP address + port range) and `unixSocket` (a socket path).
  Composed as `ipListener | unixSocket`; **no new `_type` tag**. `parse`
  dispatches by shape: a leading `/` or `@` → `unixSocket`, otherwise
  the IP listener form.

  Returns the underlying typed value; consumers branch on `value._type`.
  The members are heterogeneous (`ipListener` has address/portRange and
  the `endpoints` materialization; `unixSocket` has a path), so this
  union exposes predicates + `toString` + comparison. Branch with
  `isIpListener` / `isUnixSocket` and use the member module's API.

    listener = ipListener | unixSocket

  Example:
    libnet.listener.parse ":8080"           # tagged ipListener
    libnet.listener.parse "/run/foo.sock"   # tagged unixSocket
*/
let
  types = import ./internal/types.nix;
  parse' = import ./internal/parse.nix;
  ipListener = import ./ip-listener.nix;
  unixSocket = import ./unix-socket.nix;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.listener.parse: input must be a string"
    else if parse'.startsWith "/" s || parse'.startsWith "@" s then
      unixSocket.tryParse s
    else
      ipListener.tryParse s;

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    lst:
    if types.isIpListener lst then
      ipListener.toString lst
    else if types.isUnixSocket lst then
      unixSocket.toString lst
    else
      builtins.throw "libnet.listener.toString: expected ipListener or unixSocket value";

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = v: types.isIpListener v || types.isUnixSocket v;
  isIpListener = types.isIpListener;
  isUnixSocket = types.isUnixSocket;

  # ===== Comparison =====
  #
  # Cross-kind order: ipListener < unixSocket. Within a kind, delegates.

  rank =
    v:
    if types.isIpListener v then
      0
    else if types.isUnixSocket v then
      1
    else
      builtins.throw "libnet.listener.compare: expected ipListener or unixSocket value";

  eq =
    a: b:
    if types.isIpListener a && types.isIpListener b then
      ipListener.eq a b
    else if types.isUnixSocket a && types.isUnixSocket b then
      unixSocket.eq a b
    else
      false;

  compare =
    a: b:
    let
      ra = rank a;
      rb = rank b;
    in
    if ra < rb then
      -1
    else if ra > rb then
      1
    else if ra == 0 then
      ipListener.compare a b
    else
      unixSocket.compare a b;

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
    isIpListener
    isUnixSocket
    ;
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
}
