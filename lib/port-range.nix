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
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  port = import ./port.nix;

  # `first` and `last` are tagged Port values, parallel to how cidr stores
  # a tagged address and how ipRange stores tagged from/to ip values.
  # Force both fields, so a constructor throws for a bad argument when
  # it builds the value rather than when a field is read.
  mk =
    first: last:
    builtins.seq first (
      builtins.seq last {
        _type = "portRange";
        from = first;
        to = last;
      }
    );

  # ===== Argument kinds =====

  # Each returns its argument, throwing for the wrong kind on behalf of
  # the public `function`.
  portRangeArgument = function: errors.expectKind "portRange.${function}" "portRange";
  portArgument = function: errors.expectKind "portRange.${function}" "port";
  intArgument = function: errors.expectType "portRange.${function}" "int";

  # Check both range operands of a binary `function`, then apply
  # `relation` to them. Unchecked helpers such as `order` and `sizeOf`
  # below take ranges the public function has already checked.
  binary =
    function: relation: a: b:
    relation (portRangeArgument function a) (portRangeArgument function b);

  # ===== Parsing =====

  # Decimal port number from one side of a range, or null when invalid.
  parsePort = parsing.decimal port.maxValue;

  /*
    Parse a port range without throwing, so callers can handle invalid
    input themselves.

    `input`: "8080" (single port), "5500-6000" (canonical), or
    "5500:6000" (iptables form); each port is decimal in [0, 65535]
    without leading zeros.

    Returns a tryResult: `{ success = true; value = <portRange>; }` or
    `{ success = false; error = <message>; }`. Fails when from > to.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr (errors.message "portRange.parse" "expected string, got ${errors.describe input}")
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
            first = parsePort (builtins.elemAt parts 0);
            last = parsePort (builtins.elemAt parts 1);
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
          number = parsePort input;
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
    "5500:6000" (iptables form); each port is decimal in [0, 65535]
    without leading zeros.

    Returns a portRange value; throws on malformed input, out-of-range
    ports, or from > to.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  formatWith =
    separator: range:
    if port.eq range.from range.to then
      port.toString range.from
    else
      "${port.toString range.from}${separator}${port.toString range.to}";

  /*
    Format a range in canonical hyphen form.

    `range`: portRange value.

    Returns "from-to", or just "from" for a single-port range.
  */
  toString = range: formatWith "-" (portRangeArgument "toString" range);

  /*
    Format a range in iptables colon form.

    `range`: portRange value.

    Returns "from:to", or just "from" for a single-port range.
  */
  toStringColon = range: formatWith ":" (portRangeArgument "toStringColon" range);

  /*
    Build a range from its two end ports, parallel to `ipRange.make`.

    `first`: lowest port value.
    `last`: highest port value, not below `first`.

    Returns a portRange value; throws on non-port values or first > last.
  */
  make =
    first: last:
    let
      lowest = portArgument "make" first;
      highest = portArgument "make" last;
    in
    if port.gt lowest highest then
      errors.fail "portRange.make" "from > to: ${port.toString lowest}-${port.toString highest}"
    else
      mk lowest highest;

  /*
    Build a range holding exactly one port, parallel to
    `cidr.fromAddress` and `ipRange.fromAddress`.

    `portValue`: port value.

    Returns a single-port portRange; throws when given a non-port.
  */
  fromPort =
    portValue:
    let
      checked = portArgument "fromPort" portValue;
    in
    mk checked checked;

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
  isSingleton =
    range:
    let
      checked = portRangeArgument "isSingleton" range;
    in
    port.eq checked.from checked.to;

  # ===== Accessors =====

  /*
    Get the lowest port of a range.

    `range`: portRange value.

    Returns the tagged `from` port.
  */
  from = range: (portRangeArgument "from" range).from;

  /*
    Get the highest port of a range.

    `range`: portRange value.

    Returns the tagged `to` port.
  */
  to = range: (portRangeArgument "to" range).to;

  sizeOf = range: port.toInt range.to - port.toInt range.from + 1;

  /*
    Count the ports in a range.

    `range`: portRange value.

    Returns `toInt to - toInt from + 1`.
  */
  size = range: sizeOf (portRangeArgument "size" range);

  # ===== Containment =====

  /*
    Check whether a port lies inside a range.

    `range`: portRange value.
    `portValue`: value to test.

    Returns true when `portValue` is a port within [from, to]; throws for
    a value of any other kind.
  */
  contains =
    range: portValue:
    let
      checkedRange = portRangeArgument "contains" range;
      checkedPort = portArgument "contains" portValue;
    in
    port.le checkedRange.from checkedPort && port.le checkedPort checkedRange.to;

  overlapping = a: b: port.le a.from b.to && port.le b.from a.to;

  /*
    Check whether two ranges share at least one port. Symmetric.

    `a`, `b`: portRange values.

    Returns true when the ranges intersect.
  */
  overlaps = binary "overlaps" overlapping;

  subrange = a: b: port.le b.from a.from && port.le a.to b.to;

  /*
    Check whether one range lies within another, subject first like
    `cidr.isSubnetOf`.

    `a`: candidate inner range.
    `b`: candidate outer range.

    Returns true when `a` is a subset of `b` (including equal ranges).
  */
  isSubrangeOf = binary "isSubrangeOf" subrange;

  /*
    Check whether one range encloses another; inverse of `isSubrangeOf`.

    `a`: candidate outer range.
    `b`: candidate inner range.

    Returns true when `b` is a subset of `a` (including equal ranges).
  */
  isSuperrangeOf = binary "isSuperrangeOf" (a: b: subrange b a);

  adjacent =
    a: b:
    let
      aTo = port.toInt a.to;
      bTo = port.toInt b.to;
      aFrom = port.toInt a.from;
      bFrom = port.toInt b.from;
    in
    aTo + 1 == bFrom || bTo + 1 == aFrom;

  /*
    Check whether two ranges touch with no gap and no overlap. Compares
    plain ints, so a range ending at 65535 has no upward neighbour and
    nothing overflows.

    `a`, `b`: portRange values.

    Returns true when `a.to + 1 == b.from` or `b.to + 1 == a.from`.
  */
  isAdjacent = binary "isAdjacent" adjacent;

  /*
    Combine two ranges into one when they overlap or touch.

    `a`, `b`: portRange values.

    Returns the spanning portRange, or null when a gap separates them.
  */
  merge = binary "merge" (
    a: b:
    if overlapping a b || adjacent a b then mk (port.min a.from b.from) (port.max a.to b.to) else null
  );

  # ===== Enumeration =====

  listPorts =
    range:
    let
      base = port.toInt range.from;
    in
    builtins.genList (i: port.fromInt (base + i)) (sizeOf range);

  /*
    List every port in a range with no size guard; the caller bounds the
    cost.

    `range`: portRange value.

    Returns the ports from `from` to `to` in ascending order.
  */
  portsUnbounded = range: listPorts (portRangeArgument "portsUnbounded" range);

  /*
    List every port in a range, guarding against accidentally huge lists.

    `range`: portRange value.

    Returns the ports from `from` to `to` in ascending order; throws when
    the range holds more than 4096 ports (use `portsUnbounded`).
  */
  ports =
    range:
    let
      checked = portRangeArgument "ports" range;
      rangeSize = sizeOf checked;
    in
    if rangeSize > bits.pow2 12 then
      errors.fail "portRange.ports" "range too large (${builtins.toString rangeSize} > 4096); use portsUnbounded"
    else
      listPorts checked;

  /*
    Index into a range, parallel to `cidr.addressAt` and
    `ipBindpoint.endpointAt`.

    `n`: 0-based offset from `from`; negative values count from the end.
    `range`: portRange value.

    Returns the selected port; throws when `n` is not an integer or falls
    outside the range.
  */
  portAt =
    n: range:
    let
      offset = intArgument "portAt" n;
      checked = portRangeArgument "portAt" range;
      rangeSize = sizeOf checked;
      index = if offset < 0 then rangeSize + offset else offset;
    in
    if index < 0 || index >= rangeSize then
      errors.fail "portRange.portAt" "index out of range [0, ${builtins.toString rangeSize}): ${builtins.toString offset}"
    else
      port.add index checked.from;

  # ===== Comparison =====

  /*
    Test two port ranges for equality.

    `a`, `b`: portRange values.

    Returns true when both have the same type tag, `from`, and `to`.
  */
  eq = a: b: types.bothHaveTag types.tags.portRange a b && port.eq a.from b.from && port.eq a.to b.to;

  order =
    a: b:
    let
      fromOrder = port.compare a.from b.from;
    in
    if fromOrder != 0 then fromOrder else port.compare a.to b.to;

  /*
    Order two ranges lexicographically on (from, to).

    `a`, `b`: portRange values.

    Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`.
  */
  compare = binary "compare" order;

  /*
    Test whether one range sorts before another.

    `a`, `b`: portRange values.

    Returns true when `compare a b == -1`.
  */
  lt = binary "lt" (a: b: order a b == -1);

  /*
    Test whether one range sorts before or equal to another.

    `a`, `b`: portRange values.

    Returns true when `compare a b <= 0`.
  */
  le = binary "le" (a: b: order a b <= 0);

  /*
    Test whether one range sorts after another.

    `a`, `b`: portRange values.

    Returns true when `compare a b == 1`.
  */
  gt = binary "gt" (a: b: order a b == 1);

  /*
    Test whether one range sorts after or equal to another.

    `a`, `b`: portRange values.

    Returns true when `compare a b >= 0`.
  */
  ge = binary "ge" (a: b: order a b >= 0);

  /*
    Pick the earlier of two ranges in sort order.

    `a`, `b`: portRange values.

    Returns the lesser range; `a` when they compare equal.
  */
  min = binary "min" (a: b: if order a b <= 0 then a else b);

  /*
    Pick the later of two ranges in sort order.

    `a`, `b`: portRange values.

    Returns the greater range; `a` when they compare equal.
  */
  max = binary "max" (a: b: if order a b >= 0 then a else b);
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
