{ helpers, libnet, ... }:
let
  inherit (libnet) interfaceName;
  inherit (helpers) throws;
  inherit (interfaceName) parse;

  # Nix string literals cannot spell these bytes, so decode them from JSON.
  # U+00A0 is the UTF-8 sequence C3 A0, so its second byte is byte 160.
  verticalTab = builtins.fromJSON ''"\u000b"'';
  formFeed = builtins.fromJSON ''"\u000c"'';
  byte160 = builtins.substring 1 1 (builtins.fromJSON ''"\u00a0"'');
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
  testToStringKeepsCase = {
    expr = interfaceName.toString (parse "Eth0");
    expected = "Eth0";
  };
  testToStringRejectsString = {
    expr = interfaceName.toString "eth0";
    expectedError.msg = "^libnet\\.interfaceName\\.toString: expected interfaceName value, got string$";
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
  testIsValidRejectVerticalTab = {
    expr = interfaceName.isValid "eth${verticalTab}0";
    expected = false;
  };
  testIsValidRejectFormFeed = {
    expr = interfaceName.isValid "eth${formFeed}0";
    expected = false;
  };
  # The kernel's isspace treats byte 160 as space, so dev_valid_name
  # rejects it, even inside the UTF-8 sequence for "à".
  testIsValidRejectByte160 = {
    expr = interfaceName.isValid "eth${byte160}0";
    expected = false;
  };
  testIsValidRejectUtf8WithByte160 = {
    expr = interfaceName.isValid "wlà0";
    expected = false;
  };
  # Other non-ASCII bytes are not space to the kernel.
  testIsValidAcceptsOtherUtf8 = {
    expr = interfaceName.isValid "wlé0";
    expected = true;
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
    expr = parse 42;
    expectedError.msg = "^libnet\\.interfaceName\\.parse: expected string, got int$";
  };
  testParseRejectSpaceNamesParse = {
    expr = parse "a b";
    expectedError.msg = "^libnet\\.interfaceName\\.parse: name contains '/', ':' or a space byte: \"a b\"$";
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
  testLtCaseSensitiveOrder = {
    expr = interfaceName.lt (parse "Eth0") (parse "eth0");
    expected = true;
  };
  testGeNamesItself = {
    expr = interfaceName.ge (parse "eth0") "eth0";
    expectedError.msg = "^libnet\\.interfaceName\\.ge: expected interfaceName value, got string$";
  };

  # ===== Constant =====
  testMaxLength = {
    expr = interfaceName.maxLength;
    expected = 15;
  };
}
