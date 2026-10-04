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
  bits = import ./internal/bits.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  # Internal constructor; assumes `value` is already validated.
  mk = value: {
    _type = "ipv4";
    inherit value;
  };

  # ===== Conversion =====

  /*
    Build an address from its 32-bit integer value.

    `n`: integer in [0, 4294967295].

    Returns an IPv4 value; throws on a non-integer or out-of-range input.
  */
  fromInt =
    n:
    if !(builtins.isInt n) || n < 0 || n > bits.mask32 then
      throw "libnet.ipv4.fromInt: value out of range [0, 4294967295]: ${builtins.toString n}"
    else
      mk n;

  /*
    Get the 32-bit integer value of an address.

    `ip`: IPv4 value.

    Returns an integer in [0, 4294967295].
  */
  toInt = ip: ip.value;

  /*
    Build an address from its four octets, most significant first.

    `octets`: list of exactly 4 integers, each in [0, 255].

    Returns an IPv4 value; throws on a wrong length or an invalid octet.
  */
  fromOctets =
    octets:
    if !(builtins.isList octets) || builtins.length octets != 4 then
      throw "libnet.ipv4.fromOctets: expected list of 4 ints"
    else if builtins.any (octet: !(builtins.isInt octet) || octet < 0 || octet > 255) octets then
      throw "libnet.ipv4.fromOctets: each octet must be int in [0, 255]"
    else
      mk (builtins.foldl' (accumulated: octet: accumulated * bits.pow2_8 + octet) 0 octets);

  /*
    Split an address into its four octets.

    `ip`: IPv4 value.

    Returns a list of 4 integers in [0, 255], most significant first.
  */
  toOctets =
    ip:
    let
      inherit (ip) value;
    in
    [
      (bits.bits 24 8 value)
      (bits.bits 16 8 value)
      (bits.bits 8 8 value)
      (bits.bits 0 8 value)
    ];

  /*
    Alias of `fromOctets`. "Octet" is the IPv4 term (RFC 791); "byte"
    matches `mac` and `ipv6` for cross-family discoverability.

    `octets`: list of exactly 4 integers, each in [0, 255].

    Returns an IPv4 value; throws on a wrong length or an invalid octet.
  */
  fromBytes = octets: fromOctets octets;

  /*
    Alias of `toOctets`, named like `mac.toBytes` and `ipv6.toBytes` for
    cross-family discoverability.

    `ip`: IPv4 value.

    Returns a list of 4 integers in [0, 255], most significant first.
  */
  toBytes = ip: toOctets ip;

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
      types.tryErr "libnet.ipv4.parse: input must be a string"
    else
      let
        parts = parsing.splitOn "." input;
        partCount = builtins.length parts;
        octets = map parsing.octet parts;
      in
      if partCount != 4 then
        types.tryErr "libnet.ipv4.parse: must have 4 octets, got ${builtins.toString partCount}: \"${input}\""
      else if builtins.elem null octets then
        types.tryErr "libnet.ipv4.parse: invalid octet in \"${input}\""
      else
        types.tryOk (fromOctets octets);

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
  toString = ip: builtins.concatStringsSep "." (map builtins.toString (toOctets ip));

  /*
    Format an address as its reverse-DNS name.

    `ip`: IPv4 value.

    Returns a string such as "1.2.0.192.in-addr.arpa" for 192.0.2.1.
  */
  toArpa =
    ip:
    let
      octets = toOctets ip;
      octetText = i: builtins.toString (builtins.elemAt octets i);
    in
    "${octetText 3}.${octetText 2}.${octetText 1}.${octetText 0}.in-addr.arpa";

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
  isLoopback = ip: ip.value >= 127 * bits.pow2_24 && ip.value <= 128 * bits.pow2_24 - 1;

  /*
    Check whether an address is private (RFC 1918: 10.0.0.0/8,
    172.16.0.0/12, 192.168.0.0/16).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isPrivate =
    ip:
    (ip.value >= class10Start && ip.value <= class10End)
    || (ip.value >= class172Start && ip.value <= class172End)
    || (ip.value >= class192Start && ip.value <= class192End);

  /*
    Check whether an address is link-local (169.254.0.0/16).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isLinkLocal =
    ip:
    ip.value >= 169 * bits.pow2_24 + 254 * bits.pow2_16
    && ip.value <= 169 * bits.pow2_24 + 255 * bits.pow2_16 - 1;

  /*
    Check whether an address is multicast (224.0.0.0/4).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isMulticast = ip: ip.value >= 224 * bits.pow2_24 && ip.value <= 240 * bits.pow2_24 - 1;

  /*
    Check whether an address is the limited broadcast address
    255.255.255.255.

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isBroadcast = ip: ip.value == bits.mask32;

  /*
    Check whether an address is the unspecified address 0.0.0.0.

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isUnspecified = ip: ip.value == 0;

  /*
    Check whether an address is reserved for future use (240.0.0.0/4,
    excluding the broadcast address 255.255.255.255).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isReserved = ip: ip.value >= 240 * bits.pow2_24 && ip.value <= bits.mask32 - 1;

  /*
    Check whether an address is in a documentation block (192.0.2.0/24,
    198.51.100.0/24, 203.0.113.0/24).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isDocumentation =
    ip:
    let
      inherit (ip) value;
    in
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
    );

  /*
    Check whether an address is in 0.0.0.0/8, "this host on this network"
    (RFC 1122 §3.2.1.3).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isThisNetwork = ip: ip.value < bits.pow2_24;

  /*
    Check whether an address is in the shared address space used for
    carrier-grade NAT (100.64.0.0/10, RFC 6598).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isSharedAddressSpace = ip: ip.value >= shared100Start && ip.value <= shared100End;

  /*
    Check whether an address is an IETF protocol assignment
    (192.0.0.0/24, RFC 6890).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isProtocolAssignment = ip: ip.value >= protocol192Start && ip.value <= protocol192End;

  /*
    Check whether an address is in the benchmarking block (198.18.0.0/15,
    RFC 2544).

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isBenchmarking = ip: ip.value >= benchmarking198Start && ip.value <= benchmarking198End;

  /*
    Check whether an address is not globally routable: it matches any of
    the special-purpose predicates in this module.

    `ip`: IPv4 value.

    Returns a Boolean.
  */
  isBogon =
    ip:
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
  isGlobal = ip: !(isBogon ip);

  # ===== Arithmetic =====

  /*
    Offset an address by an integer; curried so `add n` can be mapped.

    `n`: integer offset; may be negative.
    `ip`: IPv4 value.

    Returns an IPv4 value; throws if the result leaves the address space.
  */
  add =
    n: ip:
    let
      result = ip.value + n;
    in
    if result < 0 || result > bits.mask32 then
      throw "libnet.ipv4.add: result out of range [0, 4294967295]: ${builtins.toString result}"
    else
      mk result;

  /*
    Offset an address downwards by an integer.

    `n`: integer to subtract; may be negative.
    `ip`: IPv4 value.

    Returns an IPv4 value; throws if the result leaves the address space.
  */
  sub = n: ip: add (0 - n) ip;

  /*
    Measure the distance between two addresses.

    `a`: IPv4 value to measure from.
    `b`: IPv4 value to measure to.

    Returns `toInt b - toInt a`, negative when `b` precedes `a`.
  */
  diff = a: b: b.value - a.value;

  /*
    Get the address one above `ip`. Equivalent to `add 1`, so it can be
    mapped over a list of addresses.

    `ip`: IPv4 value.

    Returns an IPv4 value; throws at 255.255.255.255.
  */
  next = ip: add 1 ip;

  /*
    Get the address one below `ip`. Equivalent to `sub 1`, so it can be
    mapped over a list of addresses.

    `ip`: IPv4 value.

    Returns an IPv4 value; throws at 0.0.0.0.
  */
  prev = ip: sub 1 ip;

  # ===== Comparison =====

  /*
    Check whether two values are the same address. Never throws for
    values of a different `_type`.

    `a`, `b`: IPv4 values.

    Returns true when both tag and value match.
  */
  eq = a: b: types.hasSameTag a b && a.value == b.value;

  /*
    Order two addresses numerically.

    `a`, `b`: IPv4 values.

    Returns -1 if `a < b`, 0 if equal, 1 if `a > b`.
  */
  compare =
    a: b:
    if a.value < b.value then
      -1
    else if a.value > b.value then
      1
    else
      0;

  /*
    Check whether `a` sorts before `b`.

    `a`, `b`: IPv4 values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Check whether `a` sorts before or equal to `b`.

    `a`, `b`: IPv4 values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Check whether `a` sorts after `b`.

    `a`, `b`: IPv4 values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Check whether `a` sorts after or equal to `b`.

    `a`, `b`: IPv4 values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lower of two addresses.

    `a`, `b`: IPv4 values.

    Returns `a` when the two are equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the higher of two addresses.

    `a`, `b`: IPv4 values.

    Returns `a` when the two are equal.
  */
  max = a: b: if ge a b then a else b;

  # ===== Constants =====

  unspecified = mk 0;
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
    add
    broadcast
    compare
    diff
    eq
    fromBytes
    fromInt
    fromOctets
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
    toOctets
    toString
    tryParse
    unspecified
    ;
}
