/*
  libnet.interfaceName

  A Linux network interface name (ifname): `eth0`, `wg0`, `br-lan`, … —
  the NIC identifier. Validation mirrors the kernel's dev_valid_name()
  (net/core/dev.c): non-empty, length < IFNAMSIZ (16, so <= 15 bytes on
  the wire), not "." or "..", and containing no '/', no ':', and no
  byte that the kernel's isspace() treats as space: 9 to 13 (HT LF VT FF
  CR), 32 (SP) and 160 (NBSP in Latin-1). Names are case-sensitive and
  keep their case.

  The address-on-subnet counterpart (`192.168.1.10/24`) is a separate
  type: `libnet.interfaceAddress`.

  Example:
    libnet.interfaceName.parse "eth0"
    => { _type = "interfaceName"; value = "eth0"; }
*/
let
  types = import ./internal/types.nix;
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  comparison = import ./internal/comparison.nix;

  # IFNAMSIZ from <linux/if.h> is a 16-byte buffer including the
  # terminating NUL, so a valid name has at most 15 bytes.
  maxLength = 15;

  mk = name: {
    _type = "interfaceName";
    value = name;
  };

  /*
    The bytes dev_valid_name() rejects besides the length and dot rules:
    '/', ':' and every byte the kernel's isspace() accepts, which unlike
    isspace(3) in the C locale includes byte 160. Nix string literals
    cannot spell VT, FF or a lone byte 160, so they are decoded from JSON;
    byte 160 is the second byte of the UTF-8 encoding of U+00A0.
  */
  forbiddenBytes = [
    "/"
    ":"
    "\t"
    "\n"
    (builtins.fromJSON ''"\u000b"'')
    (builtins.fromJSON ''"\u000c"'')
    "\r"
    " "
    (builtins.substring 1 1 (builtins.fromJSON ''"\u00a0"''))
  ];

  hasForbiddenByte =
    name:
    builtins.any (i: builtins.elem (builtins.substring i 1 name) forbiddenBytes) (
      builtins.genList (i: i) (builtins.stringLength name)
    );

  # The stored name of an interfaceName argument of `function`.
  valueOf =
    function: name: (errors.expectKind "interfaceName.${function}" "interfaceName" name).value;

  # ===== Parsing (kernel dev_valid_name parity) =====

  /*
    Validate an interface name: the detail parser of the parsing suite.

    `input`: candidate name; must be non-empty, at most 15 bytes, not
    "." or "..", and free of '/', ':', and the kernel's space bytes.

    Returns a tryResult holding an interfaceName value, or the detail of
    the failure.
  */
  tryParseDetail =
    input:
    if input == "" then
      types.tryErr "empty name"
    else if builtins.stringLength input > maxLength then
      types.tryErr "name too long (max ${builtins.toString maxLength} bytes): \"${input}\""
    else if input == "." || input == ".." then
      types.tryErr "reserved name \"${input}\""
    else if hasForbiddenByte input then
      types.tryErr "name contains '/', ':' or a space byte: \"${input}\""
    else
      types.tryOk (mk input);

  parsers = parsing.suite "interfaceName" tryParseDetail;

  /*
    Format an interface name as text.

    `interfaceName`: interfaceName value.

    Returns the name verbatim.
  */
  toString = valueOf "toString";

  # ===== Predicates =====

  /*
    Check whether a value is an interfaceName value.

    `value`: any value.

    Returns true when `value` is tagged `_type = "interfaceName"`.
  */
  is = value: types.isInterfaceName value;

  # ===== Comparison =====
  #
  # Byte-wise on the name, case-sensitive (Linux ifnames are
  # case-sensitive).

  /*
    Test two interface names for equality, case-sensitively.

    `a`, `b`: interfaceName values.

    Returns true when both have the same type tag and name.
  */
  eq = a: b: types.bothHaveTag types.tags.interfaceName a b && a.value == b.value;

  ordering = comparison.suite (
    function: a: b:
    comparison.order (valueOf function a) (valueOf function b)
  );
in
{
  inherit
    eq
    is
    maxLength
    toString
    ;
  inherit (parsers)
    isValid
    parse
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
