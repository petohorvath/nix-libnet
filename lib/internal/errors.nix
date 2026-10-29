/*
  The library's error rules. Every error reads `libnet.<caller>: <detail>`,
  where `caller` is the public function the user called, written
  `<namespace>.<function>`, such as `port.prev`. A public function adds the
  prefix once; a helper that throws on its behalf takes the caller as an
  argument instead of naming itself. Within a namespace, the argument
  guards are named `<kind>Argument`, such as `cidrArgument`, and take the
  short name of the public function, such as `contains`, adding the
  namespace themselves.

  The argument-kind guards check a tagged argument's `_type` or a raw
  argument's builtin type. Their messages describe the bad value without
  coercing it to a string, so a set or function argument still yields a
  libnet error rather than a coercion error.
*/
let
  types = import ./types.nix;

  # The text of an error raised by `caller`, for `tryParse` results.
  message = caller: detail: "libnet.${caller}: ${detail}";

  fail = caller: detail: throw (message caller detail);

  # A tagged value reads as `<kind> value`, anything else as its builtin
  # type, such as `int` or `set`. A non-string `_type` is not a tag.
  describe =
    value:
    if builtins.isAttrs value && value ? _type && builtins.isString value._type then
      "${value._type} value"
    else
      builtins.typeOf value;

  # The detail for a `parse` or `tryParse` input that is not a string.
  notString = input: "expected string, got ${describe input}";

  # Return `value` when `isExpected value` holds; otherwise throw
  # `expected <expected>, got <description>` for `caller`.
  expect =
    caller: expected: isExpected: value:
    if isExpected value then value else fail caller "expected ${expected}, got ${describe value}";

  # Expect a tagged value of the kind `tag`, such as `port`.
  expectKind = caller: tag: expect caller "${tag} value" (types.hasTag tag);

  # Expect a raw value of a builtin type, named as `builtins.typeOf` names
  # it, such as `int` or `string`.
  expectType = caller: typeName: expect caller typeName (value: builtins.typeOf value == typeName);

  # Expect an integer argument, such as an offset or an index, of the
  # public function `function` of `namespace`, a guard that several
  # namespaces bind as their `intArgument`.
  intArgument = namespace: function: expectType "${namespace}.${function}" "int";

  # Expect an attribute set argument, such as that of `url.make`, holding
  # every name in `required` and no name outside `required` and
  # `optional`. The attribute values are not forced.
  expectFields =
    caller:
    { required, optional }:
    arguments:
    let
      checked = expectType caller "set" arguments;
      missing = builtins.filter (name: !(checked ? ${name})) required;
      unexpected = builtins.filter (name: !(builtins.elem name (required ++ optional))) (
        builtins.attrNames checked
      );
    in
    if missing != [ ] then
      fail caller "missing attribute \"${builtins.head missing}\""
    else if unexpected != [ ] then
      fail caller "unexpected attribute \"${builtins.head unexpected}\""
    else
      checked;
in
{
  inherit
    describe
    expect
    expectFields
    expectKind
    expectType
    fail
    intArgument
    message
    notString
    ;
}
