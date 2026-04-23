/*
  libnet.ipRange

  An inclusive range of IP addresses stored as from / to endpoints.
  Supports containment, overlap, adjacency, enumeration, and
  conversion to and from a minimal CIDR set.

  Example:
    libnet.ipRange.parse "192.0.2.0-192.0.2.255"
    => { _type = "ipRange"; from = <ipv4>; to = <ipv4>; }

    map libnet.cidr.toString
      (libnet.ipRange.toCidrs (libnet.ipRange.parse "10.0.0.0-10.0.0.3"))
    => [ "10.0.0.0/30" ]
*/
let
  bits = import ./internal/bits.nix;
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  cidr = import ./cidr.nix;

  mk = f: t: {
    _type = "ipRange";
    from = f;
    to = t;
  };

  isV4 = addr: addr._type == "ipv4";
  isV6 = addr: addr._type == "ipv6";

  # Family-specific dispatchers
  addFor = addr: if isV4 addr then ipv4.add else ipv6.add;
  cmpFor = addr: if isV4 addr then ipv4.compare else ipv6.compare;
  leFor =
    addr: a: b:
    (cmpFor addr) a b <= 0;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.ipRange.parse: input must be a string"
    else
      let
        parts = parse'.splitOn "-" s;
        len = builtins.length parts;
      in
      if len != 2 then
        types.tryErr "libnet.ipRange.parse: missing '-' or too many: \"${s}\""
      else
        let
          fromStr = builtins.elemAt parts 0;
          toStr = builtins.elemAt parts 1;
          isV6Str = x: parse'.countOccurrences ":" x > 0;
          fromRes = if isV6Str fromStr then ipv6.tryParse fromStr else ipv4.tryParse fromStr;
          toRes = if isV6Str toStr then ipv6.tryParse toStr else ipv4.tryParse toStr;
        in
        if !fromRes.success then
          types.tryErr "libnet.ipRange.parse: invalid 'from': ${fromRes.error}"
        else if !toRes.success then
          types.tryErr "libnet.ipRange.parse: invalid 'to': ${toRes.error}"
        else if fromRes.value._type != toRes.value._type then
          types.tryErr "libnet.ipRange.parse: mixed families in \"${s}\""
        else if !(leFor fromRes.value fromRes.value toRes.value) then
          types.tryErr "libnet.ipRange.parse: 'from' > 'to' in \"${s}\""
        else
          types.tryOk (mk fromRes.value toRes.value);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    r:
    let
      fmt = if isV4 r.from then ipv4.toString else ipv6.toString;
    in
    "${fmt r.from}-${fmt r.to}";

  make =
    f: t:
    if !(types.isIp f) then
      builtins.throw "libnet.ipRange.make: 'from' must be ipv4 or ipv6"
    else if !(types.isIp t) then
      builtins.throw "libnet.ipRange.make: 'to' must be ipv4 or ipv6"
    else if f._type != t._type then
      builtins.throw "libnet.ipRange.make: mixed families"
    else if !(leFor f f t) then
      builtins.throw "libnet.ipRange.make: 'from' > 'to'"
    else
      mk f t;

  fromAddress =
    addr:
    if !(types.isIp addr) then
      builtins.throw "libnet.ipRange.fromAddress: expected ipv4 or ipv6 value"
    else
      mk addr addr;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isIpRange;
  isIpv4 = r: isV4 r.from;
  isIpv6 = r: isV6 r.from;
  isSingleton = r: if isV4 r.from then r.from.value == r.to.value else r.from.words == r.to.words;

  # ===== Accessors =====

  from = r: r.from;
  to = r: r.to;
  version = r: if isV4 r.from then 4 else 6;

  size = r: if isV4 r.from then r.to.value - r.from.value + 1 else ipv6.diff r.from r.to + 1;

  # ===== Containment & relationships =====

  contains =
    r: addr:
    if !(types.isIp addr) then
      false
    else if r.from._type != addr._type then
      false
    else
      let
        le = leFor r.from;
      in
      (le r.from addr) && (le addr r.to);

  overlaps =
    a: b:
    if a.from._type != b.from._type then
      false
    else
      let
        le = leFor a.from;
      in
      (le a.from b.to) && (le b.from a.to);

  isSubrangeOf =
    a: b:
    if a.from._type != b.from._type then
      false
    else
      let
        le = leFor a.from;
      in
      (le b.from a.from) && (le a.to b.to);

  isSuperrangeOf = a: b: isSubrangeOf b a;

  # Are a and b adjacent (no gap between them, non-overlapping)?
  isAdjacent =
    a: b:
    if a.from._type != b.from._type then
      false
    else
      let
        addOneA = (addFor a.from) 1 a.to;
        addOneB = (addFor b.from) 1 b.to;
        eqAddr = x: y: if isV4 x then x.value == y.value else x.words == y.words;
        aEndPlusOne = builtins.tryEval addOneA;
        bEndPlusOne = builtins.tryEval addOneB;
      in
      (aEndPlusOne.success && eqAddr aEndPlusOne.value b.from)
      || (bEndPlusOne.success && eqAddr bEndPlusOne.value a.from);

  merge =
    a: b:
    if a.from._type != b.from._type then
      null
    else if overlaps a b || isAdjacent a b then
      let
        le = leFor a.from;
        ge = x: y: le y x;
        newFrom = if le a.from b.from then a.from else b.from;
        newTo = if ge a.to b.to then a.to else b.to;
      in
      mk newFrom newTo
    else
      null;

  # ===== Enumeration =====

  addressesUnbounded =
    r:
    let
      sz = size r;
      add = addFor r.from;
    in
    builtins.genList (i: add i r.from) sz;

  addresses =
    r:
    let
      sz = size r;
    in
    if sz > bits.pow2 16 then
      builtins.throw "libnet.ipRange.addresses: range too large (${builtins.toString sz} > 2^16); use addressesUnbounded"
    else
      addressesUnbounded r;

  # ===== CIDR interop =====

  fromCidr =
    c:
    if !(types.isCidr c) then
      builtins.throw "libnet.ipRange.fromCidr: expected a cidr value"
    else
      mk (cidr.network c) (cidr.topAddress c);

  # Convert range to minimal set of CIDR blocks.
  toCidrs =
    r:
    let
      maxP = if isV4 r.from then 32 else 128;
      addOne = (addFor r.from) 1;
      atMax =
        addr:
        if isV4 addr then
          addr.value == bits.mask32
        else
          addr.words == [
            bits.mask32
            bits.mask32
            bits.mask32
            bits.mask32
          ];
      eqAddr = a: b: if isV4 a then a.value == b.value else a.words == b.words;
      le = leFor r.from;

      # Find smallest prefix p such that cidr(from, p) is aligned AND top <= to.
      findPrefix =
        curFrom: curTo:
        let
          go =
            p:
            if p > maxP then
              maxP
            else
              let
                c = cidr.make curFrom p;
                net = cidr.network c;
                top = cidr.topAddress c;
              in
              if (eqAddr net curFrom) && (le top curTo) then p else go (p + 1);
        in
        go 0;

      loop =
        acc: cur:
        if !(le cur r.to) then
          acc
        else
          let
            p = findPrefix cur r.to;
            block = cidr.make cur p;
            topOfBlock = cidr.topAddress block;
            accNext = acc ++ [ block ];
          in
          if atMax topOfBlock then accNext else loop accNext (addOne topOfBlock);
    in
    loop [ ] r.from;

  # ===== Comparison =====

  cmpAddrs = a: b: if isV4 a then ipv4.compare a b else ipv6.compare a b;

  compare =
    a: b:
    if isV4 a.from && isV6 b.from then
      -1
    else if isV6 a.from && isV4 b.from then
      1
    else
      let
        fc = cmpAddrs a.from b.from;
      in
      if fc != 0 then fc else cmpAddrs a.to b.to;

  eq = a: b: a == b;
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
    make
    fromAddress
    ;
  inherit
    isValid
    is
    isIpv4
    isIpv6
    isSingleton
    ;
  inherit
    from
    to
    size
    version
    ;
  inherit
    contains
    overlaps
    isSubrangeOf
    isSuperrangeOf
    isAdjacent
    merge
    ;
  inherit addresses addressesUnbounded;
  inherit toCidrs fromCidr;
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
