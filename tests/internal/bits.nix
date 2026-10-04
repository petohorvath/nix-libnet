{ harness }:
let
  bits = import ../../lib/internal/bits.nix;
  inherit (harness) throws;
in
{
  testPow2Of0 = {
    expr = bits.pow2 0;
    expected = 1;
  };
  testPow2Of1 = {
    expr = bits.pow2 1;
    expected = 2;
  };
  testPow2Of8 = {
    expr = bits.pow2 8;
    expected = 256;
  };
  testPow2Of16 = {
    expr = bits.pow2 16;
    expected = 65536;
  };
  testPow2Of32 = {
    expr = bits.pow2 32;
    expected = 4294967296;
  };
  testPow2Of48 = {
    expr = bits.pow2 48;
    expected = 281474976710656;
  };
  testPow2Of62 = {
    expr = bits.pow2 62;
    expected = 4611686018427387904;
  };
  testPow2RejectsNegative = {
    expr = throws (bits.pow2 (-1));
    expected = true;
  };
  testPow2RejectsOverflow = {
    expr = throws (bits.pow2 63);
    expected = true;
  };

  testShlBy0 = {
    expr = bits.shl 0 42;
    expected = 42;
  };
  testShlBy4 = {
    expr = bits.shl 4 1;
    expected = 16;
  };
  testShlBy8 = {
    expr = bits.shl 8 1;
    expected = 256;
  };
  testShlBy16 = {
    expr = bits.shl 16 1;
    expected = 65536;
  };
  testShlBy32 = {
    expr = bits.shl 32 1;
    expected = 4294967296;
  };

  testShrBy0 = {
    expr = bits.shr 0 42;
    expected = 42;
  };
  testShrBy4 = {
    expr = bits.shr 4 256;
    expected = 16;
  };
  testShrTruncates = {
    expr = bits.shr 4 255;
    expected = 15;
  };

  testMask0 = {
    expr = bits.mask 0;
    expected = 0;
  };
  testMask1 = {
    expr = bits.mask 1;
    expected = 1;
  };
  testMask8 = {
    expr = bits.mask 8;
    expected = 255;
  };
  testMask16 = {
    expr = bits.mask 16;
    expected = 65535;
  };
  testMask32 = {
    expr = bits.mask 32;
    expected = 4294967295;
  };
  testMaskRejectsOverflow = {
    expr = throws (bits.mask 63);
    expected = true;
  };

  testConstantMask8 = {
    expr = bits.mask8;
    expected = 255;
  };
  testConstantMask16 = {
    expr = bits.mask16;
    expected = 65535;
  };
  testConstantMask24 = {
    expr = bits.mask24;
    expected = 16777215;
  };
  testConstantMask32 = {
    expr = bits.mask32;
    expected = 4294967295;
  };
  testConstantMask48 = {
    expr = bits.mask48;
    expected = 281474976710655;
  };
  testConstantPow2_8 = {
    expr = bits.pow2_8;
    expected = 256;
  };
  testConstantPow2_16 = {
    expr = bits.pow2_16;
    expected = 65536;
  };
  testConstantPow2_24 = {
    expr = bits.pow2_24;
    expected = 16777216;
  };
  testConstantPow2_32 = {
    expr = bits.pow2_32;
    expected = 4294967296;
  };
  testConstantPow2_48 = {
    expr = bits.pow2_48;
    expected = 281474976710656;
  };

  # 0xABCDEF = 11259375 ; bytes: EF=239, CD=205, AB=171
  testBitsByte0 = {
    expr = bits.bits 0 8 11259375;
    expected = 239;
  };
  testBitsByte1 = {
    expr = bits.bits 8 8 11259375;
    expected = 205;
  };
  testBitsByte2 = {
    expr = bits.bits 16 8 11259375;
    expected = 171;
  };
  testBitsByte3 = {
    expr = bits.bits 24 8 11259375;
    expected = 0;
  };

  testShlPartialApplication = {
    expr = map (bits.shl 8) [
      1
      2
      3
    ];
    expected = [
      256
      512
      768
    ];
  };
  testShrPartialApplication = {
    expr = map (bits.shr 1) [
      2
      4
      6
    ];
    expected = [
      1
      2
      3
    ];
  };
}
