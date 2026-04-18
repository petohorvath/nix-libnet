{ harness }:
let
  bits = import ../lib/internal/bits.nix;
  inherit (harness) throws;
in
{
  pow2-0     = { expr = bits.pow2 0;  expected = 1; };
  pow2-1     = { expr = bits.pow2 1;  expected = 2; };
  pow2-8     = { expr = bits.pow2 8;  expected = 256; };
  pow2-16    = { expr = bits.pow2 16; expected = 65536; };
  pow2-32    = { expr = bits.pow2 32; expected = 4294967296; };
  pow2-48    = { expr = bits.pow2 48; expected = 281474976710656; };
  pow2-62    = { expr = bits.pow2 62; expected = 4611686018427387904; };
  pow2-neg   = { expr = throws (bits.pow2 (-1)); expected = true; };
  pow2-over  = { expr = throws (bits.pow2 63);   expected = true; };

  shl-by-0   = { expr = bits.shl 0 42;  expected = 42; };
  shl-by-4   = { expr = bits.shl 4 1;   expected = 16; };
  shl-by-8   = { expr = bits.shl 8 1;   expected = 256; };
  shl-by-16  = { expr = bits.shl 16 1;  expected = 65536; };
  shl-by-32  = { expr = bits.shl 32 1;  expected = 4294967296; };

  shr-by-0   = { expr = bits.shr 0 42;  expected = 42; };
  shr-by-4   = { expr = bits.shr 4 256; expected = 16; };
  shr-trunc  = { expr = bits.shr 4 255; expected = 15; };

  mask-0     = { expr = bits.mask 0;   expected = 0; };
  mask-1     = { expr = bits.mask 1;   expected = 1; };
  mask-8     = { expr = bits.mask 8;   expected = 255; };
  mask-16    = { expr = bits.mask 16;  expected = 65535; };
  mask-32    = { expr = bits.mask 32;  expected = 4294967295; };
  mask-over  = { expr = throws (bits.mask 63); expected = true; };

  const-mask8   = { expr = bits.mask8;  expected = 255; };
  const-mask16  = { expr = bits.mask16; expected = 65535; };
  const-mask24  = { expr = bits.mask24; expected = 16777215; };
  const-mask32  = { expr = bits.mask32; expected = 4294967295; };
  const-mask48  = { expr = bits.mask48; expected = 281474976710655; };
  const-pow2_8  = { expr = bits.pow2_8;  expected = 256; };
  const-pow2_16 = { expr = bits.pow2_16; expected = 65536; };
  const-pow2_24 = { expr = bits.pow2_24; expected = 16777216; };
  const-pow2_32 = { expr = bits.pow2_32; expected = 4294967296; };
  const-pow2_48 = { expr = bits.pow2_48; expected = 281474976710656; };

  # 0xABCDEF = 11259375 ; bytes: EF=239, CD=205, AB=171
  bits-byte0 = { expr = bits.bits 0  8 11259375; expected = 239; };
  bits-byte1 = { expr = bits.bits 8  8 11259375; expected = 205; };
  bits-byte2 = { expr = bits.bits 16 8 11259375; expected = 171; };
  bits-byte3 = { expr = bits.bits 24 8 11259375; expected = 0; };

  curry-shl  = { expr = map (bits.shl 8) [ 1 2 3 ]; expected = [ 256 512 768 ]; };
  curry-shr  = { expr = map (bits.shr 1) [ 2 4 6 ]; expected = [ 1 2 3 ]; };
}
