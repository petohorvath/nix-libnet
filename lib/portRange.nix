let
  bits = import ./internal/bits.nix;
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  port = import ./port.nix;

  portMax = 65535;

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
          types.tryOk (mk f t)
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
          types.tryOk (mk f t)
      else if isSingle then
        let
          p = parsePart s;
        in
        if p == null then
          types.tryErr "libnet.portRange.parse: invalid port \"${s}\""
        else
          types.tryOk (mk p p)
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
    if pr.from == pr.to then
      builtins.toString pr.from
    else
      "${builtins.toString pr.from}-${builtins.toString pr.to}";

  toStringColon =
    pr:
    if pr.from == pr.to then
      builtins.toString pr.from
    else
      "${builtins.toString pr.from}:${builtins.toString pr.to}";

  make =
    f: t:
    if !(builtins.isInt f) || !(builtins.isInt t) then
      builtins.throw "libnet.portRange.make: from and to must be ints"
    else if f < 0 || f > portMax || t < 0 || t > portMax then
      builtins.throw "libnet.portRange.make: out of range [0, 65535]"
    else if f > t then
      builtins.throw "libnet.portRange.make: from > to"
    else
      mk f t;

  singleton =
    pt:
    if !(types.isPort pt) then
      builtins.throw "libnet.portRange.singleton: expected a port value"
    else
      mk pt.value pt.value;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isPortRange;
  isSingleton = pr: pr.from == pr.to;

  # ===== Accessors =====

  from = pr: pr.from;
  to = pr: pr.to;
  size = pr: pr.to - pr.from + 1;

  # ===== Containment =====

  contains = pr: pt: if !(types.isPort pt) then false else pt.value >= pr.from && pt.value <= pr.to;

  overlaps = a: b: a.from <= b.to && b.from <= a.to;

  isSubrangeOf = a: b: b.from <= a.from && a.to <= b.to;

  isSuperrangeOf = a: b: isSubrangeOf b a;

  # Adjacent: a.to + 1 == b.from OR b.to + 1 == a.from
  merge =
    a: b:
    if overlaps a b || a.to + 1 == b.from || b.to + 1 == a.from then
      let
        newFrom = if a.from < b.from then a.from else b.from;
        newTo = if a.to > b.to then a.to else b.to;
      in
      mk newFrom newTo
    else
      null;

  # ===== Enumeration =====

  portsUnbounded = pr: builtins.genList (i: port.fromInt (pr.from + i)) (size pr);

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

  eq = a: b: a.from == b.from && a.to == b.to;
  compare =
    a: b:
    if a.from < b.from then
      -1
    else if a.from > b.from then
      1
    else if a.to < b.to then
      -1
    else if a.to > b.to then
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
    toStringColon
    make
    singleton
    ;
  inherit isValid is isSingleton;
  inherit from to size;
  inherit
    contains
    overlaps
    isSubrangeOf
    isSuperrangeOf
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
