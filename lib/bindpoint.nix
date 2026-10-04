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

  No DNS-name member (unlike `endpoint`): you bind to a local address,
  not a name — `localhost` and other names are rejected; use
  `127.0.0.1` / `[::1]` for a loopback bind.

  Example:
    libnet.bindpoint.parse ":8080"           # tagged ipBindpoint
    libnet.bindpoint.parse "/run/foo.sock"   # tagged unixSocket
*/
let
  types = import ./internal/types.nix;
  parsing = import ./internal/parse.nix;
  ipBindpoint = import ./ip-bindpoint.nix;
  unixSocket = import ./unix-socket.nix;

  # ===== Parsing =====

  /*
    Parse any bind target without throwing, classifying it by shape.

    `input`: a unix socket path (leading `/` or `@`), or any form
    `ipBindpoint.parse` accepts, such as `":8080"` or
    `"[::1]:8000-8100"`.

    Returns a tryResult whose value is an ipBindpoint or unixSocket; on
    failure, `error` comes from the member parser that was tried.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.bindpoint.parse: input must be a string"
    else if parsing.startsWith "/" input || parsing.startsWith "@" input then
      unixSocket.tryParse input
    else
      ipBindpoint.tryParse input;

  /*
    Parse any bind target, classifying it by shape as `tryParse` does.

    `input`: a unix socket path, or an IP bindpoint form such as
    `":8080"`.

    Returns an ipBindpoint or unixSocket value; throws on malformed
    input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render any bindpoint member in its canonical text form.

    `bindpoint`: ipBindpoint or unixSocket value.

    Returns the member module's `toString` output; throws for other
    values.
  */
  toString =
    bindpoint:
    if types.isIpBindpoint bindpoint then
      ipBindpoint.toString bindpoint
    else if types.isUnixSocket bindpoint then
      unixSocket.toString bindpoint
    else
      throw "libnet.bindpoint.toString: expected ipBindpoint or unixSocket value";

  # ===== Predicates =====

  /*
    Test whether a string parses as any bindpoint member.

    `input`: value to test; non-strings yield false.

    Returns a Boolean.
  */
  isValid = input: (tryParse input).success;

  /*
    Test whether a value is an ipBindpoint or unixSocket.

    `value`: any value.

    Returns a Boolean.
  */
  is = value: types.isIpBindpoint value || types.isUnixSocket value;

  /*
    Test whether a value is an ipBindpoint.

    `value`: any value.

    Returns a Boolean.
  */
  isIpBindpoint = value: types.isIpBindpoint value;

  /*
    Test whether a value is a unixSocket.

    `value`: any value.

    Returns a Boolean.
  */
  isUnixSocket = value: types.isUnixSocket value;

  # ===== Comparison =====
  #
  # Cross-kind order: ipBindpoint < unixSocket. Within a kind, delegates.

  rank =
    value:
    if types.isIpBindpoint value then
      0
    else if types.isUnixSocket value then
      1
    else
      throw "libnet.bindpoint.compare: expected ipBindpoint or unixSocket value";

  /*
    Test two bindpoints for equality using their member module's `eq`.

    `a`, `b`: values to compare.

    Returns a Boolean; false when the two are different kinds.
  */
  eq =
    a: b:
    if types.isIpBindpoint a && types.isIpBindpoint b then
      ipBindpoint.eq a b
    else if types.isUnixSocket a && types.isUnixSocket b then
      unixSocket.eq a b
    else
      false;

  /*
    Order two bindpoints by kind (ipBindpoint < unixSocket), then by the
    member module's `compare`.

    `a`, `b`: bindpoint member values.

    Returns `-1`, `0`, or `1`; throws if either is not a bindpoint
    member.
  */
  compare =
    a: b:
    let
      rankA = rank a;
      rankB = rank b;
    in
    if rankA < rankB then
      -1
    else if rankA > rankB then
      1
    else if rankA == 0 then
      ipBindpoint.compare a b
    else
      unixSocket.compare a b;

  /*
    Test whether `a` orders strictly before `b` under `compare`.

    `a`, `b`: bindpoint member values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` orders before or equal to `b` under `compare`.

    `a`, `b`: bindpoint member values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` orders strictly after `b` under `compare`.

    `a`, `b`: bindpoint member values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` orders after or equal to `b` under `compare`.

    `a`, `b`: bindpoint member values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two bindpoints under `compare`.

    `a`, `b`: bindpoint member values.

    Returns `a` when they order equal, otherwise the lesser value.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two bindpoints under `compare`.

    `a`, `b`: bindpoint member values.

    Returns `a` when they order equal, otherwise the greater value.
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
    isIpBindpoint
    isUnixSocket
    isValid
    le
    lt
    max
    min
    parse
    toString
    tryParse
    ;
}
