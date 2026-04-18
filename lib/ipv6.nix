let
  bits = import ./internal/bits.nix;
  parse' = import ./internal/parse.nix;
  fmt = import ./internal/format.nix;
  carry = import ./internal/carry.nix;
  types = import ./internal/types.nix;
  mac = import ./mac.nix;

  mk = ws: {
    _type = "ipv6";
    words = ws;
  };

  # ===== Conversion =====

  fromWords =
    ws:
    if !(builtins.isList ws) || builtins.length ws != 4 then
      builtins.throw "libnet.ipv6.fromWords: expected list of 4 u32 ints"
    else
      let
        invalid = builtins.any (w: !(builtins.isInt w) || w < 0 || w > bits.mask32) ws;
      in
      if invalid then
        builtins.throw "libnet.ipv6.fromWords: each word must be int in [0, 2^32 - 1]"
      else
        mk ws;

  toWords = ip: ip.words;

  fromGroups =
    gs:
    if !(builtins.isList gs) || builtins.length gs != 8 then
      builtins.throw "libnet.ipv6.fromGroups: expected list of 8 u16 ints"
    else
      let
        invalid = builtins.any (g: !(builtins.isInt g) || g < 0 || g > bits.mask16) gs;
      in
      if invalid then
        builtins.throw "libnet.ipv6.fromGroups: each group must be int in [0, 65535]"
      else
        let
          g = i: builtins.elemAt gs i;
          pair = i: j: (g i) * bits.pow2_16 + (g j);
        in
        mk [
          (pair 0 1)
          (pair 2 3)
          (pair 4 5)
          (pair 6 7)
        ];

  toGroups =
    ip:
    let
      ws = ip.words;
      wordToGroups = w: [
        (bits.shr 16 w)
        (builtins.bitAnd w bits.mask16)
      ];
    in
    builtins.concatMap wordToGroups ws;

  fromBytes =
    bs:
    if !(builtins.isList bs) || builtins.length bs != 16 then
      builtins.throw "libnet.ipv6.fromBytes: expected list of 16 u8 ints"
    else
      let
        invalid = builtins.any (b: !(builtins.isInt b) || b < 0 || b > 255) bs;
      in
      if invalid then
        builtins.throw "libnet.ipv6.fromBytes: each byte must be int in [0, 255]"
      else
        let
          b = i: builtins.elemAt bs i;
          quad =
            i: (b i) * bits.pow2_24 + (b (i + 1)) * bits.pow2_16 + (b (i + 2)) * bits.pow2_8 + (b (i + 3));
        in
        mk [
          (quad 0)
          (quad 4)
          (quad 8)
          (quad 12)
        ];

  toBytes =
    ip:
    let
      ws = ip.words;
      wordToBytes = w: [
        (bits.bits 24 8 w)
        (bits.bits 16 8 w)
        (bits.bits 8 8 w)
        (bits.bits 0 8 w)
      ];
    in
    builtins.concatMap wordToBytes ws;

  # ===== Parsing =====

  # Parse a list of hex-group strings into ints. null on failure.
  parseHexGroups =
    strs:
    let
      results = map parse'.hexGroup strs;
    in
    if builtins.any (v: v == null) results then null else results;

  # Check that no element contains "." except the last.
  v4OnlyLast =
    parts:
    let
      n = builtins.length parts;
      hasDot = p: parse'.countOccurrences "." p > 0;
    in
    if n <= 1 then
      true
    else
      let
        allExceptLast = builtins.genList (i: builtins.elemAt parts i) (n - 1);
      in
      !(builtins.any hasDot allExceptLast);

  # Given a list of strings, expand the last element if it's a v4 literal;
  # parse the rest as hex groups. Returns list of ints or null.
  expandPartsToGroups =
    parts:
    let
      n = builtins.length parts;
    in
    if n == 0 then
      [ ]
    else if !(v4OnlyLast parts) then
      null
    else
      let
        last = builtins.elemAt parts (n - 1);
        hasDot = parse'.countOccurrences "." last > 0;
      in
      if !hasDot then
        parseHexGroups parts
      else
        let
          v4parts = parse'.splitOn "." last;
          octs = if builtins.length v4parts == 4 then map parse'.octet v4parts else null;
          v4Ok = octs != null && !(builtins.any (o: o == null) octs);
        in
        if !v4Ok then
          null
        else
          let
            a = builtins.elemAt octs 0;
            b = builtins.elemAt octs 1;
            c = builtins.elemAt octs 2;
            d = builtins.elemAt octs 3;
            g0 = a * 256 + b;
            g1 = c * 256 + d;
            prefixParts = if n == 1 then [ ] else builtins.genList (i: builtins.elemAt parts i) (n - 1);
            prefixGroups = parseHexGroups prefixParts;
          in
          if prefixGroups == null then
            null
          else
            prefixGroups
            ++ [
              g0
              g1
            ];

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.ipv6.parse: input must be a string"
    else if s == "" then
      types.tryErr "libnet.ipv6.parse: empty string"
    else
      let
        dcCount = parse'.countOccurrences "::" s;
      in
      if dcCount > 1 then
        types.tryErr "libnet.ipv6.parse: more than one \"::\" in \"${s}\""
      else
        let
          groups =
            if dcCount == 0 then
              let
                parts = parse'.splitOn ":" s;
                g = expandPartsToGroups parts;
              in
              if g == null || builtins.length g != 8 then null else g
            else
              let
                halves = parse'.splitOn "::" s;
                leftStr = builtins.elemAt halves 0;
                rightStr = builtins.elemAt halves 1;
                leftParts = if leftStr == "" then [ ] else parse'.splitOn ":" leftStr;
                rightParts = if rightStr == "" then [ ] else parse'.splitOn ":" rightStr;
                # v4 in left half is invalid (must be at absolute end)
                leftHasDot = builtins.any (p: parse'.countOccurrences "." p > 0) leftParts;
                leftG = if leftHasDot then null else parseHexGroups leftParts;
                rightG = expandPartsToGroups rightParts;
              in
              if leftG == null || rightG == null then
                null
              else
                let
                  total = builtins.length leftG + builtins.length rightG;
                in
                if total > 7 then
                  null # "::" must represent at least 1 zero group
                else
                  let
                    zeros = builtins.genList (_: 0) (8 - total);
                  in
                  leftG ++ zeros ++ rightG;
        in
        if groups == null then
          types.tryErr "libnet.ipv6.parse: invalid \"${s}\""
        else
          types.tryOk (fromGroups groups);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  # ===== Formatting =====

  # RFC 5952 canonical form. IPv4-mapped addresses emit mixed form per § 5.
  toString =
    ip:
    if isIpv4Mapped ip then
      let
        w3 = builtins.elemAt ip.words 3;
        ipv4Part =
          "${builtins.toString (bits.bits 24 8 w3)}"
          + ".${builtins.toString (bits.bits 16 8 w3)}"
          + ".${builtins.toString (bits.bits 8 8 w3)}"
          + ".${builtins.toString (bits.bits 0 8 w3)}";
      in
      "::ffff:${ipv4Part}"
    else
      let
        gs = toGroups ip;
        run = fmt.longestZeroRun gs;
        hexOf = g: fmt.hex g;
        groupStrs = map hexOf gs;
      in
      if run.len == 0 then
        builtins.concatStringsSep ":" groupStrs
      else
        let
          prefix = builtins.genList (i: builtins.elemAt groupStrs i) run.start;
          suffix = builtins.genList (i: builtins.elemAt groupStrs (run.start + run.len + i)) (
            8 - run.start - run.len
          );
          prefixStr = builtins.concatStringsSep ":" prefix;
          suffixStr = builtins.concatStringsSep ":" suffix;
        in
        "${prefixStr}::${suffixStr}";

  toStringCompressed = toString;

  toStringExpanded = ip: builtins.concatStringsSep ":" (map fmt.hex4 (toGroups ip));

  toStringBracketed = ip: "[${toString ip}]";

  toArpa =
    ip:
    let
      bs = toBytes ip;
      nibblesOf = b: [
        (fmt.hex1 (bits.shr 4 b))
        (fmt.hex1 (builtins.bitAnd b 15))
      ];
      nibbles = builtins.concatMap nibblesOf bs;
      # Reverse 32 nibbles
      reversed = builtins.genList (i: builtins.elemAt nibbles (31 - i)) 32;
    in
    (builtins.concatStringsSep "." reversed) + ".ip6.arpa";

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isIpv6;

  w = i: ip: builtins.elemAt ip.words i;

  isUnspecified =
    ip:
    ip.words == [
      0
      0
      0
      0
    ];
  isLoopback =
    ip:
    ip.words == [
      0
      0
      0
      1
    ];

  # fe80::/10 — first 10 bits = 0b1111111010 = 1018
  isLinkLocal = ip: bits.shr 22 (w 0 ip) == 1018;

  # fc00::/7 — first 7 bits = 0b1111110 = 126
  isUniqueLocal = ip: bits.shr 25 (w 0 ip) == 126;

  # ff00::/8 — first 8 bits = 0xff = 255
  isMulticast = ip: bits.shr 24 (w 0 ip) == 255;

  # 2001:db8::/32 — entire first word = 0x20010db8 = 536939960
  # 3fff::/20 — first 20 bits = 0x3fff0 = 262128
  isDocumentation = ip: w 0 ip == 536939960 || bits.shr 12 (w 0 ip) == 262128;

  # ::ffff:0:0/96 — w0==0, w1==0, w2==0xffff (65535)
  isIpv4Mapped = ip: w 0 ip == 0 && w 1 ip == 0 && w 2 ip == 65535;

  # ::/96 — w0==0, w1==0, w2==0
  isIpv4Compatible = ip: w 0 ip == 0 && w 1 ip == 0 && w 2 ip == 0;

  # 2002::/16 — upper 16 bits of w0 = 0x2002 = 8194
  is6to4 = ip: bits.shr 16 (w 0 ip) == 8194;

  isBogon =
    ip:
    isUnspecified ip
    || isLoopback ip
    || isLinkLocal ip
    || isUniqueLocal ip
    || isMulticast ip
    || isDocumentation ip;

  # Spec: isGlobal means "none of the above" — wider set than isBogon,
  # additionally excluding isIpv4Mapped, isIpv4Compatible, is6to4.
  isGlobal = ip: !(isBogon ip || isIpv4Mapped ip || isIpv4Compatible ip || is6to4 ip);

  # ===== IPv4 interop =====

  # Requires access to ipv4 module for construction on fromIpv4Mapped side.
  # To keep dependency one-way (cidr depends on ipv4+ipv6; ipv6 shouldn't import ipv4
  # to avoid cross-pollination), we emit only raw ipv4 values via ipv4.fromInt-compatible
  # shape: { _type = "ipv4"; value = <int>; }.

  fromIpv4Mapped =
    v4:
    if !(types.isIpv4 v4) then
      builtins.throw "libnet.ipv6.fromIpv4Mapped: expected ipv4 value"
    else
      mk [
        0
        0
        65535
        v4.value
      ];

  toIpv4Mapped =
    ip:
    if !(isIpv4Mapped ip) then
      builtins.throw "libnet.ipv6.toIpv4Mapped: address is not in ::ffff:0:0/96"
    else
      {
        _type = "ipv4";
        value = w 3 ip;
      };

  # ===== EUI-64 =====

  # Takes an IPv6 cidr value (with prefix <= 64) and a mac value.
  # Produces an IPv6 address with the cidr's network in the upper bits and
  # modified EUI-64 in the lower 64 bits.
  fromEui64 =
    cidrVal: macVal:
    let
      isValidCidr = types.isCidr cidrVal && cidrVal.address._type == "ipv6";
    in
    if !isValidCidr then
      builtins.throw "libnet.ipv6.fromEui64: first argument must be an IPv6 cidr"
    else if !(types.isMac macVal) then
      builtins.throw "libnet.ipv6.fromEui64: second argument must be a mac"
    else if cidrVal.prefix > 64 then
      builtins.throw "libnet.ipv6.fromEui64: CIDR prefix must be <= 64, got /${builtins.toString cidrVal.prefix}"
    else
      let
        addrWords = cidrVal.address.words;
        w0 = builtins.elemAt addrWords 0;
        w1 = builtins.elemAt addrWords 1;
        prefix = cidrVal.prefix;
        applyMask =
          wv: keep:
          if keep <= 0 then
            0
          else if keep >= 32 then
            wv
          else
            bits.shl (32 - keep) (bits.shr (32 - keep) wv);
        netW0 = applyMask w0 prefix;
        netW1 = applyMask w1 (prefix - 32);
        eui = mac.toEui64 macVal;
        b = i: builtins.elemAt eui i;
        newW2 = (b 0) * bits.pow2_24 + (b 1) * bits.pow2_16 + (b 2) * bits.pow2_8 + (b 3);
        newW3 = (b 4) * bits.pow2_24 + (b 5) * bits.pow2_16 + (b 6) * bits.pow2_8 + (b 7);
      in
      mk [
        netW0
        netW1
        newW2
        newW3
      ];

  # ===== Arithmetic =====

  # Add a non-negative int n (must fit in signed 63-bit) to the 128-bit value.
  # Splits n into nHigh (u32) and nLow (u32).
  # Throws on overflow past 2^128.
  addU63 =
    n: ip:
    let
      nLow = builtins.bitAnd n bits.mask32;
      nHigh = bits.shr 32 n;
      ws = ip.words;
      w0 = builtins.elemAt ws 0;
      w1 = builtins.elemAt ws 1;
      w2 = builtins.elemAt ws 2;
      w3 = builtins.elemAt ws 3;
      r3 = carry.add32 w3 nLow 0;
      r2 = carry.add32 w2 nHigh r3.carry;
      r1 = carry.add32 w1 0 r2.carry;
      r0 = carry.add32 w0 0 r1.carry;
    in
    if r0.carry == 1 then
      builtins.throw "libnet.ipv6.add: overflow beyond 2^128"
    else
      mk [
        r0.sum
        r1.sum
        r2.sum
        r3.sum
      ];

  subU63 =
    n: ip:
    let
      nLow = builtins.bitAnd n bits.mask32;
      nHigh = bits.shr 32 n;
      ws = ip.words;
      w0 = builtins.elemAt ws 0;
      w1 = builtins.elemAt ws 1;
      w2 = builtins.elemAt ws 2;
      w3 = builtins.elemAt ws 3;
      r3 = carry.sub32 w3 nLow 0;
      r2 = carry.sub32 w2 nHigh r3.borrow;
      r1 = carry.sub32 w1 0 r2.borrow;
      r0 = carry.sub32 w0 0 r1.borrow;
    in
    if r0.borrow == 1 then
      builtins.throw "libnet.ipv6.sub: underflow below 0"
    else
      mk [
        r0.diff
        r1.diff
        r2.diff
        r3.diff
      ];

  add =
    n: ip:
    if n == 0 then
      ip
    else if n > 0 then
      addU63 n ip
    else
      subU63 (0 - n) ip;

  sub = n: ip: add (0 - n) ip;

  next = add 1;
  prev = sub 1;

  # Multi-word unsigned subtract: xa - xb (both lists of 4 u32 MSB-first).
  # Returns { words = [...]; finalBorrow = 0 or 1 }.
  subMultiWord =
    xa: xb:
    let
      s3 = carry.sub32 (builtins.elemAt xa 3) (builtins.elemAt xb 3) 0;
      s2 = carry.sub32 (builtins.elemAt xa 2) (builtins.elemAt xb 2) s3.borrow;
      s1 = carry.sub32 (builtins.elemAt xa 1) (builtins.elemAt xb 1) s2.borrow;
      s0 = carry.sub32 (builtins.elemAt xa 0) (builtins.elemAt xb 0) s1.borrow;
    in
    {
      words = [
        s0.diff
        s1.diff
        s2.diff
        s3.diff
      ];
      finalBorrow = s0.borrow;
    };

  # Pack the low 64 bits of a 4-word unsigned number into a signed-63-bit int, or throw.
  lower64OrThrow =
    ws:
    let
      w0 = builtins.elemAt ws 0;
      w1 = builtins.elemAt ws 1;
      w2 = builtins.elemAt ws 2;
      w3 = builtins.elemAt ws 3;
    in
    if w0 != 0 || w1 != 0 then
      builtins.throw "libnet.ipv6.diff: result exceeds signed 63-bit int range"
    else if
      w2 >= 2147483648 # 2^31
    then
      builtins.throw "libnet.ipv6.diff: result exceeds signed 63-bit int range"
    else
      w2 * bits.pow2_32 + w3;

  # diff b - a, expressed as Int. Throws if difference exceeds signed 63-bit int range.
  diff =
    a: b:
    let
      r = subMultiWord b.words a.words;
    in
    if r.finalBorrow == 0 then
      lower64OrThrow r.words
    else
      let
        r2 = subMultiWord a.words b.words;
      in
      0 - (lower64OrThrow r2.words);

  # ===== Comparison =====

  # Lexicographic on words (MSB first).
  compare =
    a: b:
    let
      cmpWord =
        i:
        let
          aw = builtins.elemAt a.words i;
          bw = builtins.elemAt b.words i;
        in
        if aw < bw then
          -1
        else if aw > bw then
          1
        else
          0;
      go =
        i:
        if i == 4 then
          0
        else
          let
            c = cmpWord i;
          in
          if c != 0 then c else go (i + 1);
    in
    go 0;

  eq = a: b: a.words == b.words;
  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;

  # ===== Constants =====

  any = mk [
    0
    0
    0
    0
  ];
  loopback = mk [
    0
    0
    0
    1
  ];
in
{
  inherit
    fromWords
    toWords
    fromGroups
    toGroups
    fromBytes
    toBytes
    ;
  inherit
    parse
    tryParse
    toString
    toStringCompressed
    toStringExpanded
    toStringBracketed
    toArpa
    ;
  inherit isValid is;
  inherit
    isUnspecified
    isLoopback
    isLinkLocal
    isUniqueLocal
    isMulticast
    ;
  inherit
    isDocumentation
    isIpv4Mapped
    isIpv4Compatible
    is6to4
    isGlobal
    isBogon
    ;
  inherit fromIpv4Mapped toIpv4Mapped fromEui64;
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
  inherit any loopback;
}
