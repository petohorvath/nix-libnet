let
  pow2Table = builtins.genList (
    n:
    let
      go = i: acc: if i == 0 then acc else go (i - 1) (acc * 2);
    in
    go n 1
  ) 63;

  pow2 =
    n:
    if n < 0 then
      builtins.throw "libnet: bits.pow2: negative exponent: ${toString n}"
    else if n > 62 then
      builtins.throw "libnet: bits.pow2: exponent out of range (0..62): ${toString n}"
    else
      builtins.elemAt pow2Table n;

  shl = n: x: x * (pow2 n);

  shr = n: x: x / (pow2 n);

  mask =
    n:
    if n == 0 then
      0
    else if n < 0 || n > 62 then
      builtins.throw "libnet: bits.mask: n out of range (0..62): ${toString n}"
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

  bits =
    lo: width: x:
    builtins.bitAnd (shr lo x) (mask width);
in
{
  inherit
    pow2
    shl
    shr
    mask
    bits
    ;
  inherit
    mask8
    mask16
    mask24
    mask32
    mask48
    ;
  inherit
    pow2_8
    pow2_16
    pow2_24
    pow2_32
    pow2_48
    ;
}
