/*
  libnet.cidr

  Parse and operate on CIDR blocks (IPv4 and IPv6). Provides network,
  broadcast, and host derivation, prefix arithmetic (subnet, supernet),
  and set operations (summarize, exclude, intersect).

  Example:
    libnet.cidr.parse "192.0.2.0/24"
    => { _type = "cidr"; address = <ipv4 192.0.2.0>; prefix = 24; }

    libnet.cidr.toString (libnet.cidr.parse "2001:DB8::/32")
    => "2001:db8::/32"
*/
let
  bits = import ./internal/bits.nix;
  carry = import ./internal/carry.nix;
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;

  mk = addr: prefix: {
    _type = "cidr";
    address = addr;
    inherit prefix;
  };

  isV4 = addr: addr._type == "ipv4";
  isV6 = addr: addr._type == "ipv6";

  maxPrefix = addr: if isV4 addr then 32 else 128;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.cidr.parse: input must be a string"
    else
      let
        parts = parse'.splitOn "/" s;
      in
      if builtins.length parts != 2 then
        types.tryErr "libnet.cidr.parse: missing '/': \"${s}\""
      else
        let
          addrStr = builtins.elemAt parts 0;
          prefStr = builtins.elemAt parts 1;
          isV6Str = parse'.countOccurrences ":" addrStr > 0;
          addrRes = if isV6Str then ipv6.tryParse addrStr else ipv4.tryParse addrStr;
          prefInt = parse'.decimal prefStr;
        in
        if !addrRes.success then
          types.tryErr "libnet.cidr.parse: ${addrRes.error}"
        else if prefInt == null then
          types.tryErr "libnet.cidr.parse: invalid prefix \"${prefStr}\""
        else if prefInt > (maxPrefix addrRes.value) then
          types.tryErr "libnet.cidr.parse: prefix /${prefStr} out of range"
        else
          types.tryOk (mk addrRes.value prefInt);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    c:
    let
      s = if isV4 c.address then ipv4.toString c.address else ipv6.toString c.address;
    in
    "${s}/${builtins.toString c.prefix}";

  make =
    addr: prefix:
    if !(types.isIp addr) then
      builtins.throw "libnet.cidr.make: address must be ipv4 or ipv6"
    else if !(builtins.isInt prefix) || prefix < 0 || prefix > (maxPrefix addr) then
      builtins.throw "libnet.cidr.make: prefix out of range"
    else
      mk addr prefix;

  fromAddress =
    addr:
    if !(types.isIp addr) then
      builtins.throw "libnet.cidr.fromAddress: expected ipv4 or ipv6 value"
    else
      mk addr (maxPrefix addr);

  # ===== Accessors / predicates =====

  address = c: c.address;
  prefix = c: c.prefix;
  version = c: if isV4 c.address then 4 else 6;
  isIpv4 = c: isV4 c.address;
  isIpv6 = c: isV6 c.address;

  isValid = s: (tryParse s).success;
  is = types.isCidr;

  # ===== Mask helpers =====

  # v4 network mask as u32. p=0 → 0; p=32 → 0xFFFFFFFF.
  netmaskV4Int =
    p:
    if p == 0 then
      0
    else if p == 32 then
      bits.mask32
    else
      bits.shl (32 - p) (bits.mask p);

  hostmaskV4Int = p: bits.mask32 - (netmaskV4Int p);

  # Mask for word i (0..3) given overall prefix p.
  wordMaskIpv6 =
    i: p:
    let
      keep = p - 32 * i;
    in
    if keep <= 0 then
      0
    else if keep >= 32 then
      bits.mask32
    else
      bits.shl (32 - keep) (bits.mask keep);

  wordHostmaskIpv6 = i: p: bits.mask32 - (wordMaskIpv6 i p);

  # ===== Derived values =====

  network =
    c:
    let
      p = c.prefix;
      addr = c.address;
    in
    if isV4 addr then
      ipv4.fromInt (builtins.bitAnd addr.value (netmaskV4Int p))
    else
      ipv6.fromWords (
        builtins.genList (i: builtins.bitAnd (builtins.elemAt addr.words i) (wordMaskIpv6 i p)) 4
      );

  broadcast =
    c:
    if isV6 c.address then
      builtins.throw "libnet.cidr.broadcast: IPv6 has no broadcast"
    else
      let
        n = network c;
      in
      ipv4.fromInt (builtins.bitOr n.value (hostmaskV4Int c.prefix));

  topAddress =
    c:
    let
      n = network c;
      p = c.prefix;
    in
    if isV4 c.address then
      ipv4.fromInt (builtins.bitOr n.value (hostmaskV4Int p))
    else
      ipv6.fromWords (
        builtins.genList (i: builtins.bitOr (builtins.elemAt n.words i) (wordHostmaskIpv6 i p)) 4
      );

  netmask =
    c:
    if isV4 c.address then
      ipv4.fromInt (netmaskV4Int c.prefix)
    else
      ipv6.fromWords (builtins.genList (i: wordMaskIpv6 i c.prefix) 4);

  hostmask =
    c:
    if isV4 c.address then
      ipv4.fromInt (hostmaskV4Int c.prefix)
    else
      ipv6.fromWords (builtins.genList (i: wordHostmaskIpv6 i c.prefix) 4);

  size =
    c:
    let
      hostBits = (maxPrefix c.address) - c.prefix;
    in
    if hostBits > 62 then
      builtins.throw "libnet.cidr.size: block too large for Nix int (2^${builtins.toString hostBits}); IPv6 prefixes <= 65 exceed signed 63-bit range"
    else
      bits.pow2 hostBits;

  numHosts =
    c:
    let
      sz = size c;
      p = c.prefix;
    in
    if isV4 c.address then (if p >= 31 then sz else sz - 2) else sz;

  # /31 IPv4 and /127 IPv6 are point-to-point per RFC 3021 and RFC 6164 —
  # both addresses are usable, so firstHost = network and lastHost = top.
  firstHost =
    c:
    let
      n = network c;
      p = c.prefix;
    in
    if isV4 c.address then
      (if p >= 31 then n else ipv4.add 1 n)
    else
      (if p >= 127 then n else ipv6.add 1 n);

  lastHost =
    c:
    let
      top = topAddress c;
      p = c.prefix;
    in
    if isV4 c.address then (if p >= 31 then top else ipv4.sub 1 top) else top;

  # ===== Enumeration =====

  host =
    n: c:
    let
      sz = size c;
      idx = if n < 0 then sz + n else n;
    in
    if idx < 0 || idx >= sz then
      builtins.throw "libnet.cidr.host: index out of range [0, ${builtins.toString sz})"
    else
      let
        n' = network c;
      in
      if isV4 c.address then ipv4.add idx n' else ipv6.add idx n';

  hostsUnbounded =
    c:
    let
      nh = numHosts c;
      first = firstHost c;
      addFn = if isV4 c.address then ipv4.add else ipv6.add;
    in
    builtins.genList (i: addFn i first) nh;

  hosts =
    c:
    let
      sz = size c;
    in
    if sz > bits.pow2 16 then
      builtins.throw "libnet.cidr.hosts: block too large (${builtins.toString sz} addresses > 2^16); use host or hostsUnbounded"
    else
      hostsUnbounded c;

  # ===== Containment =====

  containsAddress =
    c: addr:
    if c.address._type != addr._type then
      false
    else
      let
        n = network c;
        t = topAddress c;
      in
      if isV4 addr then
        addr.value >= n.value && addr.value <= t.value
      else
        (ipv6.ge addr n) && (ipv6.le addr t);

  containsCidr =
    parent: child:
    if parent.address._type != child.address._type then
      false
    else if child.prefix < parent.prefix then
      false
    else
      containsAddress parent (network child);

  contains =
    c: x:
    if types.isIp x then
      containsAddress c x
    else if types.isCidr x then
      containsCidr c x
    else
      false;

  isSubnetOf = a: b: containsCidr b a;
  isSupernetOf = a: b: containsCidr a b;

  overlaps =
    a: b:
    if a.address._type != b.address._type then false else (containsCidr a b) || (containsCidr b a);

  # ===== Normalization & restructuring =====

  canonical = c: mk (network c) c.prefix;

  isCanonical =
    c:
    let
      n = network c;
    in
    if isV4 c.address then c.address.value == n.value else c.address.words == n.words;

  # Internal: ipv6 value = base + (i * 2^shift), computed directly on words.
  # Used by subnet for v6 where 2^(mp - newPrefix) can exceed pow2's 62-bit cap.
  # Preconditions (enforced by subnet caller): 0 <= shift < 128 when i > 0;
  # bits.shl (shift mod 32) i must fit in a Nix int.
  v6AddBlockOffset =
    shift: i: base:
    if i == 0 then
      base
    else
      let
        wordIdx = 3 - (shift / 32);
        inWord = shift - 32 * (shift / 32);
        shifted = bits.shl inWord i;
        lowPart = builtins.bitAnd shifted bits.mask32;
        highPart = if inWord == 0 then 0 else bits.shr (32 - inWord) i;
      in
      if wordIdx == 0 && highPart > 0 then
        builtins.throw "libnet.cidr.subnet: block offset overflow beyond 2^128"
      else
        let
          offsetOf =
            idx:
            if idx == wordIdx then
              lowPart
            else if idx == wordIdx - 1 then
              highPart
            else
              0;
          o0 = offsetOf 0;
          o1 = offsetOf 1;
          o2 = offsetOf 2;
          o3 = offsetOf 3;
          ws = base.words;
          w0 = builtins.elemAt ws 0;
          w1 = builtins.elemAt ws 1;
          w2 = builtins.elemAt ws 2;
          w3 = builtins.elemAt ws 3;
          r3 = carry.add32 w3 o3 0;
          r2 = carry.add32 w2 o2 r3.carry;
          r1 = carry.add32 w1 o1 r2.carry;
          r0 = carry.add32 w0 o0 r1.carry;
        in
        if r0.carry == 1 then
          builtins.throw "libnet.cidr.subnet: block offset overflow beyond 2^128"
        else
          ipv6.fromWords [
            r0.sum
            r1.sum
            r2.sum
            r3.sum
          ];

  subnet =
    n: c:
    if !(builtins.isInt n) || n < 0 then
      builtins.throw "libnet.cidr.subnet: n must be non-negative int"
    else
      let
        newPrefix = c.prefix + n;
        mp = maxPrefix c.address;
      in
      if newPrefix > mp then
        builtins.throw "libnet.cidr.subnet: resulting prefix /${builtins.toString newPrefix} exceeds max /${builtins.toString mp}"
      else if n > 16 then
        builtins.throw "libnet.cidr.subnet: n too large (>16); would produce > 2^16 subnets"
      else
        let
          count = bits.pow2 n;
          base = network c;
          bitsToShift = mp - newPrefix;
          mkBlock =
            if isV4 c.address then
              let
                blockSize = bits.pow2 bitsToShift;
              in
              i: mk (ipv4.add (i * blockSize) base) newPrefix
            else
              i: mk (v6AddBlockOffset bitsToShift i base) newPrefix;
        in
        builtins.genList mkBlock count;

  supernet =
    n: c:
    if !(builtins.isInt n) || n < 0 then
      builtins.throw "libnet.cidr.supernet: n must be non-negative int"
    else if n > c.prefix then
      builtins.throw "libnet.cidr.supernet: n exceeds current prefix"
    else
      canonical (mk c.address (c.prefix - n));

  # ===== Set algebra =====

  # Internal: are a and b canonical sibling halves of their parent at prefix-1?
  areSiblings =
    a: b:
    a.prefix == b.prefix
    && a.prefix > 0
    && a.address._type == b.address._type
    && isCanonical a
    && isCanonical b
    && !(eq a b)
    && containsCidr (canonical (mk a.address (a.prefix - 1))) a
    && containsCidr (canonical (mk a.address (a.prefix - 1))) b;

  mergeParent = a: canonical (mk a.address (a.prefix - 1));

  # Coalesce a list of CIDRs (same family) into a minimal set.
  # Uses a simple iterative stack approach after sorting.
  coalesceOne =
    cidrs:
    let
      canon = map canonical cidrs;
      sorted = sortCidrs canon;
      step =
        acc: cur:
        if acc == [ ] then
          [ cur ]
        else
          let
            top = builtins.elemAt acc (builtins.length acc - 1);
            rest = builtins.genList (i: builtins.elemAt acc i) (builtins.length acc - 1);
          in
          if eq top cur then
            acc
          else if containsCidr top cur then
            acc
          else if areSiblings top cur then
            step rest (mergeParent top)
          else
            acc ++ [ cur ];
    in
    builtins.foldl' step [ ] sorted;

  # Stable sort CIDRs by (family, network, prefix).
  sortCidrs = cidrs: builtins.sort (a: b: compare a b < 0) cidrs;

  summarize =
    cidrs:
    let
      v4s = builtins.filter (c: isV4 c.address) cidrs;
      v6s = builtins.filter (c: isV6 c.address) cidrs;
    in
    (coalesceOne v4s) ++ (coalesceOne v6s);

  # exclude parent child: minimal list of cidrs covering parent \ child.
  # Throws if child is not contained in parent.
  exclude =
    parent: child:
    if parent.address._type != child.address._type then
      builtins.throw "libnet.cidr.exclude: family mismatch"
    else if !(containsCidr parent child) then
      builtins.throw "libnet.cidr.exclude: child not contained in parent"
    else if eq parent child then
      [ ]
    else
      let
        # Recursively split parent, keeping the half that doesn't contain child.
        go =
          cur:
          if eq cur child then
            [ ]
          else
            let
              halves = subnet 1 cur;
              left = builtins.elemAt halves 0;
              right = builtins.elemAt halves 1;
            in
            if containsCidr left child then (go left) ++ [ right ] else [ left ] ++ (go right);
      in
      go (canonical parent);

  intersect =
    a: b:
    if a.address._type != b.address._type then
      null
    else if containsCidr a b then
      canonical b
    else if containsCidr b a then
      canonical a
    else
      null;

  # ===== Comparison =====

  eq =
    a: b:
    a.address._type == b.address._type
    && a.prefix == b.prefix
    && (
      let
        na = network a;
        nb = network b;
      in
      if isV4 a.address then na.value == nb.value else na.words == nb.words
    );

  compare =
    a: b:
    if isV4 a.address && isV6 b.address then
      -1
    else if isV6 a.address && isV4 b.address then
      1
    else
      let
        na = network a;
        nb = network b;
        addrCmp =
          if isV4 a.address then
            (
              if na.value < nb.value then
                -1
              else if na.value > nb.value then
                1
              else
                0
            )
          else
            ipv6.compare na nb;
      in
      if addrCmp != 0 then
        addrCmp
      else if a.prefix < b.prefix then
        -1
      else if a.prefix > b.prefix then
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
    make
    fromAddress
    ;
  inherit
    isValid
    is
    isIpv4
    isIpv6
    ;
  inherit address prefix version;
  inherit
    network
    broadcast
    topAddress
    netmask
    hostmask
    firstHost
    lastHost
    size
    numHosts
    ;
  inherit host hosts hostsUnbounded;
  inherit contains containsAddress containsCidr;
  inherit isSubnetOf isSupernetOf overlaps;
  inherit
    canonical
    isCanonical
    subnet
    supernet
    ;
  inherit summarize exclude intersect;
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
