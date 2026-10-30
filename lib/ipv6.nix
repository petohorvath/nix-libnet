/*
  libnet.ipv6

  Parse, format, compare, and do arithmetic on IPv6 addresses. The
  internal form is four u32 words (high-to-low, words[0] most
  significant); output follows RFC 5952 canonical formatting.

  Note: `diff a b` returns `b - a` as an Int (second arg minus first),
  throwing if the result does not fit in a Nix integer. Matches ipv4 /
  mac / port curry direction.

  Example:
    libnet.ipv6.parse "2001:DB8:0:0::0001"
    => { _type = "ipv6"; words = [ 536939960 0 0 1 ]; }

    libnet.ipv6.toString (libnet.ipv6.parse "2001:DB8:0:0::0001")
    => "2001:db8::1"
*/
let
  address = import ./internal/address.nix;
  bits = import ./internal/bits.nix;
  comparison = import ./internal/comparison.nix;
  errors = import ./internal/errors.nix;
  formatting = import ./internal/format.nix;
  mac = import ./mac.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  mk = words: {
    _type = "ipv6";
    inherit words;
  };

  # An IPv6 argument of `function`, which throws for any other kind.
  ipv6Argument = function: errors.expectKind "ipv6.${function}" "ipv6";

  wordsOf = function: ip: (ipv6Argument function ip).words;

  # Apply `f` to the words of an IPv6 argument of `function`.
  withWords =
    function: f: ip:
    let
      words = wordsOf function ip;
    in
    builtins.seq words (f words);

  # Check a list of `count` integers in [0, maxValue] for `function`,
  # and build an address from the checked list with `build`.
  fromParts =
    function: part: count: maxValue: build: list:
    let
      parts = address.intList "ipv6.${function}" { inherit count part maxValue; } list;
    in
    builtins.seq parts (build parts);

  wordAt = i: words: builtins.elemAt words i;

  groupsOf = builtins.concatMap (word: [
    (bits.shr 16 word)
    (builtins.bitAnd word bits.mask16)
  ]);

  bytesOf = builtins.concatMap (word: [
    (bits.bits 24 8 word)
    (bits.bits 16 8 word)
    (bits.bits 8 8 word)
    (bits.bits 0 8 word)
  ]);

  inIpv4Mapped = words: wordAt 0 words == 0 && wordAt 1 words == 0 && wordAt 2 words == 65535;

  arithmetic = address.ipv6;

  # ===== Conversion =====

  /*
    Build an address from four 32-bit words, most significant first.

    `words`: list of exactly 4 integers, each in [0, 2^32 - 1].

    Returns an IPv6 value; throws on a wrong length or an invalid word.
  */
  fromWords = fromParts "fromWords" "word" 4 bits.mask32 mk;

  /*
    Get the four 32-bit words of an address.

    `ip`: IPv6 value.

    Returns a list of 4 integers in [0, 2^32 - 1], most significant first.
  */
  toWords = wordsOf "toWords";

  /*
    Build an address from its eight 16-bit groups, in the order they
    appear in hex notation.

    `groups`: list of exactly 8 integers, each in [0, 65535].

    Returns an IPv6 value; throws on a wrong length or an invalid group.
  */
  fromGroups = fromParts "fromGroups" "group" 8 bits.mask16 (
    groups:
    let
      groupAt = i: builtins.elemAt groups i;
      pair = i: j: (groupAt i) * bits.pow2_16 + (groupAt j);
    in
    mk [
      (pair 0 1)
      (pair 2 3)
      (pair 4 5)
      (pair 6 7)
    ]
  );

  /*
    Split an address into its eight 16-bit groups.

    `ip`: IPv6 value.

    Returns a list of 8 integers in [0, 65535], most significant first.
  */
  toGroups = withWords "toGroups" groupsOf;

  /*
    Build an address from its sixteen bytes, most significant first.

    `bytes`: list of exactly 16 integers, each in [0, 255].

    Returns an IPv6 value; throws on a wrong length or an invalid byte.
  */
  fromBytes = fromParts "fromBytes" "byte" 16 255 (
    bytes:
    let
      byteAt = i: builtins.elemAt bytes i;
      quad =
        i:
        (byteAt i) * bits.pow2_24
        + (byteAt (i + 1)) * bits.pow2_16
        + (byteAt (i + 2)) * bits.pow2_8
        + (byteAt (i + 3));
    in
    mk [
      (quad 0)
      (quad 4)
      (quad 8)
      (quad 12)
    ]
  );

  /*
    Split an address into its sixteen bytes.

    `ip`: IPv6 value.

    Returns a list of 16 integers in [0, 255], most significant first.
  */
  toBytes = withWords "toBytes" bytesOf;

  # ===== Parsing =====

  /*
    Parse the `:`-separated `parts` of `input` into 16-bit groups. When
    `allowIpv4` holds, the last part may be a dotted-quad IPv4 address,
    read as two groups. Returns `{ groups; }`, or `{ error; }` with the
    detail of the first invalid part.
  */
  partsToGroups =
    input: allowIpv4: parts:
    let
      count = builtins.length parts;
      group =
        part:
        let
          value = parsing.hexGroup part;
        in
        if part == "" then
          { error = "empty group in \"${input}\""; }
        else if value == null then
          { error = "invalid group \"${part}\" in \"${input}\""; }
        else
          { groups = [ value ]; };
      ipv4Part =
        part:
        let
          octetTexts = parsing.splitOn "." part;
          octets = map parsing.octet octetTexts;
          octetAt = builtins.elemAt octets;
        in
        if builtins.length octetTexts != 4 || builtins.elem null octets then
          { error = "invalid IPv4 part \"${part}\" in \"${input}\""; }
        else
          {
            groups = [
              (octetAt 0 * 256 + octetAt 1)
              (octetAt 2 * 256 + octetAt 3)
            ];
          };
      isIpv4Part = index: part: allowIpv4 && index == count - 1 && parsing.countOccurrences "." part > 0;
      results = builtins.genList (
        index:
        let
          part = builtins.elemAt parts index;
        in
        if isIpv4Part index part then ipv4Part part else group part
      ) count;
      failures = builtins.filter (result: result ? error) results;
    in
    if failures != [ ] then
      builtins.head failures
    else
      { groups = builtins.concatMap (result: result.groups) results; };

  # Split the `:`-separated text of one side of `::`, which may be empty.
  splitGroups = text: if text == "" then [ ] else parsing.splitOn ":" text;

  /*
    Parse an IPv6 address: the detail parser of the parsing suite.
    Accepts any RFC 4291 text form, including `::` compression, mixed
    case, and a trailing dotted-quad IPv4 part.

    `input`: string such as "2001:db8::1".

    Returns a tryResult holding the IPv6 value, or the detail of the
    failure.
  */
  tryParseDetail =
    input:
    if input == "" then
      types.tryErr "empty string"
    else
      let
        doubleColonCount = parsing.countOccurrences "::" input;
      in
      if doubleColonCount > 1 then
        types.tryErr "more than one \"::\" in \"${input}\""
      else if doubleColonCount == 0 then
        let
          result = partsToGroups input true (parsing.splitOn ":" input);
          groupCount = builtins.length result.groups;
        in
        if result ? error then
          types.tryErr result.error
        else if groupCount != 8 then
          types.tryErr "must have 8 groups, got ${builtins.toString groupCount}: \"${input}\""
        else
          types.tryOk (fromGroups result.groups)
      else
        let
          halves = parsing.splitOn "::" input;
          # An IPv4 part is only valid at the very end of the address.
          left = partsToGroups input false (splitGroups (builtins.elemAt halves 0));
          right = partsToGroups input true (splitGroups (builtins.elemAt halves 1));
          groupCount = builtins.length left.groups + builtins.length right.groups;
        in
        if left ? error then
          types.tryErr left.error
        else if right ? error then
          types.tryErr right.error
        # "::" stands for at least one zero group.
        else if groupCount > 7 then
          types.tryErr "must have at most 7 groups with \"::\", got ${builtins.toString groupCount}: \"${input}\""
        else
          types.tryOk (fromGroups (left.groups ++ builtins.genList (_: 0) (8 - groupCount) ++ right.groups));

  parsers = parsing.suite "ipv6" tryParseDetail;

  # ===== Predicates =====

  /*
    Check whether a value is a parsed IPv6 value by its `_type` tag, as
    opposed to `isValid`, which checks whether a string parses.

    `value`: any value.

    Returns a Boolean; raw strings yield false.
  */
  is = value: types.isIpv6 value;

  /*
    Check whether an address is the unspecified address `::`.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isUnspecified = withWords "isUnspecified" (
    words:
    words == [
      0
      0
      0
      0
    ]
  );

  /*
    Check whether an address is the loopback address `::1`.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isLoopback = withWords "isLoopback" (
    words:
    words == [
      0
      0
      0
      1
    ]
  );

  /*
    Check whether an address is link-local (fe80::/10).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isLinkLocal = withWords "isLinkLocal" (
    words:
    # The first 10 bits are 0b1111111010.
    bits.shr 22 (wordAt 0 words) == 1018
  );

  /*
    Check whether an address is unique local (fc00::/7), the IPv6
    counterpart of IPv4 private space.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isUniqueLocal = withWords "isUniqueLocal" (
    words:
    # The first 7 bits are 0b1111110.
    bits.shr 25 (wordAt 0 words) == 126
  );

  /*
    Check whether an address is multicast (ff00::/8).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isMulticast = withWords "isMulticast" (words: bits.shr 24 (wordAt 0 words) == 255);

  /*
    Check whether an address is in a documentation block (2001:db8::/32,
    3fff::/20).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isDocumentation = withWords "isDocumentation" (
    words:
    # 536939960 is 0x20010db8, the whole first word; 262128 is 0x3fff0,
    # the first 20 bits.
    wordAt 0 words == 536939960 || bits.shr 12 (wordAt 0 words) == 262128
  );

  /*
    Check whether an address is IPv4-mapped (::ffff:0:0/96).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isIpv4Mapped = withWords "isIpv4Mapped" inIpv4Mapped;

  /*
    Check whether an address is in the deprecated IPv4-compatible form
    (::/96). This includes `::` and `::1`.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isIpv4Compatible = withWords "isIpv4Compatible" (
    words: wordAt 0 words == 0 && wordAt 1 words == 0 && wordAt 2 words == 0
  );

  /*
    Check whether an address is a 6to4 address (2002::/16).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  is6to4 = withWords "is6to4" (
    words:
    # The first 16 bits are 0x2002.
    bits.shr 16 (wordAt 0 words) == 8194
  );

  /*
    Check whether an address is a Teredo address (2001::/32, RFC 4380).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isTeredo = withWords "isTeredo" (
    words:
    # The first word is 0x20010000.
    wordAt 0 words == 536936448
  );

  /*
    Check whether an address is in the local-use IPv4/IPv6 translation
    block (64:ff9b:1::/48, RFC 8215).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isLocalNat64 = withWords "isLocalNat64" (
    words:
    # The first word is 0x0064ff9b and the next 16 bits are 0x0001.
    wordAt 0 words == 6619035 && bits.shr 16 (wordAt 1 words) == 1
  );

  /*
    Check whether an address is in the discard-only block (100::/64,
    RFC 6666).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isDiscard = withWords "isDiscard" (
    words:
    # The first word is 0x01000000.
    wordAt 0 words == 16777216 && wordAt 1 words == 0
  );

  /*
    Check whether an address is in the dummy prefix (100:0:0:1::/64,
    RFC 9780).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isDummy = withWords "isDummy" (
    words:
    # The first word is 0x01000000 and the second 0x00000001.
    wordAt 0 words == 16777216 && wordAt 1 words == 1
  );

  /*
    Check whether an address is an IETF protocol assignment (2001::/23,
    RFC 2928), excluding Teredo (2001::/32) and the globally reachable
    allocations 2001:1::1, 2001:1::2, 2001:1::3, 2001:3::/32,
    2001:4:112::/48, 2001:20::/28, and 2001:30::/28.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isProtocolAssignment = withWords "isProtocolAssignment" (
    words:
    let
      # 2001::/23 is the first group 0x2001 (8193) with the second group
      # in [0x0000, 0x01ff].
      group = builtins.bitAnd (wordAt 0 words) bits.mask16;
      anycast =
        group == 1
        && wordAt 1 words == 0
        && wordAt 2 words == 0
        && wordAt 3 words >= 1
        && wordAt 3 words <= 3;
      # 274 is 0x0112, the third group of 2001:4:112::/48.
      as112 = group == 4 && bits.shr 16 (wordAt 1 words) == 274;
      # 2001:20::/28 and 2001:30::/28 together span groups 0x20 to 0x3f.
      orchidV2OrDet = group >= 32 && group <= 63;
    in
    bits.shr 16 (wordAt 0 words) == 8193
    && group <= 511
    # Teredo, 2001::/32.
    && group != 0
    # AMT, 2001:3::/32.
    && group != 3
    && !anycast
    && !as112
    && !orchidV2OrDet
  );

  /*
    Check whether an address is in the benchmarking block (2001:2::/48,
    RFC 5180).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isBenchmarking = withWords "isBenchmarking" (
    words:
    # The first word is 0x20010002 and the next 16 bits are zero.
    wordAt 0 words == 536936450 && bits.shr 16 (wordAt 1 words) == 0
  );

  /*
    Check whether an address is in the deprecated ORCHID block
    (2001:10::/28, RFC 4843).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isOrchid = withWords "isOrchid" (
    words:
    # The first 28 bits are 0x2001001.
    bits.shr 4 (wordAt 0 words) == 33558529
  );

  /*
    Check whether an address is a segment routing (SRv6) SID
    (5f00::/16, RFC 9602).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isSrv6Sid = withWords "isSrv6Sid" (
    words:
    # The first 16 bits are 0x5f00.
    bits.shr 16 (wordAt 0 words) == 24320
  );

  /*
    Check whether an address is in the deprecated site-local block
    (fec0::/10, RFC 3879).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isSiteLocal = withWords "isSiteLocal" (
    words:
    # The first 10 bits are 0b1111111011.
    bits.shr 22 (wordAt 0 words) == 1019
  );

  /*
    Check whether an address is a bogon, not globally reachable: unspecified,
    loopback, link-local, unique local, multicast, documentation,
    local-use NAT64, discard, dummy, IETF protocol assignment,
    benchmarking, ORCHID, SRv6 SID, or site-local. Transition forms are
    not bogons.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isBogon =
    argument:
    let
      ip = ipv6Argument "isBogon" argument;
    in
    isUnspecified ip
    || isLoopback ip
    || isLinkLocal ip
    || isUniqueLocal ip
    || isMulticast ip
    || isDocumentation ip
    || isLocalNat64 ip
    || isDiscard ip
    || isDummy ip
    || isProtocolAssignment ip
    || isBenchmarking ip
    || isOrchid ip
    || isSrv6Sid ip
    || isSiteLocal ip;

  /*
    Check whether an address is native global unicast. Stricter than
    `!isBogon`: it also excludes the IPv4-mapped, IPv4-compatible, 6to4,
    and Teredo forms, which are routable but not native IPv6.
    `ipv4.isGlobal` has no such forms, so this asymmetry is intentional
    (see docs/adr/0014).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isGlobal =
    argument:
    let
      ip = ipv6Argument "isGlobal" argument;
    in
    !(isBogon ip || isIpv4Mapped ip || isIpv4Compatible ip || is6to4 ip || isTeredo ip);

  # ===== Formatting =====

  /*
    Format an address in RFC 5952 canonical form: lowercase, leading
    zeros dropped, and the longest run of zero groups compressed to `::`.
    IPv4-mapped addresses use the mixed form `::ffff:a.b.c.d` (§ 5).

    `ip`: IPv6 value.

    Returns a string such as "2001:db8::1".
  */
  toString = withWords "toString" formatting.ipv6;

  /*
    Format an address with all eight groups as four hex digits and no
    compression.

    `ip`: IPv6 value.

    Returns a string such as "2001:0db8:0000:0000:0000:0000:0000:0001".
  */
  toStringExpanded = withWords "toStringExpanded" (
    words: builtins.concatStringsSep ":" (map formatting.hex4 (groupsOf words))
  );

  /*
    Format an address in brackets for URL and endpoint contexts.

    `ip`: IPv6 value.

    Returns a string such as "[2001:db8::1]".
  */
  toStringBracketed = withWords "toStringBracketed" (words: "[${formatting.ipv6 words}]");

  /*
    Format an address as its reverse-DNS name: the 32 nibbles in reverse
    order under ip6.arpa.

    `ip`: IPv6 value.

    Returns a string such as "1.0.0.0.<...>.8.b.d.0.1.0.0.2.ip6.arpa".
  */
  toArpa =
    ip:
    let
      nibblesOf = byte: [
        (formatting.hex1 (bits.shr 4 byte))
        (formatting.hex1 (builtins.bitAnd byte 15))
      ];
      nibbles = builtins.concatMap nibblesOf (bytesOf (wordsOf "toArpa" ip));
      reversed = builtins.genList (i: builtins.elemAt nibbles (31 - i)) 32;
    in
    (builtins.concatStringsSep "." reversed) + ".ip6.arpa";

  # ===== IPv4 interop =====

  # To keep dependencies one-way (cidr imports ipv4 and ipv6), this module
  # does not import ipv4; it builds IPv4 values directly in the shape
  # `ipv4.fromInt` returns: { _type = "ipv4"; value = <int>; }.

  /*
    Embed an IPv4 address in the IPv4-mapped block (RFC 4291 section
    2.5.5.2), e.g. 1.2.3.4 becomes ::ffff:1.2.3.4.

    `ipv4`: IPv4 value.

    Returns an IPv6 value; throws if `ipv4` is not an IPv4 value.
  */
  fromIpv4 =
    ipv4:
    let
      inherit (errors.expectKind "ipv6.fromIpv4" "ipv4" ipv4) value;
    in
    builtins.seq value (mk [
      0
      0
      65535
      value
    ]);

  /*
    Extract the IPv4 address embedded in an IPv4-mapped address.

    `ip`: IPv6 value in ::ffff:0:0/96.

    Returns an IPv4 value; throws if `ip` is not IPv4-mapped.
  */
  toIpv4 =
    ip:
    let
      words = wordsOf "toIpv4" ip;
    in
    if !(inIpv4Mapped words) then
      errors.fail "ipv6.toIpv4" "address is not in ::ffff:0:0/96: ${formatting.ipv6 words}"
    else
      {
        _type = "ipv4";
        value = wordAt 3 words;
      };

  # ===== EUI-64 =====

  /*
    Build a SLAAC-style address from a CIDR and a MAC address.

    `cidrValue`: IPv6 CIDR value with a prefix length of at most 64; its
    network address forms the upper 64 bits.
    `macValue`: MAC value; its modified EUI-64 form (RFC 4291) becomes
    the lower 64 bits.

    Returns an IPv6 value; throws if `cidrValue` is not an IPv6 CIDR,
    `macValue` is not a MAC, or the prefix length exceeds 64.
  */
  fromMac =
    cidrArgument: macArgument:
    let
      cidrValue = errors.expectKind "ipv6.fromMac" "cidr" cidrArgument;
      macValue = errors.expectKind "ipv6.fromMac" "mac" macArgument;
    in
    if !(types.isIpv6 cidrValue.networkAddress) then
      errors.fail "ipv6.fromMac" "expected an IPv6 cidr, got an IPv4 one"
    else if cidrValue.prefix > 64 then
      errors.fail "ipv6.fromMac" "CIDR prefix must be <= 64, got /${builtins.toString cidrValue.prefix}"
    else
      let
        # The network address has no host bits, so its upper two words
        # are the prefix and its lower two are zero.
        networkWords = cidrValue.networkAddress.words;
        euiBytes = mac.toEui64 macValue;
        euiByteAt = i: builtins.elemAt euiBytes i;
        interfaceWord =
          i:
          (euiByteAt i) * bits.pow2_24
          + (euiByteAt (i + 1)) * bits.pow2_16
          + (euiByteAt (i + 2)) * bits.pow2_8
          + (euiByteAt (i + 3));
      in
      builtins.seq macValue (mk [
        (builtins.elemAt networkWords 0)
        (builtins.elemAt networkWords 1)
        (interfaceWord 0)
        (interfaceWord 4)
      ]);

  # ===== Arithmetic =====

  /*
    Offset an address by an integer, carrying across the four words;
    curried so `add n` can be mapped.

    `n`: integer offset; may be negative.
    `ip`: IPv6 value.

    Returns an IPv6 value; throws when `n` is not an integer, on overflow
    past ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff, or on underflow below
    `::`.
  */
  add = arithmetic.add "ipv6.add";

  /*
    Offset an address downwards by an integer.

    `n`: integer to subtract; may be negative.
    `ip`: IPv6 value.

    Returns an IPv6 value; throws when `n` is not an integer or the result
    leaves the address space.
  */
  sub = arithmetic.sub "ipv6.sub";

  /*
    Get the address one above `ip`. Equivalent to `add 1`, so it can be
    mapped over a list of addresses.

    `ip`: IPv6 value.

    Returns an IPv6 value; throws at the highest address,
    ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff.
  */
  next = arithmetic.add "ipv6.next" 1;

  /*
    Get the address one below `ip`. Equivalent to `sub 1`, so it can be
    mapped over a list of addresses.

    `ip`: IPv6 value.

    Returns an IPv6 value; throws at `::`.
  */
  prev = arithmetic.sub "ipv6.prev" 1;

  /*
    Measure the distance between two addresses.

    `a`: IPv6 value to measure from.
    `b`: IPv6 value to measure to.

    Returns `b - a` as an integer, negative when `b` precedes `a`; throws
    if the difference does not fit in a Nix integer, [-2^63, 2^63 - 1].
  */
  diff = arithmetic.diff "ipv6.diff";

  # ===== Comparison =====

  # Order two addresses for the public function `function`, comparing
  # words most significant first. Throws for any argument that is not an
  # IPv6 value, including an IPv4 one.
  compareFor =
    function: a: b:
    let
      left = wordsOf function a;
      right = wordsOf function b;
    in
    comparison.lexicographic (
      builtins.genList (i: comparison.order (wordAt i left) (wordAt i right)) 4
    );

  ordering = comparison.suite compareFor;

  /*
    Check whether two values are the same address. Never throws for
    values of a different `_type`.

    `a`, `b`: IPv6 values.

    Returns true when both tag and words match.
  */
  eq = a: b: types.bothHaveTag types.tags.ipv6 a b && a.words == b.words;

  # ===== Constants =====

  unspecified = mk [
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
    add
    diff
    eq
    fromBytes
    fromGroups
    fromIpv4
    fromMac
    fromWords
    is
    is6to4
    isBenchmarking
    isBogon
    isDiscard
    isDocumentation
    isDummy
    isGlobal
    isIpv4Compatible
    isIpv4Mapped
    isLinkLocal
    isLocalNat64
    isLoopback
    isMulticast
    isOrchid
    isProtocolAssignment
    isSiteLocal
    isSrv6Sid
    isTeredo
    isUniqueLocal
    isUnspecified
    loopback
    next
    prev
    sub
    toArpa
    toBytes
    toGroups
    toIpv4
    toString
    toStringBracketed
    toStringExpanded
    toWords
    tryParseDetail
    unspecified
    ;
  inherit (parsers)
    isValid
    parse
    tryParse
    ;
  inherit (ordering)
    compare
    ge
    gt
    le
    lt
    max
    min
    ;
}
