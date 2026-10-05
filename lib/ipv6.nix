/*
  libnet.ipv6

  Parse, format, compare, and do arithmetic on IPv6 addresses. The
  internal form is four u32 words (high-to-low, words[0] most
  significant); output follows RFC 5952 canonical formatting.

  Note: `diff a b` returns `b - a` as an Int (second arg minus first),
  throwing if the result exceeds signed 63-bit range. Matches ipv4 /
  mac / port curry direction.

  Example:
    libnet.ipv6.parse "2001:DB8:0:0::0001"
    => { _type = "ipv6"; words = [ 536939960 0 0 1 ]; }

    libnet.ipv6.toString (libnet.ipv6.parse "2001:DB8:0:0::0001")
    => "2001:db8::1"
*/
let
  bits = import ./internal/bits.nix;
  carry = import ./internal/carry.nix;
  formatting = import ./internal/format.nix;
  mac = import ./mac.nix;
  parsing = import ./internal/parse.nix;
  types = import ./internal/types.nix;

  mk = words: {
    _type = "ipv6";
    inherit words;
  };

  # ===== Conversion =====

  /*
    Build an address from four 32-bit words, most significant first.

    `words`: list of exactly 4 integers, each in [0, 2^32 - 1].

    Returns an IPv6 value; throws on a wrong length or an invalid word.
  */
  fromWords =
    words:
    if !(builtins.isList words) || builtins.length words != 4 then
      throw "libnet.ipv6.fromWords: expected list of 4 u32 ints"
    else
      let
        invalid = builtins.any (word: !(builtins.isInt word) || word < 0 || word > bits.mask32) words;
      in
      if invalid then throw "libnet.ipv6.fromWords: each word must be int in [0, 2^32 - 1]" else mk words;

  /*
    Get the four 32-bit words of an address.

    `ip`: IPv6 value.

    Returns a list of 4 integers in [0, 2^32 - 1], most significant first.
  */
  toWords = ip: ip.words;

  /*
    Build an address from its eight 16-bit groups, in the order they
    appear in hex notation.

    `groups`: list of exactly 8 integers, each in [0, 65535].

    Returns an IPv6 value; throws on a wrong length or an invalid group.
  */
  fromGroups =
    groups:
    if !(builtins.isList groups) || builtins.length groups != 8 then
      throw "libnet.ipv6.fromGroups: expected list of 8 u16 ints"
    else
      let
        invalid = builtins.any (group: !(builtins.isInt group) || group < 0 || group > bits.mask16) groups;
      in
      if invalid then
        throw "libnet.ipv6.fromGroups: each group must be int in [0, 65535]"
      else
        let
          groupAt = i: builtins.elemAt groups i;
          pair = i: j: (groupAt i) * bits.pow2_16 + (groupAt j);
        in
        mk [
          (pair 0 1)
          (pair 2 3)
          (pair 4 5)
          (pair 6 7)
        ];

  /*
    Split an address into its eight 16-bit groups.

    `ip`: IPv6 value.

    Returns a list of 8 integers in [0, 65535], most significant first.
  */
  toGroups =
    ip:
    let
      wordToGroups = word: [
        (bits.shr 16 word)
        (builtins.bitAnd word bits.mask16)
      ];
    in
    builtins.concatMap wordToGroups ip.words;

  /*
    Build an address from its sixteen bytes, most significant first.

    `bytes`: list of exactly 16 integers, each in [0, 255].

    Returns an IPv6 value; throws on a wrong length or an invalid byte.
  */
  fromBytes =
    bytes:
    if !(builtins.isList bytes) || builtins.length bytes != 16 then
      throw "libnet.ipv6.fromBytes: expected list of 16 u8 ints"
    else
      let
        invalid = builtins.any (byte: !(builtins.isInt byte) || byte < 0 || byte > 255) bytes;
      in
      if invalid then
        throw "libnet.ipv6.fromBytes: each byte must be int in [0, 255]"
      else
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
        ];

  /*
    Split an address into its sixteen bytes.

    `ip`: IPv6 value.

    Returns a list of 16 integers in [0, 255], most significant first.
  */
  toBytes =
    ip:
    let
      wordToBytes = word: [
        (bits.bits 24 8 word)
        (bits.bits 16 8 word)
        (bits.bits 8 8 word)
        (bits.bits 0 8 word)
      ];
    in
    builtins.concatMap wordToBytes ip.words;

  # ===== Parsing =====

  # Parse a list of hex-group strings into ints. null on failure.
  parseHexGroups =
    groupTexts:
    let
      results = map parsing.hexGroup groupTexts;
    in
    if builtins.any (group: group == null) results then null else results;

  # Check that no element contains "." except the last.
  hasDotOnlyInLast =
    parts:
    let
      n = builtins.length parts;
      hasDot = part: parsing.countOccurrences "." part > 0;
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
    else if !(hasDotOnlyInLast parts) then
      null
    else
      let
        lastPart = builtins.elemAt parts (n - 1);
        hasDot = parsing.countOccurrences "." lastPart > 0;
      in
      if !hasDot then
        parseHexGroups parts
      else
        let
          ipv4Parts = parsing.splitOn "." lastPart;
          octets = if builtins.length ipv4Parts == 4 then map parsing.octet ipv4Parts else null;
          ipv4Valid = octets != null && !(builtins.any (octet: octet == null) octets);
        in
        if !ipv4Valid then
          null
        else
          let
            octetAt = i: builtins.elemAt octets i;
            highGroup = octetAt 0 * 256 + octetAt 1;
            lowGroup = octetAt 2 * 256 + octetAt 3;
            prefixParts = if n == 1 then [ ] else builtins.genList (i: builtins.elemAt parts i) (n - 1);
            prefixGroups = parseHexGroups prefixParts;
          in
          if prefixGroups == null then
            null
          else
            prefixGroups
            ++ [
              highGroup
              lowGroup
            ];

  /*
    Parse an IPv6 address without throwing, for validating untrusted
    input. Accepts any RFC 4291 text form, including `::` compression,
    mixed case, and a trailing dotted-quad IPv4 part.

    `input`: string such as "2001:db8::1".

    Returns a tryParse result: `{ success, value, error }`, where `value`
    is the IPv6 value on success and `error` describes the failure.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.ipv6.parse: input must be a string"
    else if input == "" then
      types.tryErr "libnet.ipv6.parse: empty string"
    else
      let
        doubleColonCount = parsing.countOccurrences "::" input;
      in
      if doubleColonCount > 1 then
        types.tryErr "libnet.ipv6.parse: more than one \"::\" in \"${input}\""
      else
        let
          groups =
            if doubleColonCount == 0 then
              let
                expanded = expandPartsToGroups (parsing.splitOn ":" input);
              in
              if expanded == null || builtins.length expanded != 8 then null else expanded
            else
              let
                halves = parsing.splitOn "::" input;
                leftText = builtins.elemAt halves 0;
                rightText = builtins.elemAt halves 1;
                leftParts = if leftText == "" then [ ] else parsing.splitOn ":" leftText;
                rightParts = if rightText == "" then [ ] else parsing.splitOn ":" rightText;
                # An IPv4 part is only valid at the very end of the address.
                leftHasDot = builtins.any (part: parsing.countOccurrences "." part > 0) leftParts;
                leftGroups = if leftHasDot then null else parseHexGroups leftParts;
                rightGroups = expandPartsToGroups rightParts;
              in
              if leftGroups == null || rightGroups == null then
                null
              else
                let
                  groupCount = builtins.length leftGroups + builtins.length rightGroups;
                in
                if groupCount > 7 then
                  null # "::" must represent at least 1 zero group
                else
                  let
                    zeros = builtins.genList (_: 0) (8 - groupCount);
                  in
                  leftGroups ++ zeros ++ rightGroups;
        in
        if groups == null then
          types.tryErr "libnet.ipv6.parse: invalid \"${input}\""
        else
          types.tryOk (fromGroups groups);

  /*
    Parse an IPv6 address, for trusted configuration values.

    `input`: string such as "2001:db8::1".

    Returns an IPv6 value; throws on malformed input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  # ===== Predicates =====

  /*
    Check whether a string parses as an IPv6 address.

    `input`: value to check; non-strings yield false.

    Returns a Boolean.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a parsed IPv6 value by its `_type` tag, as
    opposed to `isValid`, which checks whether a string parses.

    `value`: any value.

    Returns a Boolean; raw strings yield false.
  */
  is = value: types.isIpv6 value;

  wordAt = i: ip: builtins.elemAt ip.words i;

  /*
    Check whether an address is the unspecified address `::`.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isUnspecified =
    ip:
    ip.words == [
      0
      0
      0
      0
    ];

  /*
    Check whether an address is the loopback address `::1`.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isLoopback =
    ip:
    ip.words == [
      0
      0
      0
      1
    ];

  /*
    Check whether an address is link-local (fe80::/10).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isLinkLocal =
    ip:
    # The first 10 bits are 0b1111111010.
    bits.shr 22 (wordAt 0 ip) == 1018;

  /*
    Check whether an address is unique local (fc00::/7), the IPv6
    counterpart of IPv4 private space.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isUniqueLocal =
    ip:
    # The first 7 bits are 0b1111110.
    bits.shr 25 (wordAt 0 ip) == 126;

  /*
    Check whether an address is multicast (ff00::/8).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isMulticast = ip: bits.shr 24 (wordAt 0 ip) == 255;

  /*
    Check whether an address is in a documentation block (2001:db8::/32,
    3fff::/20).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isDocumentation =
    ip:
    # 536939960 is 0x20010db8, the whole first word; 262128 is 0x3fff0,
    # the first 20 bits.
    wordAt 0 ip == 536939960 || bits.shr 12 (wordAt 0 ip) == 262128;

  /*
    Check whether an address is IPv4-mapped (::ffff:0:0/96).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isIpv4Mapped = ip: wordAt 0 ip == 0 && wordAt 1 ip == 0 && wordAt 2 ip == 65535;

  /*
    Check whether an address is in the deprecated IPv4-compatible form
    (::/96). This includes `::` and `::1`.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isIpv4Compatible = ip: wordAt 0 ip == 0 && wordAt 1 ip == 0 && wordAt 2 ip == 0;

  /*
    Check whether an address is a 6to4 address (2002::/16).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  is6to4 =
    ip:
    # The first 16 bits are 0x2002.
    bits.shr 16 (wordAt 0 ip) == 8194;

  /*
    Check whether an address is in the discard-only block (100::/64,
    RFC 6666).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isDiscard =
    ip:
    # The first word is 0x01000000.
    wordAt 0 ip == 16777216 && wordAt 1 ip == 0;

  /*
    Check whether an address is in the deprecated ORCHID block
    (2001:10::/28, RFC 4843).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isOrchid =
    ip:
    # The first 28 bits are 0x2001001.
    bits.shr 4 (wordAt 0 ip) == 33558529;

  /*
    Check whether an address is in the deprecated site-local block
    (fec0::/10, RFC 3879).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isSiteLocal =
    ip:
    # The first 10 bits are 0b1111111011.
    bits.shr 22 (wordAt 0 ip) == 1019;

  /*
    Check whether an address is not globally routable: unspecified,
    loopback, link-local, unique local, multicast, documentation,
    discard, ORCHID, or site-local. IPv4 transition forms are not bogons.

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isBogon =
    ip:
    isUnspecified ip
    || isLoopback ip
    || isLinkLocal ip
    || isUniqueLocal ip
    || isMulticast ip
    || isDocumentation ip
    || isDiscard ip
    || isOrchid ip
    || isSiteLocal ip;

  /*
    Check whether an address is native global unicast. Stricter than
    `!isBogon`: it also excludes the IPv4-mapped, IPv4-compatible, and
    6to4 forms, which are routable but not native IPv6. `ipv4.isGlobal`
    has no such forms, so this asymmetry is intentional (see SPEC.md).

    `ip`: IPv6 value.

    Returns a Boolean.
  */
  isGlobal = ip: !(isBogon ip || isIpv4Mapped ip || isIpv4Compatible ip || is6to4 ip);

  # ===== Formatting =====

  /*
    Format an address in RFC 5952 canonical form: lowercase, leading
    zeros dropped, and the longest run of zero groups compressed to `::`.
    IPv4-mapped addresses use the mixed form `::ffff:a.b.c.d` (§ 5).

    `ip`: IPv6 value.

    Returns a string such as "2001:db8::1".
  */
  toString =
    ip:
    if isIpv4Mapped ip then
      let
        lowWord = wordAt 3 ip;
        octetText = shift: builtins.toString (bits.bits shift 8 lowWord);
      in
      "::ffff:${octetText 24}.${octetText 16}.${octetText 8}.${octetText 0}"
    else
      let
        groups = toGroups ip;
        zeroRun = formatting.longestZeroRun groups;
        groupTexts = map formatting.hex groups;
      in
      if zeroRun.len == 0 then
        builtins.concatStringsSep ":" groupTexts
      else
        let
          prefix = builtins.genList (i: builtins.elemAt groupTexts i) zeroRun.start;
          suffix = builtins.genList (i: builtins.elemAt groupTexts (zeroRun.start + zeroRun.len + i)) (
            8 - zeroRun.start - zeroRun.len
          );
          prefixText = builtins.concatStringsSep ":" prefix;
          suffixText = builtins.concatStringsSep ":" suffix;
        in
        "${prefixText}::${suffixText}";

  /*
    Alias of `toString`, named to contrast with `toStringExpanded` when
    both forms appear in the same code.

    `ip`: IPv6 value.

    Returns the RFC 5952 canonical string.
  */
  toStringCompressed = ip: toString ip;

  /*
    Format an address with all eight groups as four hex digits and no
    compression.

    `ip`: IPv6 value.

    Returns a string such as "2001:0db8:0000:0000:0000:0000:0000:0001".
  */
  toStringExpanded = ip: builtins.concatStringsSep ":" (map formatting.hex4 (toGroups ip));

  /*
    Format an address in brackets for URL and endpoint contexts.

    `ip`: IPv6 value.

    Returns a string such as "[2001:db8::1]".
  */
  toStringBracketed = ip: "[${toString ip}]";

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
      nibbles = builtins.concatMap nibblesOf (toBytes ip);
      reversed = builtins.genList (i: builtins.elemAt nibbles (31 - i)) 32;
    in
    (builtins.concatStringsSep "." reversed) + ".ip6.arpa";

  # ===== IPv4 interop =====

  # To keep dependencies one-way (cidr imports ipv4 and ipv6), this module
  # does not import ipv4; it builds IPv4 values directly in the shape
  # `ipv4.fromInt` returns: { _type = "ipv4"; value = <int>; }.

  /*
    Embed an IPv4 address in the IPv4-mapped block, e.g. 1.2.3.4 becomes
    ::ffff:1.2.3.4.

    `ipv4`: IPv4 value.

    Returns an IPv6 value; throws if `ipv4` is not an IPv4 value.
  */
  fromIpv4Mapped =
    ipv4:
    if !(types.isIpv4 ipv4) then
      throw "libnet.ipv6.fromIpv4Mapped: expected ipv4 value"
    else
      mk [
        0
        0
        65535
        ipv4.value
      ];

  /*
    Extract the IPv4 address embedded in an IPv4-mapped address.

    `ip`: IPv6 value in ::ffff:0:0/96.

    Returns an IPv4 value; throws if `ip` is not IPv4-mapped.
  */
  toIpv4Mapped =
    ip:
    if !(isIpv4Mapped ip) then
      throw "libnet.ipv6.toIpv4Mapped: address is not in ::ffff:0:0/96"
    else
      {
        _type = "ipv4";
        value = wordAt 3 ip;
      };

  # ===== EUI-64 =====

  /*
    Build a SLAAC-style address from a network prefix and a MAC address.

    `cidrValue`: IPv6 CIDR value with a prefix length of at most 64; its
    network bits form the upper 64 bits.
    `macValue`: MAC value; its modified EUI-64 form (RFC 4291) becomes
    the lower 64 bits.

    Returns an IPv6 value; throws if `cidrValue` is not an IPv6 CIDR,
    `macValue` is not a MAC, or the prefix length exceeds 64.
  */
  fromEui64 =
    cidrValue: macValue:
    let
      isValidCidr = types.isCidr cidrValue && cidrValue.address._type == "ipv6";
    in
    if !isValidCidr then
      throw "libnet.ipv6.fromEui64: first argument must be an IPv6 cidr"
    else if !(types.isMac macValue) then
      throw "libnet.ipv6.fromEui64: second argument must be a mac"
    else if cidrValue.prefix > 64 then
      throw "libnet.ipv6.fromEui64: CIDR prefix must be <= 64, got /${builtins.toString cidrValue.prefix}"
    else
      let
        addressWords = cidrValue.address.words;
        inherit (cidrValue) prefix;
        # Keep the top `keep` bits of `word` and zero the rest.
        applyMask =
          word: keep:
          if keep <= 0 then
            0
          else if keep >= 32 then
            word
          else
            bits.shl (32 - keep) (bits.shr (32 - keep) word);
        networkWord0 = applyMask (builtins.elemAt addressWords 0) prefix;
        networkWord1 = applyMask (builtins.elemAt addressWords 1) (prefix - 32);
        euiBytes = mac.toEui64 macValue;
        euiByteAt = i: builtins.elemAt euiBytes i;
        interfaceWord =
          i:
          (euiByteAt i) * bits.pow2_24
          + (euiByteAt (i + 1)) * bits.pow2_16
          + (euiByteAt (i + 2)) * bits.pow2_8
          + (euiByteAt (i + 3));
      in
      mk [
        networkWord0
        networkWord1
        (interfaceWord 0)
        (interfaceWord 4)
      ];

  # ===== Arithmetic =====

  # Add a non-negative int `n` (which fits in signed 63 bits) to the
  # 128-bit value by splitting it into two u32 halves. Throws on overflow
  # past 2^128.
  addU63 =
    n: ip:
    let
      lowOffset = builtins.bitAnd n bits.mask32;
      highOffset = bits.shr 32 n;
      result3 = carry.add32 (wordAt 3 ip) lowOffset 0;
      result2 = carry.add32 (wordAt 2 ip) highOffset result3.carry;
      result1 = carry.add32 (wordAt 1 ip) 0 result2.carry;
      result0 = carry.add32 (wordAt 0 ip) 0 result1.carry;
    in
    if result0.carry == 1 then
      throw "libnet.ipv6.add: overflow beyond 2^128"
    else
      mk [
        result0.sum
        result1.sum
        result2.sum
        result3.sum
      ];

  # Subtract a non-negative int `n` (which fits in signed 63 bits) from
  # the 128-bit value. Throws on underflow below 0.
  subU63 =
    n: ip:
    let
      lowOffset = builtins.bitAnd n bits.mask32;
      highOffset = bits.shr 32 n;
      result3 = carry.sub32 (wordAt 3 ip) lowOffset 0;
      result2 = carry.sub32 (wordAt 2 ip) highOffset result3.borrow;
      result1 = carry.sub32 (wordAt 1 ip) 0 result2.borrow;
      result0 = carry.sub32 (wordAt 0 ip) 0 result1.borrow;
    in
    if result0.borrow == 1 then
      throw "libnet.ipv6.sub: underflow below 0"
    else
      mk [
        result0.diff
        result1.diff
        result2.diff
        result3.diff
      ];

  /*
    Offset an address by an integer, carrying across the four words;
    curried so `add n` can be mapped.

    `n`: integer offset; may be negative.
    `ip`: IPv6 value.

    Returns an IPv6 value; throws on overflow past
    ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff or underflow below `::`.
  */
  add =
    n: ip:
    if n == 0 then
      ip
    else if n > 0 then
      addU63 n ip
    else
      subU63 (0 - n) ip;

  /*
    Offset an address downwards by an integer.

    `n`: integer to subtract; may be negative.
    `ip`: IPv6 value.

    Returns an IPv6 value; throws if the result leaves the address space.
  */
  sub = n: ip: add (0 - n) ip;

  /*
    Get the address one above `ip`. Equivalent to `add 1`, so it can be
    mapped over a list of addresses.

    `ip`: IPv6 value.

    Returns an IPv6 value; throws at the highest address,
    ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff.
  */
  next = ip: add 1 ip;

  /*
    Get the address one below `ip`. Equivalent to `sub 1`, so it can be
    mapped over a list of addresses.

    `ip`: IPv6 value.

    Returns an IPv6 value; throws at `::`.
  */
  prev = ip: sub 1 ip;

  # Multi-word unsigned subtract of two lists of 4 u32 words, MSB first.
  # Returns { words = [...]; finalBorrow = 0 or 1 }.
  subMultiWord =
    minuend: subtrahend:
    let
      subtractWord =
        i: borrow: carry.sub32 (builtins.elemAt minuend i) (builtins.elemAt subtrahend i) borrow;
      result3 = subtractWord 3 0;
      result2 = subtractWord 2 result3.borrow;
      result1 = subtractWord 1 result2.borrow;
      result0 = subtractWord 0 result1.borrow;
    in
    {
      words = [
        result0.diff
        result1.diff
        result2.diff
        result3.diff
      ];
      finalBorrow = result0.borrow;
    };

  # Pack the low 64 bits of a 4-word unsigned number into a signed 63-bit
  # int, or throw when it does not fit.
  lower64OrThrow =
    words:
    let
      word2 = builtins.elemAt words 2;
      word3 = builtins.elemAt words 3;
    in
    if builtins.elemAt words 0 != 0 || builtins.elemAt words 1 != 0 then
      throw "libnet.ipv6.diff: result exceeds signed 63-bit int range"
    else if
      word2 >= 2147483648 # 2^31
    then
      throw "libnet.ipv6.diff: result exceeds signed 63-bit int range"
    else
      word2 * bits.pow2_32 + word3;

  /*
    Measure the distance between two addresses.

    `a`: IPv6 value to measure from.
    `b`: IPv6 value to measure to.

    Returns `b - a` as an integer, negative when `b` precedes `a`; throws
    if the difference does not fit in a signed 63-bit integer.
  */
  diff =
    a: b:
    let
      forward = subMultiWord b.words a.words;
    in
    if forward.finalBorrow == 0 then
      lower64OrThrow forward.words
    else
      let
        backward = subMultiWord a.words b.words;
      in
      0 - (lower64OrThrow backward.words);

  # ===== Comparison =====

  /*
    Order two addresses numerically, comparing words most significant
    first.

    `a`, `b`: IPv6 values.

    Returns -1 if `a < b`, 0 if equal, 1 if `a > b`.
  */
  compare =
    a: b:
    let
      compareWord =
        i:
        let
          wordA = builtins.elemAt a.words i;
          wordB = builtins.elemAt b.words i;
        in
        if wordA < wordB then
          -1
        else if wordA > wordB then
          1
        else
          0;
      compareFrom =
        i:
        if i == 4 then
          0
        else
          let
            wordOrder = compareWord i;
          in
          if wordOrder != 0 then wordOrder else compareFrom (i + 1);
    in
    compareFrom 0;

  /*
    Check whether two values are the same address. Never throws for
    values of a different `_type`.

    `a`, `b`: IPv6 values.

    Returns true when both tag and words match.
  */
  eq = a: b: types.hasSameTag a b && a.words == b.words;

  /*
    Check whether `a` sorts before `b`.

    `a`, `b`: IPv6 values.

    Returns a Boolean.
  */
  lt = a: b: compare a b == -1;

  /*
    Check whether `a` sorts before or equal to `b`.

    `a`, `b`: IPv6 values.

    Returns a Boolean.
  */
  le = a: b: compare a b <= 0;

  /*
    Check whether `a` sorts after `b`.

    `a`, `b`: IPv6 values.

    Returns a Boolean.
  */
  gt = a: b: compare a b == 1;

  /*
    Check whether `a` sorts after or equal to `b`.

    `a`, `b`: IPv6 values.

    Returns a Boolean.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lower of two addresses.

    `a`, `b`: IPv6 values.

    Returns `a` when the two are equal.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the higher of two addresses.

    `a`, `b`: IPv6 values.

    Returns `a` when the two are equal.
  */
  max = a: b: if ge a b then a else b;

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
    compare
    diff
    eq
    fromBytes
    fromEui64
    fromGroups
    fromIpv4Mapped
    fromWords
    ge
    gt
    is
    is6to4
    isBogon
    isDiscard
    isDocumentation
    isGlobal
    isIpv4Compatible
    isIpv4Mapped
    isLinkLocal
    isLoopback
    isMulticast
    isOrchid
    isSiteLocal
    isUniqueLocal
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
    toGroups
    toIpv4Mapped
    toString
    toStringBracketed
    toStringCompressed
    toStringExpanded
    toWords
    tryParse
    unspecified
    ;
}
