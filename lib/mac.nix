/*
  libnet.mac

  Parse, format, and manipulate 48-bit MAC addresses. Accepts colon,
  hyphen, Cisco dotted, and bare 12-hex-char input; supports OUI/NIC
  split and EUI-64 modified form.

  Example:
    libnet.mac.parse "a0:36:9f:1b:1e:55"
    => { _type = "mac"; value = 176028872726357; }

    libnet.mac.toString (libnet.mac.parse "a036.9f1b.1e55")
    => "a0:36:9f:1b:1e:55"
*/
let
  bits = import ./internal/bits.nix;
  parse' = import ./internal/parse.nix;
  fmt = import ./internal/format.nix;
  types = import ./internal/types.nix;

  mk = v: {
    _type = "mac";
    value = v;
  };

  # ===== Conversion =====

  fromInt =
    n:
    if !(builtins.isInt n) || n < 0 || n > bits.mask48 then
      builtins.throw "libnet.mac.fromInt: value out of range [0, ${builtins.toString bits.mask48}]: ${builtins.toString n}"
    else
      mk n;

  toInt = mac: mac.value;

  fromBytes =
    bs:
    if !(builtins.isList bs) || builtins.length bs != 6 then
      builtins.throw "libnet.mac.fromBytes: expected list of 6 ints"
    else
      let
        invalid = builtins.any (v: !(builtins.isInt v) || v < 0 || v > 255) bs;
      in
      if invalid then
        builtins.throw "libnet.mac.fromBytes: each byte must be int in [0, 255]"
      else
        mk (builtins.foldl' (acc: b: acc * 256 + b) 0 bs);

  toBytes =
    mac:
    let
      v = mac.value;
    in
    [
      (bits.bits 40 8 v)
      (bits.bits 32 8 v)
      (bits.bits 24 8 v)
      (bits.bits 16 8 v)
      (bits.bits 8 8 v)
      (bits.bits 0 8 v)
    ];

  # ===== Parsing =====

  parseBare =
    s:
    if builtins.match "[0-9a-fA-F]{12}" s == null then
      null
    else
      let
        byte = i: parse'.hexInt (builtins.substring (i * 2) 2 s);
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
    s:
    let
      parts = parse'.splitOn "." s;
    in
    if builtins.length parts != 3 then
      null
    else
      let
        g0str = builtins.elemAt parts 0;
        g1str = builtins.elemAt parts 1;
        g2str = builtins.elemAt parts 2;
        valid =
          builtins.stringLength g0str == 4
          && builtins.stringLength g1str == 4
          && builtins.stringLength g2str == 4
          && builtins.match "[0-9a-fA-F]{4}" g0str != null
          && builtins.match "[0-9a-fA-F]{4}" g1str != null
          && builtins.match "[0-9a-fA-F]{4}" g2str != null;
      in
      if !valid then
        null
      else
        mk (
          (parse'.hexInt g0str) * bits.pow2_32 + (parse'.hexInt g1str) * bits.pow2_16 + (parse'.hexInt g2str)
        );

  parseSeparated =
    sep: s:
    let
      parts = parse'.splitOn sep s;
    in
    if builtins.length parts != 6 then
      null
    else
      let
        allValid = builtins.all (
          p: builtins.stringLength p == 2 && builtins.match "[0-9a-fA-F]{2}" p != null
        ) parts;
      in
      if !allValid then null else mk (builtins.foldl' (acc: p: acc * 256 + (parse'.hexInt p)) 0 parts);

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.mac.parse: input must be a string"
    else
      let
        len = builtins.stringLength s;
        attempt =
          if len == 12 then
            parseBare s
          else if len == 14 then
            parseCisco s
          else if len == 17 then
            let
              sep = builtins.substring 2 1 s;
            in
            if sep == ":" then
              parseSeparated ":" s
            else if sep == "-" then
              parseSeparated "-" s
            else
              null
          else
            null;
      in
      if attempt == null then
        types.tryErr "libnet.mac.parse: invalid MAC address \"${s}\""
      else
        types.tryOk attempt;

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  # ===== Formatting =====

  toString = mac: builtins.concatStringsSep ":" (map fmt.hex2 (toBytes mac));

  toStringHyphen = mac: builtins.concatStringsSep "-" (map fmt.hex2 (toBytes mac));

  toStringCisco =
    mac:
    let
      bs = toBytes mac;
      h = i: fmt.hex2 (builtins.elemAt bs i);
    in
    "${h 0}${h 1}.${h 2}${h 3}.${h 4}${h 5}";

  toStringBare = mac: builtins.concatStringsSep "" (map fmt.hex2 (toBytes mac));

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isMac;

  firstOctet = mac: bits.bits 40 8 mac.value;

  isUnicast = mac: builtins.bitAnd (firstOctet mac) 1 == 0;
  isMulticast = mac: builtins.bitAnd (firstOctet mac) 1 == 1;
  isUniversal = mac: builtins.bitAnd (firstOctet mac) 2 == 0;
  isLocal = mac: builtins.bitAnd (firstOctet mac) 2 == 2;
  isBroadcast = mac: mac.value == bits.mask48;
  isUnspecified = mac: mac.value == 0;

  # ===== Bit setters =====

  bit40 = bits.pow2 40; # bit 0 of first octet
  bit41 = bits.pow2 41; # bit 1 of first octet

  setMulticast = mac: mk (builtins.bitOr mac.value bit40);
  setUnicast = mac: mk (builtins.bitAnd mac.value (builtins.bitXor bits.mask48 bit40));
  setLocal = mac: mk (builtins.bitOr mac.value bit41);
  setUniversal = mac: mk (builtins.bitAnd mac.value (builtins.bitXor bits.mask48 bit41));

  # ===== OUI / NIC =====

  oui = mac: bits.shr 24 mac.value;
  nic = mac: builtins.bitAnd mac.value bits.mask24;

  fromOuiNic =
    ouiVal: nicVal:
    if !(builtins.isInt ouiVal) || ouiVal < 0 || ouiVal > bits.mask24 then
      builtins.throw "libnet.mac.fromOuiNic: OUI out of range [0, 16777215]"
    else if !(builtins.isInt nicVal) || nicVal < 0 || nicVal > bits.mask24 then
      builtins.throw "libnet.mac.fromOuiNic: NIC out of range [0, 16777215]"
    else
      mk (ouiVal * bits.pow2_24 + nicVal);

  ouiToString =
    ouiVal:
    let
      a = bits.bits 16 8 ouiVal;
      b = bits.bits 8 8 ouiVal;
      c = bits.bits 0 8 ouiVal;
    in
    "${fmt.hex2 a}:${fmt.hex2 b}:${fmt.hex2 c}";

  # ===== EUI-64 =====

  toEui64 =
    mac:
    let
      bs = toBytes mac;
      b0Flipped = builtins.bitXor (builtins.elemAt bs 0) 2;
    in
    [
      b0Flipped
      (builtins.elemAt bs 1)
      (builtins.elemAt bs 2)
      255
      254
      (builtins.elemAt bs 3)
      (builtins.elemAt bs 4)
      (builtins.elemAt bs 5)
    ];

  # ===== Arithmetic =====

  add =
    n: mac:
    let
      r = mac.value + n;
    in
    if r < 0 || r > bits.mask48 then
      builtins.throw "libnet.mac.add: result out of range [0, 2^48-1]"
    else
      mk r;

  sub = n: mac: add (0 - n) mac;
  diff = a: b: b.value - a.value;
  next = add 1;
  prev = sub 1;

  # ===== Comparison =====

  eq = a: b: a.value == b.value;
  lt = a: b: a.value < b.value;
  le = a: b: a.value <= b.value;
  gt = a: b: a.value > b.value;
  ge = a: b: a.value >= b.value;

  compare =
    a: b:
    if a.value < b.value then
      -1
    else if a.value > b.value then
      1
    else
      0;

  min = a: b: if a.value <= b.value then a else b;
  max = a: b: if a.value >= b.value then a else b;

  # ===== Constants =====

  unspecified = mk 0;
  broadcast = mk bits.mask48;
in
{
  inherit
    fromInt
    toInt
    fromBytes
    toBytes
    ;
  inherit
    parse
    tryParse
    toString
    toStringHyphen
    toStringCisco
    toStringBare
    ;
  inherit isValid is;
  inherit
    isUnicast
    isMulticast
    isUniversal
    isLocal
    isBroadcast
    isUnspecified
    ;
  inherit
    setMulticast
    setUnicast
    setLocal
    setUniversal
    ;
  inherit
    oui
    nic
    fromOuiNic
    ouiToString
    toEui64
    ;
  inherit
    add
    sub
    diff
    next
    prev
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
  inherit unspecified broadcast;
}
