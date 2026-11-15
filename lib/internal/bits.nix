let
  # Nix integers are signed 64-bit, so 2^62 is the largest power of two
  # that fits.
  pow2Table = builtins.genList (
    n:
    let
      go = remaining: power: if remaining == 0 then power else go (remaining - 1) (power * 2);
    in
    go n 1
  ) 63;

  pow2 =
    n:
    if n < 0 then
      throw "libnet: bits.pow2: negative exponent: ${toString n}"
    else if n > 62 then
      throw "libnet: bits.pow2: exponent out of range (0..62): ${toString n}"
    else
      builtins.elemAt pow2Table n;

  shl = n: x: x * (pow2 n);

  shr = n: x: x / (pow2 n);

  mask =
    n:
    if n == 0 then
      0
    else if n < 0 || n > 62 then
      throw "libnet: bits.mask: n out of range (0..62): ${toString n}"
    else
      (pow2 n) - 1;

  mask8 = 255;
  mask16 = 65535;
  mask24 = 16777215;
  mask32 = 4294967295;
  mask48 = 281474976710655;

  pow2_8 = 256;
  pow2_16 = 65536;
  pow2_24 = 16777216;
  pow2_32 = 4294967296;
  pow2_48 = 281474976710656;

  # Extract `width` bits of `x`, starting `offset` bits from the least
  # significant end.
  bits =
    offset: width: x:
    builtins.bitAnd (shr offset x) (mask width);

  # The integer of a list of parts of `width` bits, most significant
  # first, such as the bytes of an IPv4 or a MAC address: the inverse of
  # `toParts`.
  fromParts =
    width:
    let
      base = pow2 width;
    in
    builtins.foldl' (accumulated: part: accumulated * base + part) 0;

  # Split the low `count` parts of `width` bits off `x`, most significant
  # first, such as the four bytes of an IPv4 address or the two groups of
  # an IPv6 word.
  toParts =
    width: count: x:
    builtins.genList (i: bits ((count - 1 - i) * width) width x) count;

  # Join a list of parts of `width` bits, which divides 32, into 32-bit
  # words, `32 / width` parts each, such as the groups or the bytes of an
  # IPv6 address into its four words.
  partsToWords =
    width: parts:
    let
      partsPerWord = 32 / width;
    in
    builtins.genList (
      word:
      fromParts width (builtins.genList (i: builtins.elemAt parts (word * partsPerWord + i)) partsPerWord)
    ) (builtins.length parts / partsPerWord);

  # Split 32-bit words into parts of `width` bits, which divides 32: the
  # inverse of `partsToWords`.
  wordsToParts = width: builtins.concatMap (toParts width (32 / width));
in
{
  inherit
    bits
    fromParts
    mask
    mask16
    mask24
    mask32
    mask48
    mask8
    partsToWords
    pow2
    pow2_16
    pow2_24
    pow2_32
    pow2_48
    pow2_8
    shl
    shr
    toParts
    wordsToParts
    ;
}
