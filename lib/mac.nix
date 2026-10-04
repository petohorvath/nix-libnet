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
  bits = import ./internal/bits.nix;
  formatting = import ./internal/format.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  mk = value: {
    _type = "mac";
    inherit value;
  };

  # ===== Conversion =====

  /*
    Build a MAC address from its 48-bit integer value.

    `value`: integer in [0, 2^48 - 1].

    Returns a mac value; throws on a non-integer or out-of-range value.
  */
  fromInt =
    value:
    if !(builtins.isInt value) || value < 0 || value > bits.mask48 then
      throw "libnet.mac.fromInt: value out of range [0, ${builtins.toString bits.mask48}]: ${builtins.toString value}"
    else
      mk value;

  /*
    Read the 48-bit integer value of a MAC address.

    `mac`: mac value.

    Returns an integer in [0, 2^48 - 1].
  */
  toInt = mac: mac.value;

  /*
    Build a MAC address from its six octets.

    `bytes`: list of six integers in [0, 255], most significant first.

    Returns a mac value; throws on a wrong length or an invalid byte.
  */
  fromBytes =
    bytes:
    if !(builtins.isList bytes) || builtins.length bytes != 6 then
      throw "libnet.mac.fromBytes: expected list of 6 ints"
    else
      let
        invalid = builtins.any (byte: !(builtins.isInt byte) || byte < 0 || byte > 255) bytes;
      in
      if invalid then
        throw "libnet.mac.fromBytes: each byte must be int in [0, 255]"
      else
        mk (builtins.foldl' (acc: byte: acc * 256 + byte) 0 bytes);

  /*
    Split a MAC address into its six octets.

    `mac`: mac value.

    Returns a list of six integers in [0, 255], most significant first.
  */
  toBytes =
    mac:
    let
      inherit (mac) value;
    in
    [
      (bits.bits 40 8 value)
      (bits.bits 32 8 value)
      (bits.bits 24 8 value)
      (bits.bits 16 8 value)
      (bits.bits 8 8 value)
      (bits.bits 0 8 value)
    ];

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
    Parse a MAC address without throwing, for callers that validate
    untrusted text.

    `input`: string in colon (`aa:bb:cc:dd:ee:ff`), hyphen, Cisco dotted
    (`aabb.ccdd.eeff`), or bare (`aabbccddeeff`) form; case-insensitive.

    Returns a tryParse result whose `value` is a mac value.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.mac.parse: input must be a string"
    else
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
      if parsed == null then
        types.tryErr "libnet.mac.parse: invalid MAC address \"${input}\""
      else
        types.tryOk parsed;

  /*
    Parse a MAC address written in any common notation.

    `input`: string in colon, hyphen, Cisco dotted, or bare form;
    case-insensitive.

    Returns a mac value; throws on invalid input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  # ===== Formatting =====

  /*
    Format a MAC address in canonical colon form.

    `mac`: mac value.

    Returns a lowercase string such as `aa:bb:cc:dd:ee:ff`.
  */
  toString = mac: builtins.concatStringsSep ":" (map formatting.hex2 (toBytes mac));

  /*
    Format a MAC address in hyphen form.

    `mac`: mac value.

    Returns a lowercase string such as `aa-bb-cc-dd-ee-ff`.
  */
  toStringHyphen = mac: builtins.concatStringsSep "-" (map formatting.hex2 (toBytes mac));

  /*
    Format a MAC address in Cisco dotted form.

    `mac`: mac value.

    Returns a lowercase string such as `aabb.ccdd.eeff`.
  */
  toStringCisco =
    mac:
    let
      bytes = toBytes mac;
      hexByte = i: formatting.hex2 (builtins.elemAt bytes i);
    in
    "${hexByte 0}${hexByte 1}.${hexByte 2}${hexByte 3}.${hexByte 4}${hexByte 5}";

  /*
    Format a MAC address as twelve hex digits without separators.

    `mac`: mac value.

    Returns a lowercase string such as `aabbccddeeff`.
  */
  toStringBare = mac: builtins.concatStringsSep "" (map formatting.hex2 (toBytes mac));

  # ===== Predicates =====

  /*
    Check whether a string parses as a MAC address.

    `input`: value to test.

    Returns a Boolean; never throws.
  */
  isValid = input: (tryParse input).success;

  /*
    Structural check for a tagged MAC address.

    `value`: any value.

    Returns true only for mac values.
  */
  is = value: types.isMac value;

  firstOctet = mac: bits.bits 40 8 mac.value;

  /*
    Check whether a MAC address is unicast (I/G bit, bit 0 of the first
    octet, is clear).

    `mac`: mac value.

    Returns a Boolean.
  */
  isUnicast = mac: builtins.bitAnd (firstOctet mac) 1 == 0;

  /*
    Check whether a MAC address is multicast (I/G bit, bit 0 of the first
    octet, is set).

    `mac`: mac value.

    Returns a Boolean.
  */
  isMulticast = mac: builtins.bitAnd (firstOctet mac) 1 == 1;

  /*
    Check whether a MAC address is universally administered (U/L bit, bit 1
    of the first octet, is clear).

    `mac`: mac value.

    Returns a Boolean.
  */
  isUniversal = mac: builtins.bitAnd (firstOctet mac) 2 == 0;

  /*
    Check whether a MAC address is locally administered (U/L bit, bit 1 of
    the first octet, is set).

    `mac`: mac value.

    Returns a Boolean.
  */
  isLocal = mac: builtins.bitAnd (firstOctet mac) 2 == 2;

  /*
    Check whether a MAC address is the broadcast address
    `ff:ff:ff:ff:ff:ff`.

    `mac`: mac value.

    Returns a Boolean.
  */
  isBroadcast = mac: mac.value == bits.mask48;

  /*
    Check whether a MAC address is the all-zero address.

    `mac`: mac value.

    Returns a Boolean.
  */
  isUnspecified = mac: mac.value == 0;

  # ===== Bit setters =====

  # I/G and U/L bits: bits 0 and 1 of the first octet.
  multicastBit = bits.pow2 40;
  localBit = bits.pow2 41;

  /*
    Mark a MAC address as multicast by setting the I/G bit.

    `mac`: mac value.

    Returns a mac value.
  */
  setMulticast = mac: mk (builtins.bitOr mac.value multicastBit);

  /*
    Mark a MAC address as unicast by clearing the I/G bit.

    `mac`: mac value.

    Returns a mac value.
  */
  setUnicast = mac: mk (builtins.bitAnd mac.value (builtins.bitXor bits.mask48 multicastBit));

  /*
    Mark a MAC address as locally administered by setting the U/L bit.

    `mac`: mac value.

    Returns a mac value.
  */
  setLocal = mac: mk (builtins.bitOr mac.value localBit);

  /*
    Mark a MAC address as universally administered by clearing the U/L
    bit.

    `mac`: mac value.

    Returns a mac value.
  */
  setUniversal = mac: mk (builtins.bitAnd mac.value (builtins.bitXor bits.mask48 localBit));

  # ===== OUI / NIC =====

  /*
    Extract the Organizationally Unique Identifier.

    `mac`: mac value.

    Returns the upper 24 bits as an integer.
  */
  oui = mac: bits.shr 24 mac.value;

  /*
    Extract the NIC-specific part.

    `mac`: mac value.

    Returns the lower 24 bits as an integer.
  */
  nic = mac: builtins.bitAnd mac.value bits.mask24;

  /*
    Build a MAC address from its OUI and NIC halves.

    `ouiValue`: integer in [0, 2^24 - 1] for the upper 24 bits.
    `nicValue`: integer in [0, 2^24 - 1] for the lower 24 bits.

    Returns a mac value; throws when either half is out of range.
  */
  fromOuiNic =
    ouiValue: nicValue:
    if !(builtins.isInt ouiValue) || ouiValue < 0 || ouiValue > bits.mask24 then
      throw "libnet.mac.fromOuiNic: OUI out of range [0, 16777215]"
    else if !(builtins.isInt nicValue) || nicValue < 0 || nicValue > bits.mask24 then
      throw "libnet.mac.fromOuiNic: NIC out of range [0, 16777215]"
    else
      mk (ouiValue * bits.pow2_24 + nicValue);

  /*
    Format an OUI as three colon-separated octets.

    `ouiValue`: integer in [0, 2^24 - 1], as returned by `oui`.

    Returns a lowercase string such as `aa:bb:cc`.
  */
  ouiToString =
    ouiValue:
    let
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
      bytes = toBytes mac;
      firstByteFlipped = builtins.bitXor (builtins.elemAt bytes 0) 2;
    in
    [
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

    Returns a mac value; throws when the result leaves [0, 2^48 - 1].
  */
  add =
    n: mac:
    let
      result = mac.value + n;
    in
    if result < 0 || result > bits.mask48 then
      throw "libnet.mac.add: result out of range [0, ${builtins.toString bits.mask48}]: ${builtins.toString result}"
    else
      mk result;

  /*
    Offset a MAC address downward.

    `n`: integer to subtract; may be negative.
    `mac`: mac value.

    Returns a mac value; throws when the result leaves [0, 2^48 - 1].
  */
  sub = n: mac: add (0 - n) mac;

  /*
    Measure the distance between two MAC addresses.

    `a`, `b`: mac values.

    Returns `toInt b - toInt a`.
  */
  diff = a: b: b.value - a.value;

  /*
    Step to the following MAC address.

    `mac`: mac value.

    Returns a mac value; throws past `ff:ff:ff:ff:ff:ff`.
  */
  next = mac: add 1 mac;

  /*
    Step to the preceding MAC address.

    `mac`: mac value.

    Returns a mac value; throws below `00:00:00:00:00:00`.
  */
  prev = mac: sub 1 mac;

  # ===== Comparison =====

  /*
    Test two MAC addresses for equality.

    `a`, `b`: values to compare.

    Returns true when both carry the same tag and integer value.
  */
  eq = a: b: types.hasSameTag a b && a.value == b.value;

  /*
    Order two MAC addresses by integer value.

    `a`, `b`: mac values.

    Returns -1, 0, or 1.
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
    Test whether `a` orders before `b`.

    `a`, `b`: mac values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether `a` orders before or equal to `b`.

    `a`, `b`: mac values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether `a` orders after `b`.

    `a`, `b`: mac values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether `a` orders after or equal to `b`.

    `a`, `b`: mac values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lower of two MAC addresses.

    `a`, `b`: mac values.

    Returns `a` when the two compare equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the higher of two MAC addresses.

    `a`, `b`: mac values.

    Returns `a` when the two compare equal.
  */
  max = a: b: if ge a b then a else b;

  # ===== Constants =====

  unspecified = mk 0;
  broadcast = mk bits.mask48;
in
{
  inherit
    add
    broadcast
    compare
    diff
    eq
    fromBytes
    fromInt
    fromOuiNic
    ge
    gt
    is
    isBroadcast
    isLocal
    isMulticast
    isUnicast
    isUniversal
    isUnspecified
    isValid
    le
    lt
    max
    min
    next
    nic
    oui
    ouiToString
    parse
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
    tryParse
    unspecified
    ;
}
