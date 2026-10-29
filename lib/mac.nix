/*
  libnet.mac

  Parse, format, and manipulate 48-bit MAC addresses. Accepts colon,
  hyphen, Cisco dotted, and bare 12-hex-char input; supports OUI/NIC
  split and EUI-64 modified form.

  Note: `diff a b` returns `toInt b - toInt a` (second arg minus first),
  matching the other scalar modules (ipv4, ipv6, port) for consistency.

  Example:
    libnet.mac.parse "a0:36:9f:1b:1e:55"
    => { _type = "mac"; value = 176028872726357; }

    libnet.mac.toString (libnet.mac.parse "a036.9f1b.1e55")
    => "a0:36:9f:1b:1e:55"
*/
let
  address = import ./internal/address.nix;
  bits = import ./internal/bits.nix;
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  formatting = import ./internal/format.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  mk = value: {
    _type = "mac";
    inherit value;
  };

  # Build a value from a checked integer, forcing the check so a bad
  # argument throws at the call rather than when the value is read.
  mkStrict = value: builtins.seq value (mk value);

  # A MAC argument of `function`, which throws for any other kind.
  macArgument = function: errors.expectKind "mac.${function}" "mac";

  valueOf = function: mac: (macArgument function mac).value;

  # Apply `f` to the integer of a MAC argument of `function`.
  withValue =
    function: f: mac:
    let
      value = valueOf function mac;
    in
    builtins.seq value (f value);

  bytesOf = value: [
    (bits.bits 40 8 value)
    (bits.bits 32 8 value)
    (bits.bits 24 8 value)
    (bits.bits 16 8 value)
    (bits.bits 8 8 value)
    (bits.bits 0 8 value)
  ];

  # Join the six bytes as lowercase hex pairs.
  hexBytes =
    separator: value: builtins.concatStringsSep separator (map formatting.hex2 (bytesOf value));

  arithmetic = address.scalar {
    typeName = "mac";
    maxValue = bits.mask48;
    format = mac: hexBytes ":" mac.value;
  };

  # An integer argument of `function` in [0, maxValue]; `outOfRange`
  # opens the error for a value outside it.
  boundedInt =
    function: outOfRange: maxValue: n:
    let
      checkedInt = errors.expectType "mac.${function}" "int" n;
    in
    if checkedInt < 0 || checkedInt > maxValue then
      errors.fail "mac.${function}" "${outOfRange} [0, ${builtins.toString maxValue}]: ${builtins.toString checkedInt}"
    else
      checkedInt;

  # ===== Conversion =====

  /*
    Build a MAC address from its 48-bit integer value.

    `value`: integer in [0, 2^48 - 1].

    Returns a mac value; throws on a non-integer or out-of-range value.
  */
  fromInt = value: mkStrict (boundedInt "fromInt" "out of range" bits.mask48 value);

  /*
    Read the 48-bit integer value of a MAC address.

    `mac`: mac value.

    Returns an integer in [0, 2^48 - 1].
  */
  toInt = valueOf "toInt";

  /*
    Build a MAC address from its six octets.

    `bytes`: list of six integers in [0, 255], most significant first.

    Returns a mac value; throws on a wrong length or an invalid byte.
  */
  fromBytes =
    bytes:
    let
      checkedBytes = address.intList "mac.fromBytes" {
        count = 6;
        part = "byte";
        maxValue = 255;
      } bytes;
    in
    mkStrict (builtins.foldl' (acc: byte: acc * 256 + byte) 0 checkedBytes);

  /*
    Split a MAC address into its six octets.

    `mac`: mac value.

    Returns a list of six integers in [0, 255], most significant first.
  */
  toBytes = withValue "toBytes" bytesOf;

  # ===== Parsing =====

  # Each parser below returns a mac value, or null when `input` is not in
  # its format.
  parseBare =
    input:
    if builtins.match "[0-9a-fA-F]{12}" input == null then
      null
    else
      let
        byte = i: parsing.hexInt (builtins.substring (i * 2) 2 input);
      in
      mk (
        builtins.foldl' (acc: i: acc * 256 + (byte i)) 0 [
          0
          1
          2
          3
          4
          5
        ]
      );

  parseCisco =
    input:
    let
      parts = parsing.splitOn "." input;
    in
    if builtins.length parts != 3 then
      null
    else
      let
        group0 = builtins.elemAt parts 0;
        group1 = builtins.elemAt parts 1;
        group2 = builtins.elemAt parts 2;
        valid =
          builtins.stringLength group0 == 4
          && builtins.stringLength group1 == 4
          && builtins.stringLength group2 == 4
          && builtins.match "[0-9a-fA-F]{4}" group0 != null
          && builtins.match "[0-9a-fA-F]{4}" group1 != null
          && builtins.match "[0-9a-fA-F]{4}" group2 != null;
      in
      if !valid then
        null
      else
        mk (
          (parsing.hexInt group0) * bits.pow2_32
          + (parsing.hexInt group1) * bits.pow2_16
          + (parsing.hexInt group2)
        );

  parseSeparated =
    separator: input:
    let
      parts = parsing.splitOn separator input;
    in
    if builtins.length parts != 6 then
      null
    else
      let
        allValid = builtins.all (
          octet: builtins.stringLength octet == 2 && builtins.match "[0-9a-fA-F]{2}" octet != null
        ) parts;
      in
      if !allValid then
        null
      else
        mk (builtins.foldl' (acc: octet: acc * 256 + (parsing.hexInt octet)) 0 parts);

  /*
    Parse a MAC address: the detail parser of the parsing suite.

    `input`: string in colon (`aa:bb:cc:dd:ee:ff`), hyphen, Cisco dotted
    (`aabb.ccdd.eeff`), or bare (`aabbccddeeff`) form; case-insensitive.

    Returns a tryResult holding a mac value, or the detail of the failure.
  */
  tryParseDetail =
    input:
    let
      inputLength = builtins.stringLength input;
      parsed =
        if inputLength == 12 then
          parseBare input
        else if inputLength == 14 then
          parseCisco input
        else if inputLength == 17 then
          let
            separator = builtins.substring 2 1 input;
          in
          if separator == ":" then
            parseSeparated ":" input
          else if separator == "-" then
            parseSeparated "-" input
          else
            null
        else
          null;
    in
    if parsed == null then types.tryErr "invalid MAC address \"${input}\"" else types.tryOk parsed;

  parsers = parsing.suite "mac" tryParseDetail;

  # ===== Formatting =====

  /*
    Format a MAC address in canonical colon form.

    `mac`: mac value.

    Returns a lowercase string such as `aa:bb:cc:dd:ee:ff`.
  */
  toString = withValue "toString" (hexBytes ":");

  /*
    Format a MAC address in hyphen form.

    `mac`: mac value.

    Returns a lowercase string such as `aa-bb-cc-dd-ee-ff`.
  */
  toStringHyphen = withValue "toStringHyphen" (hexBytes "-");

  /*
    Format a MAC address in Cisco dotted form.

    `mac`: mac value.

    Returns a lowercase string such as `aabb.ccdd.eeff`.
  */
  toStringCisco =
    mac:
    let
      bytes = bytesOf (valueOf "toStringCisco" mac);
      hexByte = i: formatting.hex2 (builtins.elemAt bytes i);
    in
    "${hexByte 0}${hexByte 1}.${hexByte 2}${hexByte 3}.${hexByte 4}${hexByte 5}";

  /*
    Format a MAC address as twelve hex digits without separators.

    `mac`: mac value.

    Returns a lowercase string such as `aabbccddeeff`.
  */
  toStringBare = withValue "toStringBare" (hexBytes "");

  # ===== Predicates =====

  /*
    Structural check for a tagged MAC address.

    `value`: any value.

    Returns true only for mac values.
  */
  is = value: types.isMac value;

  # Test the bits `mask` of the first octet for `function`.
  firstOctetBits =
    function: mask: mac:
    builtins.bitAnd (bits.bits 40 8 (valueOf function mac)) mask;

  /*
    Check whether a MAC address is unicast (I/G bit, bit 0 of the first
    octet, is clear).

    `mac`: mac value.

    Returns a Boolean.
  */
  isUnicast = mac: firstOctetBits "isUnicast" 1 mac == 0;

  /*
    Check whether a MAC address is multicast (I/G bit, bit 0 of the first
    octet, is set).

    `mac`: mac value.

    Returns a Boolean.
  */
  isMulticast = mac: firstOctetBits "isMulticast" 1 mac == 1;

  /*
    Check whether a MAC address is universally administered (U/L bit, bit 1
    of the first octet, is clear).

    `mac`: mac value.

    Returns a Boolean.
  */
  isUniversal = mac: firstOctetBits "isUniversal" 2 mac == 0;

  /*
    Check whether a MAC address is locally administered (U/L bit, bit 1 of
    the first octet, is set).

    `mac`: mac value.

    Returns a Boolean.
  */
  isLocal = mac: firstOctetBits "isLocal" 2 mac == 2;

  /*
    Check whether a MAC address is the broadcast address
    `ff:ff:ff:ff:ff:ff`.

    `mac`: mac value.

    Returns a Boolean.
  */
  isBroadcast = withValue "isBroadcast" (value: value == bits.mask48);

  /*
    Check whether a MAC address is the all-zero address.

    `mac`: mac value.

    Returns a Boolean.
  */
  isUnspecified = withValue "isUnspecified" (value: value == 0);

  # ===== Bit setters =====

  # I/G and U/L bits: bits 0 and 1 of the first octet.
  multicastBit = bits.pow2 40;
  localBit = bits.pow2 41;

  /*
    Mark a MAC address as multicast by setting the I/G bit.

    `mac`: mac value.

    Returns a mac value.
  */
  setMulticast = withValue "setMulticast" (value: mk (builtins.bitOr value multicastBit));

  /*
    Mark a MAC address as unicast by clearing the I/G bit.

    `mac`: mac value.

    Returns a mac value.
  */
  setUnicast = withValue "setUnicast" (
    value: mk (builtins.bitAnd value (builtins.bitXor bits.mask48 multicastBit))
  );

  /*
    Mark a MAC address as locally administered by setting the U/L bit.

    `mac`: mac value.

    Returns a mac value.
  */
  setLocal = withValue "setLocal" (value: mk (builtins.bitOr value localBit));

  /*
    Mark a MAC address as universally administered by clearing the U/L
    bit.

    `mac`: mac value.

    Returns a mac value.
  */
  setUniversal = withValue "setUniversal" (
    value: mk (builtins.bitAnd value (builtins.bitXor bits.mask48 localBit))
  );

  # ===== OUI / NIC =====

  /*
    Extract the Organizationally Unique Identifier.

    `mac`: mac value.

    Returns the upper 24 bits as an integer.
  */
  oui = withValue "oui" (bits.shr 24);

  /*
    Extract the NIC-specific part.

    `mac`: mac value.

    Returns the lower 24 bits as an integer.
  */
  nic = withValue "nic" (value: builtins.bitAnd value bits.mask24);

  /*
    Build a MAC address from its OUI and NIC halves.

    `ouiValue`: integer in [0, 2^24 - 1] for the upper 24 bits.
    `nicValue`: integer in [0, 2^24 - 1] for the lower 24 bits.

    Returns a mac value; throws when either half is out of range.
  */
  fromOuiNic =
    ouiValue: nicValue:
    mkStrict (
      boundedInt "fromOuiNic" "OUI out of range" bits.mask24 ouiValue * bits.pow2_24
      + boundedInt "fromOuiNic" "NIC out of range" bits.mask24 nicValue
    );

  /*
    Format the OUI of a MAC address as three colon-separated octets.

    `mac`: mac value.

    Returns a lowercase string such as `aa:bb:cc`.
  */
  toStringOui =
    mac:
    let
      ouiValue = bits.shr 24 (valueOf "toStringOui" mac);
      high = bits.bits 16 8 ouiValue;
      middle = bits.bits 8 8 ouiValue;
      low = bits.bits 0 8 ouiValue;
    in
    "${formatting.hex2 high}:${formatting.hex2 middle}:${formatting.hex2 low}";

  # ===== EUI-64 =====

  /*
    Derive the modified EUI-64 interface identifier (RFC 4291 section
    2.5.1), suitable as the lower 64 bits of an IPv6 address.

    `mac`: mac value.

    Returns eight bytes: `ff:fe` inserted between OUI and NIC, with the U/L
    bit of the first octet flipped.
  */
  toEui64 =
    mac:
    let
      value = valueOf "toEui64" mac;
      bytes = bytesOf value;
      firstByteFlipped = builtins.bitXor (builtins.elemAt bytes 0) 2;
    in
    builtins.seq value [
      firstByteFlipped
      (builtins.elemAt bytes 1)
      (builtins.elemAt bytes 2)
      255
      254
      (builtins.elemAt bytes 3)
      (builtins.elemAt bytes 4)
      (builtins.elemAt bytes 5)
    ];

  # ===== Arithmetic =====

  /*
    Offset a MAC address.

    `n`: integer offset; may be negative.
    `mac`: mac value.

    Returns a mac value; throws when `n` is not an integer or the result
    leaves [0, 2^48 - 1].
  */
  add = arithmetic.add "mac.add";

  /*
    Offset a MAC address downward.

    `n`: integer to subtract; may be negative.
    `mac`: mac value.

    Returns a mac value; throws when `n` is not an integer or the result
    leaves [0, 2^48 - 1].
  */
  sub = arithmetic.sub "mac.sub";

  /*
    Measure the distance between two MAC addresses.

    `a`, `b`: mac values.

    Returns `toInt b - toInt a`.
  */
  diff = a: b: valueOf "diff" b - valueOf "diff" a;

  /*
    Step to the following MAC address.

    `mac`: mac value.

    Returns a mac value; throws past `ff:ff:ff:ff:ff:ff`.
  */
  next = arithmetic.add "mac.next" 1;

  /*
    Step to the preceding MAC address.

    `mac`: mac value.

    Returns a mac value; throws below `00:00:00:00:00:00`.
  */
  prev = arithmetic.sub "mac.prev" 1;

  # ===== Comparison =====

  # Order two MAC addresses for the public function `function`, which
  # throws for any argument that is not a mac value.
  compareFor =
    function: a: b:
    comparison.order (valueOf function a) (valueOf function b);

  ordering = comparison.suite compareFor;

  /*
    Test two MAC addresses for equality.

    `a`, `b`: values to compare.

    Returns true when both carry the same tag and integer value.
  */
  eq = a: b: types.bothHaveTag types.tags.mac a b && a.value == b.value;

  # ===== Constants =====

  unspecified = mk 0;
  broadcast = mk bits.mask48;
in
{
  inherit
    add
    broadcast
    diff
    eq
    fromBytes
    fromInt
    fromOuiNic
    is
    isBroadcast
    isLocal
    isMulticast
    isUnicast
    isUniversal
    isUnspecified
    next
    nic
    oui
    prev
    setLocal
    setMulticast
    setUnicast
    setUniversal
    sub
    toBytes
    toEui64
    toInt
    toString
    toStringBare
    toStringCisco
    toStringHyphen
    toStringOui
    unspecified
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
