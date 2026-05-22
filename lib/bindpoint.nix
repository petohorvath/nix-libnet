/*
  libnet.bindpoint

  Pass-through union over the two bind targets: `ipBindpoint` (an
  optional IP address + port range) and `unixSocket` (a socket path).
  Composed as `ipBindpoint | unixSocket`; **no new `_type` tag**. `parse`
  dispatches by shape: a leading `/` or `@` → `unixSocket`, otherwise
  the IP bindpoint form.

  Returns the underlying typed value; consumers branch on `value._type`.
  The members are heterogeneous (`ipBindpoint` has address/portRange and
  the `endpoints` materialization; `unixSocket` has a path), so this
  union exposes predicates + `toString` + comparison. Branch with
  `isIpBindpoint` / `isUnixSocket` and use the member module's API.

    bindpoint = ipBindpoint | unixSocket

  The local-bind peer of `endpoint` (the connect-side union). `bindUrl`
  adds a transport tag on top, mirroring how `socketUrl` tags `endpoint`.

  Example:
    libnet.bindpoint.parse ":8080"           # tagged ipBindpoint
    libnet.bindpoint.parse "/run/foo.sock"   # tagged unixSocket
*/
let
  types = import ./internal/types.nix;
  parse' = import ./internal/parse.nix;
  ipBindpoint = import ./ip-bindpoint.nix;
  unixSocket = import ./unix-socket.nix;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.bindpoint.parse: input must be a string"
    else if parse'.startsWith "/" s || parse'.startsWith "@" s then
      unixSocket.tryParse s
    else
      ipBindpoint.tryParse s;

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    bp:
    if types.isIpBindpoint bp then
      ipBindpoint.toString bp
    else if types.isUnixSocket bp then
      unixSocket.toString bp
    else
      builtins.throw "libnet.bindpoint.toString: expected ipBindpoint or unixSocket value";

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = v: types.isIpBindpoint v || types.isUnixSocket v;
  isIpBindpoint = types.isIpBindpoint;
  isUnixSocket = types.isUnixSocket;

  # ===== Comparison =====
  #
  # Cross-kind order: ipBindpoint < unixSocket. Within a kind, delegates.

  rank =
    v:
    if types.isIpBindpoint v then
      0
    else if types.isUnixSocket v then
      1
    else
      builtins.throw "libnet.bindpoint.compare: expected ipBindpoint or unixSocket value";

  eq =
    a: b:
    if types.isIpBindpoint a && types.isIpBindpoint b then
      ipBindpoint.eq a b
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
      ipBindpoint.compare a b
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
    isIpBindpoint
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
