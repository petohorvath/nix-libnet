/*
  Shared address/prefix text and construction for CIDR and InterfaceAddress.
  Both retain host bits. Network canonicalization and identity belong to
  the domain modules; the tag also supplies their existing error context.
*/
{ typeName }:
let
  parse' = import ./parse.nix;
  types = import ./types.nix;
  ipv4 = import ../ipv4.nix;
  ipv6 = import ../ipv6.nix;

  mk = addr: prefix: {
    _type = typeName;
    address = addr;
    inherit prefix;
  };

  isV4 = addr: addr._type == "ipv4";

  maxPrefix = addr: if isV4 addr then 32 else 128;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.${typeName}.parse: input must be a string"
    else
      let
        parts = parse'.splitOn "/" s;
      in
      if builtins.length parts != 2 then
        types.tryErr "libnet.${typeName}.parse: missing '/': \"${s}\""
      else
        let
          addrStr = builtins.elemAt parts 0;
          prefStr = builtins.elemAt parts 1;
          isV6Str = parse'.countOccurrences ":" addrStr > 0;
          addrRes = if isV6Str then ipv6.tryParse addrStr else ipv4.tryParse addrStr;
          prefInt = parse'.decimal prefStr;
        in
        if !addrRes.success then
          types.tryErr "libnet.${typeName}.parse: ${addrRes.error}"
        else if prefInt == null then
          types.tryErr "libnet.${typeName}.parse: invalid prefix \"${prefStr}\""
        else if prefInt > (maxPrefix addrRes.value) then
          types.tryErr "libnet.${typeName}.parse: prefix /${prefStr} out of range"
        else
          types.tryOk (mk addrRes.value prefInt);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    c:
    let
      s = if isV4 c.address then ipv4.toString c.address else ipv6.toString c.address;
    in
    "${s}/${builtins.toString c.prefix}";

  make =
    addr: prefix:
    if !(types.isIp addr) then
      builtins.throw "libnet.${typeName}.make: address must be ipv4 or ipv6"
    else if !(builtins.isInt prefix) || prefix < 0 || prefix > (maxPrefix addr) then
      builtins.throw "libnet.${typeName}.make: prefix out of range"
    else
      mk addr prefix;

  fromAddress =
    addr:
    if !(types.isIp addr) then
      builtins.throw "libnet.${typeName}.fromAddress: expected ipv4 or ipv6 value"
    else
      mk addr (maxPrefix addr);

in
{
  # Unchecked construction is private to domain operations whose inputs
  # already satisfy the address/prefix invariants.
  inherit mk maxPrefix;
  inherit
    tryParse
    parse
    toString
    make
    fromAddress
    ;
}
