/*
  libnet.ipv4

  Parse, format, compare, and do arithmetic on IPv4 addresses. The
  canonical internal form is a single u32 carried on a tagged attrset.

  Example:
    libnet.ipv4.parse "192.0.2.1"
    => { _type = "ipv4"; value = 3221225985; }

    libnet.ipv4.toString (libnet.ipv4.next (libnet.ipv4.parse "10.0.0.1"))
    => "10.0.0.2"
*/
let
  bits = import ./internal/bits.nix;
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  # Internal constructor — assumes `v` is already validated.
  mk = v: {
    _type = "ipv4";
    value = v;
  };

  # ===== Conversion =====

  fromInt =
    n:
    if !(builtins.isInt n) || n < 0 || n > bits.mask32 then
      builtins.throw "libnet.ipv4.fromInt: value out of range [0, 4294967295]: ${builtins.toString n}"
    else
      mk n;

  toInt = ip: ip.value;

  fromOctets =
    os:
    if !(builtins.isList os) || builtins.length os != 4 then
      builtins.throw "libnet.ipv4.fromOctets: expected list of 4 ints"
    else
      let
        a = builtins.elemAt os 0;
        b = builtins.elemAt os 1;
        c = builtins.elemAt os 2;
        d = builtins.elemAt os 3;
        invalid = builtins.any (v: !(builtins.isInt v) || v < 0 || v > 255) os;
      in
      if invalid then
        builtins.throw "libnet.ipv4.fromOctets: each octet must be int in [0, 255]"
      else
        mk (a * bits.pow2_24 + b * bits.pow2_16 + c * bits.pow2_8 + d);

  toOctets =
    ip:
    let
      v = ip.value;
    in
    [
      (bits.bits 24 8 v)
      (bits.bits 16 8 v)
      (bits.bits 8 8 v)
      (bits.bits 0 8 v)
    ];

  # ===== Parsing & formatting =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.ipv4.parse: input must be a string"
    else
      let
        parts = parse'.splitOn "." s;
        len = builtins.length parts;
      in
      if len != 4 then
        types.tryErr "libnet.ipv4.parse: must have 4 octets, got ${builtins.toString len}: \"${s}\""
      else
        let
          oct = i: parse'.octet (builtins.elemAt parts i);
          a = oct 0;
          b = oct 1;
          c = oct 2;
          d = oct 3;
        in
        if a == null || b == null || c == null || d == null then
          types.tryErr "libnet.ipv4.parse: invalid octet in \"${s}\""
        else
          types.tryOk (fromOctets [
            a
            b
            c
            d
          ]);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString = ip: builtins.concatStringsSep "." (map builtins.toString (toOctets ip));

  toArpa =
    ip:
    let
      os = toOctets ip;
    in
    "${builtins.toString (builtins.elemAt os 3)}"
    + ".${builtins.toString (builtins.elemAt os 2)}"
    + ".${builtins.toString (builtins.elemAt os 1)}"
    + ".${builtins.toString (builtins.elemAt os 0)}"
    + ".in-addr.arpa";

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isIpv4;

  # Range helpers using explicit block boundaries (readable).
  class10Start = 10 * bits.pow2_24;
  class10End = 11 * bits.pow2_24 - 1;
  class172Start = 172 * bits.pow2_24 + 16 * bits.pow2_16;
  class172End = 172 * bits.pow2_24 + 32 * bits.pow2_16 - 1;
  class192Start = 192 * bits.pow2_24 + 168 * bits.pow2_16;
  class192End = 192 * bits.pow2_24 + 169 * bits.pow2_16 - 1;

  isLoopback = ip: ip.value >= 127 * bits.pow2_24 && ip.value <= 128 * bits.pow2_24 - 1;

  isPrivate =
    ip:
    (ip.value >= class10Start && ip.value <= class10End)
    || (ip.value >= class172Start && ip.value <= class172End)
    || (ip.value >= class192Start && ip.value <= class192End);

  isLinkLocal =
    ip:
    ip.value >= 169 * bits.pow2_24 + 254 * bits.pow2_16
    && ip.value <= 169 * bits.pow2_24 + 255 * bits.pow2_16 - 1;

  isMulticast = ip: ip.value >= 224 * bits.pow2_24 && ip.value <= 240 * bits.pow2_24 - 1;

  isBroadcast = ip: ip.value == bits.mask32;
  isUnspecified = ip: ip.value == 0;

  # 240.0.0.0/4 excluding 255.255.255.255
  isReserved = ip: ip.value >= 240 * bits.pow2_24 && ip.value <= bits.mask32 - 1;

  # Documentation blocks: 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24
  isDocumentation =
    ip:
    let
      v = ip.value;
    in
    (
      v >= 192 * bits.pow2_24 + 0 * bits.pow2_16 + 2 * bits.pow2_8
      && v <= 192 * bits.pow2_24 + 0 * bits.pow2_16 + 3 * bits.pow2_8 - 1
    )
    || (
      v >= 198 * bits.pow2_24 + 51 * bits.pow2_16 + 100 * bits.pow2_8
      && v <= 198 * bits.pow2_24 + 51 * bits.pow2_16 + 101 * bits.pow2_8 - 1
    )
    || (
      v >= 203 * bits.pow2_24 + 0 * bits.pow2_16 + 113 * bits.pow2_8
      && v <= 203 * bits.pow2_24 + 0 * bits.pow2_16 + 114 * bits.pow2_8 - 1
    );

  isBogon =
    ip:
    isLoopback ip
    || isPrivate ip
    || isLinkLocal ip
    || isMulticast ip
    || isReserved ip
    || isDocumentation ip
    || isUnspecified ip
    || isBroadcast ip;

  isGlobal = ip: !(isBogon ip);

  # ===== Arithmetic =====

  add =
    n: ip:
    let
      r = ip.value + n;
    in
    if r < 0 || r > bits.mask32 then
      builtins.throw "libnet.ipv4.add: result out of range [0, 4294967295]"
    else
      mk r;

  sub = n: ip: add (0 - n) ip;

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

  any = mk 0;
  broadcast = mk bits.mask32;
  loopback = fromOctets [
    127
    0
    0
    1
  ];
in
{
  inherit
    fromInt
    toInt
    fromOctets
    toOctets
    ;
  inherit
    parse
    tryParse
    toString
    toArpa
    ;
  inherit isValid is;
  inherit
    isLoopback
    isPrivate
    isLinkLocal
    isMulticast
    isBroadcast
    isUnspecified
    isReserved
    isDocumentation
    isGlobal
    isBogon
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
  inherit any broadcast loopback;
}
