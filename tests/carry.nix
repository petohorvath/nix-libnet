{ harness }:
let
  carry = import ../lib/internal/carry.nix;
in
{
  add-simple       = { expr = carry.add32 1 2 0; expected = { sum = 3; carry = 0; }; };
  add-with-cin     = { expr = carry.add32 1 2 1; expected = { sum = 4; carry = 0; }; };
  add-overflow     = { expr = carry.add32 4294967295 1 0; expected = { sum = 0; carry = 1; }; };
  add-max-plus-max = { expr = carry.add32 4294967295 4294967295 0; expected = { sum = 4294967294; carry = 1; }; };
  add-max-max-cin  = { expr = carry.add32 4294967295 4294967295 1; expected = { sum = 4294967295; carry = 1; }; };
  add-zero         = { expr = carry.add32 0 0 0; expected = { sum = 0; carry = 0; }; };
  add-cin-only     = { expr = carry.add32 4294967295 0 1; expected = { sum = 0; carry = 1; }; };

  sub-simple       = { expr = carry.sub32 5 3 0; expected = { diff = 2; borrow = 0; }; };
  sub-with-bin     = { expr = carry.sub32 5 3 1; expected = { diff = 1; borrow = 0; }; };
  sub-underflow    = { expr = carry.sub32 0 1 0; expected = { diff = 4294967295; borrow = 1; }; };
  sub-zero-one-one = { expr = carry.sub32 0 0 1; expected = { diff = 4294967295; borrow = 1; }; };
  sub-max          = { expr = carry.sub32 4294967295 4294967295 0; expected = { diff = 0; borrow = 0; }; };
  sub-max-plus-bin = { expr = carry.sub32 4294967295 4294967295 1; expected = { diff = 4294967295; borrow = 1; }; };
}
