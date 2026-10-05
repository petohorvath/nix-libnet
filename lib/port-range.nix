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
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  port = import ./port.nix;

  portMax = 65535;

  # `first` and `last` are tagged Port values, parallel to how cidr stores
  # a tagged address and how ipRange stores tagged from/to ip values.
  mk = first: last: {
    _type = "portRange";
    from = first;
    to = last;
  };

  # ===== Parsing =====

  # Decimal port number from one side of a range, or null when invalid.
  parsePart =
    input:
    let
      number = parsing.decimal input;
    in
    if number == null then
      null
    else if number > portMax then
      null
    else
      number;

  /*
    Parse a port range without throwing, so callers can handle invalid
    input themselves.

    `input`: "8080" (single port), "5500-6000" (canonical), or
    "5500:6000" (iptables form); each port in [0, 65535].

    Returns a tryResult: `{ success = true; value = <portRange>; }` or
    `{ success = false; error = <message>; }`. Fails when from > to.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.portRange.parse: input must be a string"
    else
      let
        hyphenParts = parsing.splitOn "-" input;
        colonParts = parsing.splitOn ":" input;
        hasHyphen = builtins.length hyphenParts == 2;
        hasColon = builtins.length colonParts == 2 && !hasHyphen;
        isSingle = builtins.length hyphenParts == 1 && !hasColon;
        # Hyphen ("8000-8100") and colon ("8000:8100") forms both split
        # into a [from to] pair parsed the same way.
        fromPair =
          parts:
          let
            first = parsePart (builtins.elemAt parts 0);
            last = parsePart (builtins.elemAt parts 1);
          in
          if first == null || last == null then
            types.tryErr "libnet.portRange.parse: invalid range \"${input}\""
          else if first > last then
            types.tryErr "libnet.portRange.parse: from > to in \"${input}\""
          else
            types.tryOk (mk (port.fromInt first) (port.fromInt last));
      in
      if hasHyphen then
        fromPair hyphenParts
      else if hasColon then
        fromPair colonParts
      else if isSingle then
        let
          number = parsePart input;
        in
        if number == null then
          types.tryErr "libnet.portRange.parse: invalid port \"${input}\""
        else
          let
            portValue = port.fromInt number;
          in
          types.tryOk (mk portValue portValue)
      else
        types.tryErr "libnet.portRange.parse: malformed \"${input}\"";

  /*
    Parse a port range from text such as firewall or service settings.

    `input`: "8080" (single port), "5500-6000" (canonical), or
    "5500:6000" (iptables form); each port in [0, 65535].

    Returns a portRange value; throws on malformed input, out-of-range
    ports, or from > to.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Format a range in canonical hyphen form.

    `range`: portRange value.

    Returns "from-to", or just "from" for a single-port range.
  */
  toString =
    range:
    if port.eq range.from range.to then
      port.toString range.from
    else
      "${port.toString range.from}-${port.toString range.to}";

  /*
    Format a range in iptables colon form.

    `range`: portRange value.

    Returns "from:to", or just "from" for a single-port range.
  */
  toStringColon =
    range:
    if port.eq range.from range.to then
      port.toString range.from
    else
      "${port.toString range.from}:${port.toString range.to}";

  /*
    Build a range from raw integers. A port is just an int, so this
    parallels `port.fromInt` rather than `ipRange.make`; use `fromPort`
    to build from a tagged port.

    `first`: lowest port number, in [0, 65535].
    `last`: highest port number, in [first, 65535].

    Returns a portRange value; throws on non-integers, out-of-range
    numbers, or first > last.
  */
  make =
    first: last:
    if !(builtins.isInt first) || !(builtins.isInt last) then
      throw "libnet.portRange.make: from and to must be ints"
    else if first < 0 || first > portMax || last < 0 || last > portMax then
      throw "libnet.portRange.make: out of range [0, 65535]"
    else if first > last then
      throw "libnet.portRange.make: from > to"
    else
      mk (port.fromInt first) (port.fromInt last);

  /*
    Build a range holding exactly one port, parallel to
    `cidr.fromAddress` and `ipRange.fromAddress`.

    `portValue`: port value.

    Returns a single-port portRange; throws when given a non-port.
  */
  fromPort =
    portValue:
    if !(types.isPort portValue) then
      throw "libnet.portRange.fromPort: expected a port value"
    else
      mk portValue portValue;

  # ===== Predicates =====

  /*
    Check whether a string parses as a port range.

    `input`: candidate string.

    Returns true when `tryParse input` succeeds.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a portRange value.

    `value`: any value.

    Returns true when `value` is tagged `_type = "portRange"`.
  */
  is = value: types.isPortRange value;

  /*
    Check whether a range holds a single port.

    `range`: portRange value.

    Returns true when from equals to.
  */
  isSingleton = range: port.eq range.from range.to;

  # ===== Accessors =====

  /*
    Get the lowest port of a range.

    `range`: portRange value.

    Returns the tagged `from` port.
  */
  from = range: range.from;

  /*
    Get the highest port of a range.

    `range`: portRange value.

    Returns the tagged `to` port.
  */
  to = range: range.to;

  /*
    Count the ports in a range.

    `range`: portRange value.

    Returns `toInt to - toInt from + 1`.
  */
  size = range: port.toInt range.to - port.toInt range.from + 1;

  # ===== Containment =====

  /*
    Check whether a port lies inside a range.

    `range`: portRange value.
    `portValue`: value to test.

    Returns true when `portValue` is a port within [from, to]; false for
    non-port values.
  */
  contains =
    range: portValue:
    if !(types.isPort portValue) then
      false
    else
      port.le range.from portValue && port.le portValue range.to;

  /*
    Check whether two ranges share at least one port. Symmetric.

    `a`, `b`: portRange values.

    Returns true when the ranges intersect.
  */
  overlaps = a: b: port.le a.from b.to && port.le b.from a.to;

  /*
    Check whether one range lies within another, subject first like
    `cidr.isSubnetOf`.

    `a`: candidate inner range.
    `b`: candidate outer range.

    Returns true when `a` is a subset of `b` (including equal ranges).
  */
  isSubrangeOf = a: b: port.le b.from a.from && port.le a.to b.to;

  /*
    Check whether one range encloses another; inverse of `isSubrangeOf`.

    `a`: candidate outer range.
    `b`: candidate inner range.

    Returns true when `b` is a subset of `a` (including equal ranges).
  */
  isSuperrangeOf = a: b: isSubrangeOf b a;

  /*
    Check whether two ranges touch with no gap and no overlap. Compares
    plain ints, so a range ending at 65535 has no upward neighbour and
    nothing overflows.

    `a`, `b`: portRange values.

    Returns true when `a.to + 1 == b.from` or `b.to + 1 == a.from`.
  */
  isAdjacent =
    a: b:
    let
      aTo = port.toInt a.to;
      bTo = port.toInt b.to;
      aFrom = port.toInt a.from;
      bFrom = port.toInt b.from;
    in
    aTo + 1 == bFrom || bTo + 1 == aFrom;

  /*
    Combine two ranges into one when they overlap or touch.

    `a`, `b`: portRange values.

    Returns the spanning portRange, or null when a gap separates them.
  */
  merge =
    a: b:
    if overlaps a b || isAdjacent a b then mk (port.min a.from b.from) (port.max a.to b.to) else null;

  # ===== Enumeration =====

  /*
    List every port in a range with no size guard; the caller bounds the
    cost.

    `range`: portRange value.

    Returns the ports from `from` to `to` in ascending order.
  */
  portsUnbounded =
    range:
    let
      base = port.toInt range.from;
    in
    builtins.genList (i: port.fromInt (base + i)) (size range);

  /*
    List every port in a range, guarding against accidentally huge lists.

    `range`: portRange value.

    Returns the ports from `from` to `to` in ascending order; throws when
    the range holds more than 4096 ports (use `portsUnbounded`).
  */
  ports =
    range:
    let
      rangeSize = size range;
    in
    if rangeSize > bits.pow2 12 then
      throw "libnet.portRange.ports: range too large (${builtins.toString rangeSize} > 4096); use portsUnbounded"
    else
      portsUnbounded range;

  /*
    Index into a range, parallel to `cidr.hostAt` and
    `ipBindpoint.endpointAt`.

    `n`: 0-based offset from `from`; negative values count from the end.
    `range`: portRange value.

    Returns the selected port; throws when `n` falls outside the range.
  */
  portAt =
    n: range:
    let
      rangeSize = size range;
      index = if n < 0 then rangeSize + n else n;
    in
    if index < 0 || index >= rangeSize then
      throw "libnet.portRange.portAt: index out of range [0, ${builtins.toString rangeSize})"
    else
      port.add index range.from;

  # ===== Comparison =====

  /*
    Test two port ranges for equality.

    `a`, `b`: portRange values.

    Returns true when both have the same type tag, `from`, and `to`.
  */
  eq = a: b: types.hasSameTag a b && port.eq a.from b.from && port.eq a.to b.to;

  /*
    Order two ranges lexicographically on (from, to).

    `a`, `b`: portRange values.

    Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`.
  */
  compare =
    a: b:
    let
      fromOrder = port.compare a.from b.from;
    in
    if fromOrder != 0 then fromOrder else port.compare a.to b.to;

  /*
    Test whether one range sorts before another.

    `a`, `b`: portRange values.

    Returns true when `compare a b == -1`.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether one range sorts before or equal to another.

    `a`, `b`: portRange values.

    Returns true when `compare a b <= 0`.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether one range sorts after another.

    `a`, `b`: portRange values.

    Returns true when `compare a b == 1`.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether one range sorts after or equal to another.

    `a`, `b`: portRange values.

    Returns true when `compare a b >= 0`.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the earlier of two ranges in sort order.

    `a`, `b`: portRange values.

    Returns the lesser range; `a` when they compare equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the later of two ranges in sort order.

    `a`, `b`: portRange values.

    Returns the greater range; `a` when they compare equal.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    compare
    contains
    eq
    from
    fromPort
    ge
    gt
    is
    isAdjacent
    isSingleton
    isSubrangeOf
    isSuperrangeOf
    isValid
    le
    lt
    make
    max
    merge
    min
    overlaps
    parse
    portAt
    ports
    portsUnbounded
    size
    to
    toString
    toStringColon
    tryParse
    ;
}
