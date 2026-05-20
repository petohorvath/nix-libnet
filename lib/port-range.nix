/*
  libnet.portRange

  A contiguous inclusive range of ports. Parses hyphen ("8000-8100")
  and colon ("8000:8100") forms; supports containment, overlap,
  merging, and bounded enumeration.

  Example:
    libnet.portRange.parse "8000-8100"
    => { _type = "portRange";
         from = { _type = "port"; value = 8000; };
         to   = { _type = "port"; value = 8100; }; }

    libnet.portRange.size (libnet.portRange.parse "8000-8100")
    => 101
*/
let
  bits = import ./internal/bits.nix;
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  port = import ./port.nix;

  portMax = 65535;

  # `f` and `t` are tagged Port values, parallel to how cidr stores a
  # tagged address and how ipRange stores tagged from/to ip values.
  mk = f: t: {
    _type = "portRange";
    from = f;
    to = t;
  };

  # ===== Parsing =====

  parsePart =
    s:
    let
      n = parse'.decimal s;
    in
    if n == null then
      null
    else if n < 0 || n > portMax then
      null
    else
      n;

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.portRange.parse: input must be a string"
    else
      let
        hyphenParts = parse'.splitOn "-" s;
        colonParts = parse'.splitOn ":" s;
        hasHyphen = builtins.length hyphenParts == 2;
        hasColon = builtins.length colonParts == 2 && !hasHyphen;
        isSingle = builtins.length hyphenParts == 1 && !hasColon;
      in
      if hasHyphen then
        let
          f = parsePart (builtins.elemAt hyphenParts 0);
          t = parsePart (builtins.elemAt hyphenParts 1);
        in
        if f == null || t == null then
          types.tryErr "libnet.portRange.parse: invalid range \"${s}\""
        else if f > t then
          types.tryErr "libnet.portRange.parse: from > to in \"${s}\""
        else
          types.tryOk (mk (port.fromInt f) (port.fromInt t))
      else if hasColon then
        let
          f = parsePart (builtins.elemAt colonParts 0);
          t = parsePart (builtins.elemAt colonParts 1);
        in
        if f == null || t == null then
          types.tryErr "libnet.portRange.parse: invalid range \"${s}\""
        else if f > t then
          types.tryErr "libnet.portRange.parse: from > to in \"${s}\""
        else
          types.tryOk (mk (port.fromInt f) (port.fromInt t))
      else if isSingle then
        let
          p = parsePart s;
        in
        if p == null then
          types.tryErr "libnet.portRange.parse: invalid port \"${s}\""
        else
          let
            pt = port.fromInt p;
          in
          types.tryOk (mk pt pt)
      else
        types.tryErr "libnet.portRange.parse: malformed \"${s}\"";

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    pr:
    if port.eq pr.from pr.to then
      port.toString pr.from
    else
      "${port.toString pr.from}-${port.toString pr.to}";

  toStringColon =
    pr:
    if port.eq pr.from pr.to then
      port.toString pr.from
    else
      "${port.toString pr.from}:${port.toString pr.to}";

  make =
    f: t:
    if !(builtins.isInt f) || !(builtins.isInt t) then
      builtins.throw "libnet.portRange.make: from and to must be ints"
    else if f < 0 || f > portMax || t < 0 || t > portMax then
      builtins.throw "libnet.portRange.make: out of range [0, 65535]"
    else if f > t then
      builtins.throw "libnet.portRange.make: from > to"
    else
      mk (port.fromInt f) (port.fromInt t);

  fromPort =
    pt:
    if !(types.isPort pt) then
      builtins.throw "libnet.portRange.fromPort: expected a port value"
    else
      mk pt pt;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isPortRange;
  isSingleton = pr: port.eq pr.from pr.to;

  # ===== Accessors =====

  from = pr: pr.from;
  to = pr: pr.to;
  size = pr: port.toInt pr.to - port.toInt pr.from + 1;

  # ===== Containment =====

  contains = pr: pt: if !(types.isPort pt) then false else port.le pr.from pt && port.le pt pr.to;

  overlaps = a: b: port.le a.from b.to && port.le b.from a.to;

  isSubrangeOf = a: b: port.le b.from a.from && port.le a.to b.to;

  isSuperrangeOf = a: b: isSubrangeOf b a;

  # Touching with no gap and no overlap: a.to + 1 == b.from OR
  # b.to + 1 == a.from. Plain-int comparison, so a range ending at 65535
  # simply isn't adjacent upward (no overflow).
  isAdjacent =
    a: b:
    let
      aToI = port.toInt a.to;
      bToI = port.toInt b.to;
      aFromI = port.toInt a.from;
      bFromI = port.toInt b.from;
    in
    aToI + 1 == bFromI || bToI + 1 == aFromI;

  merge =
    a: b:
    if overlaps a b || isAdjacent a b then
      mk (port.min a.from b.from) (port.max a.to b.to)
    else
      null;

  # ===== Enumeration =====

  portsUnbounded =
    pr:
    let
      base = port.toInt pr.from;
    in
    builtins.genList (i: port.fromInt (base + i)) (size pr);

  ports =
    pr:
    let
      sz = size pr;
    in
    if sz > bits.pow2 12 then
      builtins.throw "libnet.portRange.ports: range too large (${builtins.toString sz} > 4096); use portsUnbounded"
    else
      portsUnbounded pr;

  # ===== Comparison =====

  eq = a: b: port.eq a.from b.from && port.eq a.to b.to;
  compare =
    a: b:
    let
      c = port.compare a.from b.from;
    in
    if c != 0 then c else port.compare a.to b.to;
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
    toStringColon
    make
    fromPort
    ;
  inherit isValid is isSingleton;
  inherit from to size;
  inherit
    contains
    overlaps
    isSubrangeOf
    isSuperrangeOf
    isAdjacent
    merge
    ;
  inherit ports portsUnbounded;
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
