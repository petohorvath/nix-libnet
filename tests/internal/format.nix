{ harness }:
let
  formatting = import ../../lib/internal/format.nix;
in
{
  # ===== hex1 =====
  testHex1Of0 = {
    expr = formatting.hex1 0;
    expected = "0";
  };
  testHex1Of9 = {
    expr = formatting.hex1 9;
    expected = "9";
  };
  testHex1Of10 = {
    expr = formatting.hex1 10;
    expected = "a";
  };
  testHex1Of15 = {
    expr = formatting.hex1 15;
    expected = "f";
  };

  # ===== hex2 =====
  testHex2Of0 = {
    expr = formatting.hex2 0;
    expected = "00";
  };
  testHex2Of1 = {
    expr = formatting.hex2 1;
    expected = "01";
  };
  testHex2Of15 = {
    expr = formatting.hex2 15;
    expected = "0f";
  };
  testHex2Of16 = {
    expr = formatting.hex2 16;
    expected = "10";
  };
  testHex2Of255 = {
    expr = formatting.hex2 255;
    expected = "ff";
  };

  # ===== hex4 =====
  testHex4Of0 = {
    expr = formatting.hex4 0;
    expected = "0000";
  };
  testHex4Of1 = {
    expr = formatting.hex4 1;
    expected = "0001";
  };
  testHex4Of255 = {
    expr = formatting.hex4 255;
    expected = "00ff";
  };
  testHex4Of0x1234 = {
    expr = formatting.hex4 4660;
    expected = "1234";
  };
  testHex4Max = {
    expr = formatting.hex4 65535;
    expected = "ffff";
  };

  # ===== hex (unpadded) =====
  testHexOf0 = {
    expr = formatting.hex 0;
    expected = "0";
  };
  testHexOf15 = {
    expr = formatting.hex 15;
    expected = "f";
  };
  testHexOf16 = {
    expr = formatting.hex 16;
    expected = "10";
  };
  testHexOf255 = {
    expr = formatting.hex 255;
    expected = "ff";
  };
  testHexOf256 = {
    expr = formatting.hex 256;
    expected = "100";
  };
  testHex16BitMax = {
    expr = formatting.hex 65535;
    expected = "ffff";
  };

  # ===== longestZeroRun =====
  # len < 2 is not a qualifying run.
  testZeroRunEmpty = {
    expr = formatting.longestZeroRun [ ];
    expected = {
      start = -1;
      len = 0;
    };
  };
  testZeroRunNoZeros = {
    expr = formatting.longestZeroRun [
      1
      2
      3
    ];
    expected = {
      start = -1;
      len = 0;
    };
  };
  testZeroRunSingleZero = {
    expr = formatting.longestZeroRun [
      1
      0
      2
    ];
    expected = {
      start = -1;
      len = 0;
    };
  };
  testZeroRunTwo = {
    expr = formatting.longestZeroRun [
      0
      0
    ];
    expected = {
      start = 0;
      len = 2;
    };
  };
  testZeroRunMiddle = {
    expr = formatting.longestZeroRun [
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
  testZeroRunPrefersLonger = {
    expr = formatting.longestZeroRun [
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
  testZeroRunTieEarliest = {
    expr = formatting.longestZeroRun [
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
  testZeroRunLeading = {
    expr = formatting.longestZeroRun [
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
  testZeroRunTrailing = {
    expr = formatting.longestZeroRun [
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
  testZeroRunAll = {
    expr = formatting.longestZeroRun [
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
