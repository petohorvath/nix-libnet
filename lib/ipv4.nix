/*
  libnet.ipv4

  Parse, format, compare, and do arithmetic on IPv4 addresses. The
  canonical internal form is a single u32 carried on a tagged attrset.

  Note: `diff a b` returns `toInt b - toInt a` (second arg minus first),
  matching the other scalar modules (ipv6, mac, port) for consistency.

  Example:
    libnet.ipv4.parse "192.0.2.1"
    => { _type = "ipv4"; value = 3221225985; }

    libnet.ipv4.toString (libnet.ipv4.next (libnet.ipv4.parse "10.0.0.1"))
    => "10.0.0.2"
*/
let
  address = import ./internal/address.nix;
  bits = import ./internal/bits.nix;
  errors = import ./internal/errors.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  # Internal constructor; assumes `value` is already validated.
  mk = value: {
    _type = "ipv4";
    inherit value;
  };

  # An IPv4 argument of `function`, which throws for any other kind.
  ipv4Argument = function: errors.expectKind "ipv4.${function}" "ipv4";

  valueOf = function: ip: (ipv4Argument function ip).value;

  # Apply `f` to the integer of an IPv4 argument of `function`.
  withValue =
    function: f: ip:
    let
      value = valueOf function ip;
    in
    builtins.seq value (f value);

  parseError = detail: types.tryErr (errors.message "ipv4.parse" detail);

  bytesOf = value: [
    (bits.bits 24 8 value)
    (bits.bits 16 8 value)
    (bits.bits 8 8 value)
    (bits.bits 0 8 value)
  ];

  format = value: builtins.concatStringsSep "." (map builtins.toString (bytesOf value));

  arithmetic = address.scalar {
    typeName = "ipv4";
    maxValue = bits.mask32;
    format = ip: format ip.value;
  };

  # ===== Conversion =====

  /*
    Build an address from its 32-bit integer value.

    `n`: integer in [0, 4294967295].

    Returns an IPv4 value; throws on a non-integer or out-of-range input.
  */
  fromInt =
    n:
    let
      value = errors.expectType "ipv4.fromInt" "int" n;
    in
    if value < 0 || value > bits.mask32 then
      errors.fail "ipv4.fromInt" "out of range [0, 4294967295]: ${builtins.toString value}"
    else
      mk value;

  /*
    Get the 32-bit integer value of an address.

    `ip`: IPv4 value.

    Returns an integer in [0, 4294967295].
  */
  toInt = valueOf "toInt";

  /*
    Build an address from its four bytes (the RFC 791 octets), most
    significant first, named like `ipv6.fromBytes` and `mac.fromBytes`.

    `bytes`: list of exactly 4 integers, each in [0, 255].

    Returns an IPv4 value; throws on a wrong length or an invalid byte.
  */
  fromBytes =
    bytes:
    let
      checkedBytes = address.intList "ipv4.fromBytes" {
        count = 4;
        part = "byte";
        maxValue = 255;
      } bytes;
    in
    builtins.seq checkedBytes (
      mk (builtins.foldl' (accumulated: byte: accumulated * bits.pow2_8 + byte) 0 checkedBytes)
    );

  /*
    Split an address into its four bytes, named like `ipv6.toBytes` and
    `mac.toBytes`.

    `ip`: IPv4 value.

    Returns a list of 4 integers in [0, 255], most significant first.
  */
  toBytes = withValue "toBytes" bytesOf;

  # ===== Parsing & formatting =====

  /*
    Parse a dotted-quad string without throwing, for validating untrusted
    input. Octets with leading zeros or above 255 are rejected.

    `input`: string such as "192.0.2.1".

    Returns a tryParse result: `{ success, value, error }`, where `value`
    is the IPv4 value on success and `error` describes the failure.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      parseError "expected string, got ${errors.describe input}"
    else
      let
        parts = parsing.splitOn "." input;
        partCount = builtins.length parts;
        octets = map parsing.octet parts;
      in
      if partCount != 4 then
        parseError "must have 4 octets, got ${builtins.toString partCount}: \"${input}\""
      else if builtins.elem null octets then
        parseError "invalid octet in \"${input}\""
      else
        types.tryOk (fromBytes octets);

  /*
    Parse a dotted-quad string, for trusted configuration values.

    `input`: string such as "192.0.2.1".

    Returns an IPv4 value; throws on malformed input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Format an address in canonical dotted-quad form.

    `ip`: IPv4 value.

    Returns a string such as "192.0.2.1".
  */
  toString = withValue "toString" format;

  /*
    Format an address as its reverse-DNS name.

    `ip`: IPv4 value.

    Returns a string such as "1.2.0.192.in-addr.arpa" for 192.0.2.1.
  */
  toArpa =
    ip:
    let
      bytes = bytesOf (valueOf "toArpa" ip);
      byteText = i: builtins.toString (builtins.elemAt bytes i);
    in
    "${byteText 3}.${byteText 2}.${byteText 1}.${byteText 0}.in-addr.arpa";

  # ===== Predicates =====

  /*
    Check whether a string parses as an IPv4 address.

    `input`: value to check; non-strings yield false.

    Returns a Boolean.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a parsed IPv4 value by its `_type` tag, as
    opposed to `isValid`, which checks whether a string parses.

    `value`: any value.

    Returns a Boolean; raw strings yield false.
  */
  is = value: types.isIpv4 value;

  # Inclusive bounds of the special-purpose blocks used by the predicates.
  class10Start = 10 * bits.pow2_24;
  class10End = 11 * bits.pow2_24 - 1;
  class172Start = 172 * bits.pow2_24 + 16 * bits.pow2_16;
  class172End = 172 * bits.pow2_24 + 32 * bits.pow2_16 - 1;
  class192Start = 192 * bits.pow2_24 + 168 * bits.pow2_16;
  class192End = 192 * bits.pow2_24 + 169 * bits.pow2_16 - 1;
  shared100Start = 100 * bits.pow2_24 + 64 * bits.pow2_16;
  shared100End = 100 * bits.pow2_24 + 128 * bits.pow2_16 - 1;
  protocol192Start = 192 * bits.pow2_24;
  protocol192End = 192 * bits.pow2_24 + bits.pow2_8 - 1;
  benchmarking198Start = 198 * bits.pow2_24 + 18 * bits.pow2_16;
  benchmarking198End = 198 * bits.pow2_24 + 20 * bits.pow2_16 - 1;

  /*
    Check whether an address is loopback (127.0.0.0/8).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isLoopback = withValue "isLoopback" (
    value: value >= 127 * bits.pow2_24 && value <= 128 * bits.pow2_24 - 1
  );

  /*
    Check whether an address is private (RFC 1918: 10.0.0.0/8,
    172.16.0.0/12, 192.168.0.0/16).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isPrivate = withValue "isPrivate" (
    value:
    (value >= class10Start && value <= class10End)
    || (value >= class172Start && value <= class172End)
    || (value >= class192Start && value <= class192End)
  );

  /*
    Check whether an address is link-local (169.254.0.0/16).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isLinkLocal = withValue "isLinkLocal" (
    value:
    value >= 169 * bits.pow2_24 + 254 * bits.pow2_16
    && value <= 169 * bits.pow2_24 + 255 * bits.pow2_16 - 1
  );

  /*
    Check whether an address is multicast (224.0.0.0/4).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isMulticast = withValue "isMulticast" (
    value: value >= 224 * bits.pow2_24 && value <= 240 * bits.pow2_24 - 1
  );

  /*
    Check whether an address is the limited broadcast address
    255.255.255.255.

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isBroadcast = withValue "isBroadcast" (value: value == bits.mask32);

  /*
    Check whether an address is the unspecified address 0.0.0.0.

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isUnspecified = withValue "isUnspecified" (value: value == 0);

  /*
    Check whether an address is reserved for future use (240.0.0.0/4,
    excluding the broadcast address 255.255.255.255).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isReserved = withValue "isReserved" (
    value: value >= 240 * bits.pow2_24 && value <= bits.mask32 - 1
  );

  /*
    Check whether an address is in a documentation block (192.0.2.0/24,
    198.51.100.0/24, 203.0.113.0/24).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isDocumentation = withValue "isDocumentation" (
    value:
    (
      value >= 192 * bits.pow2_24 + 0 * bits.pow2_16 + 2 * bits.pow2_8
      && value <= 192 * bits.pow2_24 + 0 * bits.pow2_16 + 3 * bits.pow2_8 - 1
    )
    || (
      value >= 198 * bits.pow2_24 + 51 * bits.pow2_16 + 100 * bits.pow2_8
      && value <= 198 * bits.pow2_24 + 51 * bits.pow2_16 + 101 * bits.pow2_8 - 1
    )
    || (
      value >= 203 * bits.pow2_24 + 0 * bits.pow2_16 + 113 * bits.pow2_8
      && value <= 203 * bits.pow2_24 + 0 * bits.pow2_16 + 114 * bits.pow2_8 - 1
    )
  );

  /*
    Check whether an address is in 0.0.0.0/8, "this host on this network"
    (RFC 1122 §3.2.1.3).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isThisNetwork = withValue "isThisNetwork" (value: value < bits.pow2_24);

  /*
    Check whether an address is in the shared address space used for
    carrier-grade NAT (100.64.0.0/10, RFC 6598).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isSharedAddressSpace = withValue "isSharedAddressSpace" (
    value: value >= shared100Start && value <= shared100End
  );

  /*
    Check whether an address is an IETF protocol assignment
    (192.0.0.0/24, RFC 6890).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isProtocolAssignment = withValue "isProtocolAssignment" (
    value: value >= protocol192Start && value <= protocol192End
  );

  /*
    Check whether an address is in the benchmarking block (198.18.0.0/15,
    RFC 2544).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isBenchmarking = withValue "isBenchmarking" (
    value: value >= benchmarking198Start && value <= benchmarking198End
  );

  /*
    Check whether an address is not globally routable: it matches any of
    the special-purpose predicates in this module.

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isBogon =
    argument:
    let
      ip = ipv4Argument "isBogon" argument;
    in
    isLoopback ip
    || isPrivate ip
    || isLinkLocal ip
    || isMulticast ip
    || isReserved ip
    || isDocumentation ip
    || isUnspecified ip
    || isBroadcast ip
    || isThisNetwork ip
    || isSharedAddressSpace ip
    || isProtocolAssignment ip
    || isBenchmarking ip;

  /*
    Check whether an address is globally routable. IPv4 has no transition
    forms like IPv6's IPv4-mapped, IPv4-compatible, or 6to4 addresses, so
    this is exactly `!isBogon`; `ipv6.isGlobal` is stricter.

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isGlobal = ip: !(isBogon (ipv4Argument "isGlobal" ip));

  # ===== Arithmetic =====

  /*
    Offset an address by an integer; curried so `add n` can be mapped.

    `n`: integer offset; may be negative.
    `ip`: IPv4 value.

    Returns an IPv4 value; throws if `n` is not an integer or the result
    leaves the address space.
  */
  add = n: ip: arithmetic.add "ipv4.add" n (ipv4Argument "add" ip);

  /*
    Offset an address downwards by an integer.

    `n`: integer to subtract; may be negative.
    `ip`: IPv4 value.

    Returns an IPv4 value; throws if `n` is not an integer or the result
    leaves the address space.
  */
  sub = n: ip: arithmetic.sub "ipv4.sub" n (ipv4Argument "sub" ip);

  /*
    Measure the distance between two addresses.

    `a`: IPv4 value to measure from.
    `b`: IPv4 value to measure to.

    Returns `toInt b - toInt a`, negative when `b` precedes `a`.
  */
  diff = a: b: valueOf "diff" b - valueOf "diff" a;

  /*
    Get the address one above `ip`. Equivalent to `add 1`, so it can be
    mapped over a list of addresses.

    `ip`: IPv4 value.

    Returns an IPv4 value; throws at 255.255.255.255.
  */
  next = ip: arithmetic.add "ipv4.next" 1 (ipv4Argument "next" ip);

  /*
    Get the address one below `ip`. Equivalent to `sub 1`, so it can be
    mapped over a list of addresses.

    `ip`: IPv4 value.

    Returns an IPv4 value; throws at 0.0.0.0.
  */
  prev = ip: arithmetic.sub "ipv4.prev" 1 (ipv4Argument "prev" ip);

  # ===== Comparison =====

  # Order two addresses for the public function `function`, which throws
  # for any argument that is not an IPv4 value, including an IPv6 one.
  compareFor =
    function: a: b:
    let
      left = valueOf function a;
      right = valueOf function b;
    in
    if left < right then
      -1
    else if left > right then
      1
    else
      0;

  /*
    Check whether two values are the same address. Never throws for
    values of a different `_type`.

    `a`, `b`: IPv4 values.

    Returns true when both tag and value match.
  */
  eq = a: b: types.bothHaveTag types.tags.ipv4 a b && a.value == b.value;

  /*
    Order two addresses numerically.

    `a`, `b`: IPv4 values.

    Returns -1 if `a < b`, 0 if equal, 1 if `a > b`.
  */
  compare = compareFor "compare";

  /*
    Check whether `a` sorts before `b`.

    `a`, `b`: IPv4 values.

    Returns a Boolean.
  */
  lt = a: b: compareFor "lt" a b == -1;

  /*
    Check whether `a` sorts before or equal to `b`.

    `a`, `b`: IPv4 values.

    Returns a Boolean.
  */
  le = a: b: compareFor "le" a b <= 0;

  /*
    Check whether `a` sorts after `b`.

    `a`, `b`: IPv4 values.

    Returns a Boolean.
  */
  gt = a: b: compareFor "gt" a b == 1;

  /*
    Check whether `a` sorts after or equal to `b`.

    `a`, `b`: IPv4 values.

    Returns a Boolean.
  */
  ge = a: b: compareFor "ge" a b >= 0;

  /*
    Pick the lower of two addresses.

    `a`, `b`: IPv4 values.

    Returns `a` when the two are equal.
  */
  min = a: b: if compareFor "min" a b <= 0 then a else b;

  /*
    Pick the higher of two addresses.

    `a`, `b`: IPv4 values.

    Returns `a` when the two are equal.
  */
  max = a: b: if compareFor "max" a b >= 0 then a else b;

  # ===== Constants =====

  unspecified = mk 0;
  broadcast = mk bits.mask32;
  loopback = fromBytes [
    127
    0
    0
    1
  ];
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
    ge
    gt
    is
    isBenchmarking
    isBogon
    isBroadcast
    isDocumentation
    isGlobal
    isLinkLocal
    isLoopback
    isMulticast
    isPrivate
    isProtocolAssignment
    isReserved
    isSharedAddressSpace
    isThisNetwork
    isUnspecified
    isValid
    le
    loopback
    lt
    max
    min
    next
    parse
    prev
    sub
    toArpa
    toBytes
    toInt
    toString
    tryParse
    unspecified
    ;
}
