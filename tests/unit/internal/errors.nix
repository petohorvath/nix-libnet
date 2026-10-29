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

  # ===== detail =====
  testDetailDropsCallersPrefix = {
    expr = errors.detail "dnsName.parse" "libnet.dnsName.parse: \"a_b\" is not valid";
    expected = "\"a_b\" is not valid";
  };
  testDetailKeepsOtherText = {
    expr = errors.detail "dnsName.parse" "libnet.hostname.parse: bad";
    expected = "libnet.hostname.parse: bad";
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

  # ===== notString =====
  testNotStringDescribesInput = {
    expr = map errors.notString [
      80
      port
    ];
    expected = [
      "expected string, got int"
      "expected string, got port value"
    ];
  };

  # ===== intArgument =====
  testIntArgumentReturnsValue = {
    expr = errors.intArgument "cidr" "addressAt" 3;
    expected = 3;
  };
  testIntArgumentNamesFunction = {
    expr = errors.intArgument "cidr" "addressAt" "3";
    expectedError.msg = "^libnet\\.cidr\\.addressAt: expected int, got string$";
  };

  # ===== expect =====
  testExpectNamesExpectedKinds = {
    expr = errors.expect "ip.toString" "ipv4 or ipv6 value" (_: false) port;
    expectedError.msg = "^libnet\\.ip\\.toString: expected ipv4 or ipv6 value, got port value$";
  };

  # ===== expectFields =====
  testExpectFieldsReturnsArguments = {
    expr = errors.expectFields "url.make" {
      required = [ "scheme" ];
      optional = [ "path" ];
    } { scheme = "http"; };
    expected = {
      scheme = "http";
    };
  };
  testExpectFieldsDoesNotForceValues = {
    expr =
      (errors.expectFields "url.make" {
        required = [ "scheme" ];
        optional = [ ];
      } { scheme = throw "value forced"; })
        ? scheme;
    expected = true;
  };
  testExpectFieldsRejectsNonSet = {
    expr = errors.expectFields "url.make" {
      required = [ ];
      optional = [ ];
    } "http://h";
    expectedError.msg = "^libnet\\.url\\.make: expected set, got string$";
  };
  testExpectFieldsRejectsMissing = {
    expr = errors.expectFields "url.make" {
      required = [ "scheme" ];
      optional = [ ];
    } { };
    expectedError.msg = "^libnet\\.url\\.make: missing attribute \"scheme\"$";
  };
  testExpectFieldsRejectsUnexpected = {
    expr = errors.expectFields "url.make" {
      required = [ ];
      optional = [ "path" ];
    } { host = "h"; };
    expectedError.msg = "^libnet\\.url\\.make: unexpected attribute \"host\"$";
  };
}
