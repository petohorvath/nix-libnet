{ harness }:
let
  fmt = import ../../lib/internal/format.nix;
in
{
  # ===== hex1 =====
  hex1-0 = {
    expr = fmt.hex1 0;
    expected = "0";
  };
  hex1-9 = {
    expr = fmt.hex1 9;
    expected = "9";
  };
  hex1-10 = {
    expr = fmt.hex1 10;
    expected = "a";
  };
  hex1-15 = {
    expr = fmt.hex1 15;
    expected = "f";
  };

  # ===== hex2 =====
  hex2-0 = {
    expr = fmt.hex2 0;
    expected = "00";
  };
  hex2-1 = {
    expr = fmt.hex2 1;
    expected = "01";
  };
  hex2-15 = {
    expr = fmt.hex2 15;
    expected = "0f";
  };
  hex2-16 = {
    expr = fmt.hex2 16;
    expected = "10";
  };
  hex2-255 = {
    expr = fmt.hex2 255;
    expected = "ff";
  };

  # ===== hex4 =====
  hex4-0 = {
    expr = fmt.hex4 0;
    expected = "0000";
  };
  hex4-1 = {
    expr = fmt.hex4 1;
    expected = "0001";
  };
  hex4-255 = {
    expr = fmt.hex4 255;
    expected = "00ff";
  };
  hex4-0x1234 = {
    expr = fmt.hex4 4660;
    expected = "1234";
  };
  hex4-max = {
    expr = fmt.hex4 65535;
    expected = "ffff";
  };

  # ===== hex (unpadded) =====
  hex-0 = {
    expr = fmt.hex 0;
    expected = "0";
  };
  hex-15 = {
    expr = fmt.hex 15;
    expected = "f";
  };
  hex-16 = {
    expr = fmt.hex 16;
    expected = "10";
  };
  hex-255 = {
    expr = fmt.hex 255;
    expected = "ff";
  };
  hex-256 = {
    expr = fmt.hex 256;
    expected = "100";
  };
  hex-u16-max = {
    expr = fmt.hex 65535;
    expected = "ffff";
  };

  # ===== longestZeroRun =====
  # len < 2 is not a qualifying run.
  zeroRun-empty = {
    expr = fmt.longestZeroRun [ ];
    expected = {
      start = -1;
      len = 0;
    };
  };
  zeroRun-no-zeros = {
    expr = fmt.longestZeroRun [
      1
      2
      3
    ];
    expected = {
      start = -1;
      len = 0;
    };
  };
  zeroRun-single-zero = {
    expr = fmt.longestZeroRun [
      1
      0
      2
    ];
    expected = {
      start = -1;
      len = 0;
    };
  };
  zeroRun-two = {
    expr = fmt.longestZeroRun [
      0
      0
    ];
    expected = {
      start = 0;
      len = 2;
    };
  };
  zeroRun-middle = {
    expr = fmt.longestZeroRun [
      1
      0
      0
      1
    ];
    expected = {
      start = 1;
      len = 2;
    };
  };
  zeroRun-prefers-longer = {
    expr = fmt.longestZeroRun [
      0
      0
      1
      0
      0
      0
    ];
    expected = {
      start = 3;
      len = 3;
    };
  };
  zeroRun-tie-earliest = {
    expr = fmt.longestZeroRun [
      0
      0
      1
      0
      0
    ];
    expected = {
      start = 0;
      len = 2;
    };
  };
  zeroRun-leading = {
    expr = fmt.longestZeroRun [
      0
      0
      0
      1
    ];
    expected = {
      start = 0;
      len = 3;
    };
  };
  zeroRun-trailing = {
    expr = fmt.longestZeroRun [
      1
      0
      0
      0
    ];
    expected = {
      start = 1;
      len = 3;
    };
  };
  zeroRun-all = {
    expr = fmt.longestZeroRun [
      0
      0
      0
      0
    ];
    expected = {
      start = 0;
      len = 4;
    };
  };
}
