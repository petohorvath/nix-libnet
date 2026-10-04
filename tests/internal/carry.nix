{ harness }:
let
  carry = import ../../lib/internal/carry.nix;
in
{
  testAddSimple = {
    expr = carry.add32 1 2 0;
    expected = {
      sum = 3;
      carry = 0;
    };
  };
  testAddWithCarryIn = {
    expr = carry.add32 1 2 1;
    expected = {
      sum = 4;
      carry = 0;
    };
  };
  testAddOverflow = {
    expr = carry.add32 4294967295 1 0;
    expected = {
      sum = 0;
      carry = 1;
    };
  };
  testAddMaxPlusMax = {
    expr = carry.add32 4294967295 4294967295 0;
    expected = {
      sum = 4294967294;
      carry = 1;
    };
  };
  testAddMaxPlusMaxWithCarryIn = {
    expr = carry.add32 4294967295 4294967295 1;
    expected = {
      sum = 4294967295;
      carry = 1;
    };
  };
  testAddZero = {
    expr = carry.add32 0 0 0;
    expected = {
      sum = 0;
      carry = 0;
    };
  };
  testAddCarryInOnly = {
    expr = carry.add32 4294967295 0 1;
    expected = {
      sum = 0;
      carry = 1;
    };
  };

  testSubSimple = {
    expr = carry.sub32 5 3 0;
    expected = {
      diff = 2;
      borrow = 0;
    };
  };
  testSubWithBorrowIn = {
    expr = carry.sub32 5 3 1;
    expected = {
      diff = 1;
      borrow = 0;
    };
  };
  testSubUnderflow = {
    expr = carry.sub32 0 1 0;
    expected = {
      diff = 4294967295;
      borrow = 1;
    };
  };
  testSubZeroWithBorrowIn = {
    expr = carry.sub32 0 0 1;
    expected = {
      diff = 4294967295;
      borrow = 1;
    };
  };
  testSubMax = {
    expr = carry.sub32 4294967295 4294967295 0;
    expected = {
      diff = 0;
      borrow = 0;
    };
  };
  testSubMaxWithBorrowIn = {
    expr = carry.sub32 4294967295 4294967295 1;
    expected = {
      diff = 4294967295;
      borrow = 1;
    };
  };
}
