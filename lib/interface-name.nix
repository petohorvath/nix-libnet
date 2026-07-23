/*
  libnet.interfaceName

  A Linux network interface name (ifname): `eth0`, `wg0`, `br-lan`, … —
  the NIC identifier. Validation mirrors the kernel's dev_valid_name()
  (net/core/dev.c): non-empty, length < IFNAMSIZ (16, so <= 15 bytes on
  the wire), not "." or "..", and containing no '/', no ':', and no
  whitespace (any isspace(3) byte: SP HT LF VT FF CR).

  The address-on-subnet counterpart (`192.168.1.10/24`) is a separate
  type: `libnet.interfaceAddress`.

  Example:
    libnet.interfaceName.parse "eth0"
    => { _type = "interfaceName"; value = "eth0"; }
*/
let
  types = import ./internal/types.nix;

  # IFNAMSIZ from <linux/if.h>: the kernel stores names in a 16-byte
  # buffer including the terminating NUL, so the on-wire length is < 16.
  ifnamsiz = 16;

  mk = s: {
    _type = "interfaceName";
    value = s;
  };

  # [[:space:]] in POSIX ERE covers the six kernel-recognized whitespace
  # bytes (SP HT LF VT FF CR), matching dev_valid_name()'s isspace(3).
  hasForbiddenChar = s: builtins.match ".*[/:[:space:]].*" s != null;

  # ===== Validation (kernel dev_valid_name parity) =====

  isValid =
    s:
    builtins.isString s
    && s != ""
    && builtins.stringLength s < ifnamsiz
    && s != "."
    && s != ".."
    && !(hasForbiddenChar s);

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.interfaceName.parse: input must be a string"
    else if s == "" then
      types.tryErr "libnet.interfaceName.parse: empty name"
    else if builtins.stringLength s >= ifnamsiz then
      types.tryErr "libnet.interfaceName.parse: name too long (max 15 bytes): \"${s}\""
    else if s == "." || s == ".." then
      types.tryErr "libnet.interfaceName.parse: reserved name \"${s}\""
    else if hasForbiddenChar s then
      types.tryErr "libnet.interfaceName.parse: name contains '/' or ':' or whitespace: \"${s}\""
    else
      types.tryOk (mk s);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString = i: i.value;

  # ===== Predicates =====

  is = types.isInterfaceName;

  # ===== Accessor =====

  value = i: i.value;

  # ===== Comparison =====
  #
  # Byte-wise on the name, case-sensitive (Linux ifnames are
  # case-sensitive).

  eq = a: b: a._type == b._type && a.value == b.value;

  compare =
    a: b:
    if a.value < b.value then
      -1
    else if a.value > b.value then
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
    value
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
  inherit ifnamsiz;
}
