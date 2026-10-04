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

  mk = name: {
    _type = "interfaceName";
    value = name;
  };

  # [[:space:]] in POSIX ERE covers the six kernel-recognized whitespace
  # bytes (SP HT LF VT FF CR), matching dev_valid_name()'s isspace(3).
  hasForbiddenChar = name: builtins.match ".*[/:[:space:]].*" name != null;

  # ===== Parsing (kernel dev_valid_name parity) =====

  /*
    Validate an interface name without throwing, so callers can handle
    invalid input themselves.

    `input`: candidate name; must be non-empty, at most 15 bytes, not
    "." or "..", and free of '/', ':', and whitespace.

    Returns a tryResult: `{ success = true; value = <interfaceName>; }`
    or `{ success = false; error = <message>; }`.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.interfaceName.parse: input must be a string"
    else if input == "" then
      types.tryErr "libnet.interfaceName.parse: empty name"
    else if builtins.stringLength input >= ifnamsiz then
      types.tryErr "libnet.interfaceName.parse: name too long (max 15 bytes): \"${input}\""
    else if input == "." || input == ".." then
      types.tryErr "libnet.interfaceName.parse: reserved name \"${input}\""
    else if hasForbiddenChar input then
      types.tryErr "libnet.interfaceName.parse: name contains '/' or ':' or whitespace: \"${input}\""
    else
      types.tryOk (mk input);

  /*
    Validate an interface name the way the Linux kernel does, so invalid
    names fail at evaluation time instead of at boot.

    `input`: candidate name; must be non-empty, at most 15 bytes, not
    "." or "..", and free of '/', ':', and whitespace.

    Returns an interfaceName value; throws on kernel-invalid names.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Format an interface name as text.

    `interfaceName`: interfaceName value.

    Returns the name verbatim.
  */
  toString = interfaceName: interfaceName.value;

  # ===== Predicates =====

  /*
    Check whether a string is a kernel-valid interface name.

    `input`: candidate string.

    Returns true when `tryParse input` succeeds.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is an interfaceName value.

    `value`: any value.

    Returns true when `value` is tagged `_type = "interfaceName"`.
  */
  is = value: types.isInterfaceName value;

  # ===== Accessor =====

  /*
    Get the name string.

    `interfaceName`: interfaceName value.

    Returns the name verbatim.
  */
  value = interfaceName: interfaceName.value;

  # ===== Comparison =====
  #
  # Byte-wise on the name, case-sensitive (Linux ifnames are
  # case-sensitive).

  /*
    Test two interface names for equality, case-sensitively.

    `a`, `b`: interfaceName values.

    Returns true when both have the same type tag and name.
  */
  eq = a: b: a._type == b._type && a.value == b.value;

  /*
    Order two interface names byte-wise.

    `a`, `b`: interfaceName values.

    Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`.
  */
  compare =
    a: b:
    if a.value < b.value then
      -1
    else if a.value > b.value then
      1
    else
      0;

  /*
    Test whether one interface name sorts before another.

    `a`, `b`: interfaceName values.

    Returns true when `compare a b == -1`.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether one interface name sorts before or equal to another.

    `a`, `b`: interfaceName values.

    Returns true when `compare a b <= 0`.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether one interface name sorts after another.

    `a`, `b`: interfaceName values.

    Returns true when `compare a b == 1`.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether one interface name sorts after or equal to another.

    `a`, `b`: interfaceName values.

    Returns true when `compare a b >= 0`.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the earlier of two interface names in sort order.

    `a`, `b`: interfaceName values.

    Returns the lesser name; `a` when they compare equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the later of two interface names in sort order.

    `a`, `b`: interfaceName values.

    Returns the greater name; `a` when they compare equal.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    compare
    eq
    ge
    gt
    ifnamsiz
    is
    isValid
    le
    lt
    max
    min
    parse
    toString
    tryParse
    value
    ;
}
