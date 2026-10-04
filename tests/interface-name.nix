{ harness }:
let
  interfaceName = import ../lib/interface-name.nix;
  inherit (harness) throws;
  parse = interfaceName.parse;
in
{
  # ===== parse / toString / accessor =====
  testParseOk = {
    expr = (parse "eth0").value;
    expected = "eth0";
  };
  testParseTagged = {
    expr = (parse "eth0")._type;
    expected = "interfaceName";
  };
  testToStringRoundTrip = {
    expr = interfaceName.toString (parse "br-home");
    expected = "br-home";
  };
  testValueAccessor = {
    expr = interfaceName.value (parse "wg0");
    expected = "wg0";
  };

  # ===== isValid — kernel dev_valid_name parity =====
  testIsValidOk = {
    expr = interfaceName.isValid "eth0";
    expected = true;
  };
  testIsValidOk15Bytes = {
    expr = interfaceName.isValid "abcdefghijklmno";
    expected = true;
  };
  testIsValidRejectEmpty = {
    expr = interfaceName.isValid "";
    expected = false;
  };
  testIsValidReject16Bytes = {
    expr = interfaceName.isValid "abcdefghijklmnop";
    expected = false;
  };
  testIsValidRejectDot = {
    expr = interfaceName.isValid ".";
    expected = false;
  };
  testIsValidRejectDotDot = {
    expr = interfaceName.isValid "..";
    expected = false;
  };
  testIsValidRejectSlash = {
    expr = interfaceName.isValid "eth/0";
    expected = false;
  };
  testIsValidRejectColon = {
    expr = interfaceName.isValid "eth:0";
    expected = false;
  };
  testIsValidRejectSpace = {
    expr = interfaceName.isValid "eth 0";
    expected = false;
  };
  testIsValidRejectTab = {
    expr = interfaceName.isValid "eth\t0";
    expected = false;
  };
  testIsValidRejectNewline = {
    expr = interfaceName.isValid "eth\n0";
    expected = false;
  };
  testIsValidRejectCarriageReturn = {
    expr = interfaceName.isValid "eth\r0";
    expected = false;
  };
  testIsValidAcceptsDash = {
    expr = interfaceName.isValid "br-home";
    expected = true;
  };
  testIsValidAcceptsDotInMiddle = {
    expr = interfaceName.isValid "vlan.100";
    expected = true;
  };
  testIsValidAcceptsUnderscore = {
    expr = interfaceName.isValid "wg_0";
    expected = true;
  };
  testIsValidNotString = {
    expr = interfaceName.isValid 42;
    expected = false;
  };

  # ===== parse rejects (mirror validity) =====
  testParseRejectEmpty = {
    expr = throws (parse "");
    expected = true;
  };
  testParseReject16Bytes = {
    expr = throws (parse "abcdefghijklmnop");
    expected = true;
  };
  testParseRejectSlash = {
    expr = throws (parse "eth/0");
    expected = true;
  };
  testParseNotString = {
    expr = throws (parse 42);
    expected = true;
  };
  testTryParseOk = {
    expr = (interfaceName.tryParse "eth0").success;
    expected = true;
  };
  testTryParseBad = {
    expr = (interfaceName.tryParse "").success;
    expected = false;
  };

  # ===== Predicates =====
  testIsParsed = {
    expr = interfaceName.is (parse "eth0");
    expected = true;
  };
  testIsString = {
    expr = interfaceName.is "eth0";
    expected = false;
  };

  # ===== Comparison =====
  testEqSame = {
    expr = interfaceName.eq (parse "eth0") (parse "eth0");
    expected = true;
  };
  testEqDifferent = {
    expr = interfaceName.eq (parse "eth0") (parse "eth1");
    expected = false;
  };
  testEqCaseSensitive = {
    expr = interfaceName.eq (parse "Eth0") (parse "eth0");
    expected = false;
  };
  testCompareLt = {
    expr = interfaceName.compare (parse "eth0") (parse "eth1");
    expected = -1;
  };
  testCompareEq = {
    expr = interfaceName.compare (parse "eth0") (parse "eth0");
    expected = 0;
  };
  testCompareGt = {
    expr = interfaceName.compare (parse "eth1") (parse "eth0");
    expected = 1;
  };
  testMin = {
    expr = interfaceName.toString (interfaceName.min (parse "eth1") (parse "eth0"));
    expected = "eth0";
  };
  testMax = {
    expr = interfaceName.toString (interfaceName.max (parse "eth1") (parse "eth0"));
    expected = "eth1";
  };

  # ===== Constant =====
  testIfnamsiz = {
    expr = interfaceName.ifnamsiz;
    expected = 16;
  };
}
