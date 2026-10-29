{ internal, ... }:
let
  inherit (internal) errors;

  port = {
    _type = "port";
    value = 80;
  };
in
{
  # ===== message and fail =====
  testMessageAddsPrefix = {
    expr = errors.message "port.add" "out of range";
    expected = "libnet.port.add: out of range";
  };
  testFailThrowsMessage = {
    expr = errors.fail "port.add" "out of range";
    expectedError.msg = "^libnet\\.port\\.add: out of range$";
  };

  # ===== detailOf =====
  testDetailOfStripsPrefix = {
    expr = errors.detailOf "ipv4.parse" "libnet.ipv4.parse: invalid octet in \"300.1.1.1\"";
    expected = "invalid octet in \"300.1.1.1\"";
  };
  testDetailOfKeepsOtherCaller = {
    expr = errors.detailOf "ipv4.parse" "libnet.ipv6.parse: empty string";
    expected = "libnet.ipv6.parse: empty string";
  };

  # ===== describe =====
  # No description coerces the value, so none of these can fail.
  testDescribeBuiltinTypes = {
    expr = map errors.describe [
      80
      1.5
      "80"
      true
      null
      [ ]
      { }
      (x: x)
      ./errors.nix
    ];
    expected = [
      "int"
      "float"
      "string"
      "bool"
      "null"
      "list"
      "set"
      "lambda"
      "path"
    ];
  };
  testDescribeTaggedValue = {
    expr = errors.describe port;
    expected = "port value";
  };
  testDescribeTagOnly = {
    expr = errors.describe { _type = "foreign"; };
    expected = "foreign value";
  };
  testDescribeNonStringTag = {
    expr = errors.describe { _type = { }; };
    expected = "set";
  };

  # ===== expectKind =====
  testExpectKindReturnsValue = {
    expr = errors.expectKind "port.toString" "port" port;
    expected = port;
  };
  testExpectKindDoesNotForcePayload = {
    expr =
      (errors.expectKind "port.toString" "port" {
        _type = "port";
        value = throw "payload forced";
      })._type;
    expected = "port";
  };
  testExpectKindRejectsOtherKind = {
    expr = errors.expectKind "port.toString" "port" {
      _type = "vlanId";
      value = 80;
    };
    expectedError.msg = "^libnet\\.port\\.toString: expected port value, got vlanId value$";
  };
  testExpectKindRejectsRawValue = {
    expr = errors.expectKind "port.toString" "port" { };
    expectedError.msg = "^libnet\\.port\\.toString: expected port value, got set$";
  };

  # ===== expectType =====
  testExpectTypeReturnsValue = {
    expr = errors.expectType "port.fromInt" "int" 80;
    expected = 80;
  };
  testExpectTypeRejectsOtherType = {
    expr = errors.expectType "port.fromInt" "int" 80.0;
    expectedError.msg = "^libnet\\.port\\.fromInt: expected int, got float$";
  };
  testExpectTypeRejectsTaggedValue = {
    expr = errors.expectType "port.fromInt" "int" port;
    expectedError.msg = "^libnet\\.port\\.fromInt: expected int, got port value$";
  };

  # ===== expect =====
  testExpectNamesExpectedKinds = {
    expr = errors.expect "ip.toString" "ipv4 or ipv6 value" (_: false) port;
    expectedError.msg = "^libnet\\.ip\\.toString: expected ipv4 or ipv6 value, got port value$";
  };
}
