let
  bits = import ./bits.nix;

  # 32-bit add with carry-in. Inputs: u32 a, u32 b, carry in (0 or 1).
  # Output: { sum (u32), carry (0 or 1) }.
  add32 =
    a: b: carryIn:
    let
      total = a + b + carryIn;
    in
    {
      sum = builtins.bitAnd total bits.mask32;
      carry = if total > bits.mask32 then 1 else 0;
    };

  # 32-bit subtract with borrow-in. Computes a - b - borrowIn.
  # Output: { diff (u32), borrow (0 or 1) }.
  sub32 =
    a: b: borrowIn:
    let
      total = a - b - borrowIn;
    in
    if total < 0 then
      {
        diff = total + bits.pow2_32;
        borrow = 1;
      }
    else
      {
        diff = total;
        borrow = 0;
      };
in
{
  inherit add32 sub32;
}
