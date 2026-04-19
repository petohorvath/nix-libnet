/*
  libnet.interface

  Network interface descriptor: an optional Linux ifname combined
  with an optional address and prefix length. The ifname validator
  mirrors the kernel's dev_valid_name (length < IFNAMSIZ, not "." or
  "..", no '/', ':', or whitespace).

  Example:
    libnet.interface.make (libnet.ipv4.parse "192.0.2.1") 24
    => { _type = "interface"; name = null; address = <ipv4>; prefix = 24; }
*/
let
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  cidr = import ./cidr.nix;
  ipRange = import ./ip-range.nix;

  # IFNAMSIZ from <linux/if.h>: the kernel stores names in a 16-byte
  # buffer including the terminating NUL, so the on-wire length is < 16.
  ifnamsiz = 16;

  # Kernel-parity interface-name validator, matching net/core/dev.c
  # dev_valid_name(): non-empty, length < IFNAMSIZ, not "." / "..",
  # no '/', no ':', no isspace(3) byte.  [[:space:]] in POSIX ERE covers
  # the six kernel-recognized whitespace bytes (SP HT LF VT FF CR).
  isValidName =
    s:
    builtins.isString s
    && s != ""
    && builtins.stringLength s < ifnamsiz
    && s != "."
    && s != ".."
    && builtins.match ".*[/:[:space:]].*" s == null;

  mk = name: addr: prefix: {
    _type = "interface";
    inherit name;
    address = addr;
    inherit prefix;
  };

  isV4 = addr: addr._type == "ipv4";

  maxPrefix = addr: if isV4 addr then 32 else 128;

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.interface.parse: input must be a string"
    else
      let
        parts = parse'.splitOn "/" s;
      in
      if builtins.length parts != 2 then
        types.tryErr "libnet.interface.parse: missing '/': \"${s}\""
      else
        let
          addrStr = builtins.elemAt parts 0;
          prefStr = builtins.elemAt parts 1;
          isV6Str = parse'.countOccurrences ":" addrStr > 0;
          addrRes = if isV6Str then ipv6.tryParse addrStr else ipv4.tryParse addrStr;
          prefInt = parse'.decimal prefStr;
        in
        if !addrRes.success then
          types.tryErr "libnet.interface.parse: ${addrRes.error}"
        else if prefInt == null then
          types.tryErr "libnet.interface.parse: invalid prefix \"${prefStr}\""
        else if prefInt > maxPrefix addrRes.value then
          types.tryErr "libnet.interface.parse: prefix /${prefStr} out of range"
        else
          types.tryOk (mk null addrRes.value prefInt);

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  tryParseName =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.interface.parseName: input must be a string"
    else if s == "" then
      types.tryErr "libnet.interface.parseName: empty name"
    else if builtins.stringLength s >= ifnamsiz then
      types.tryErr "libnet.interface.parseName: name too long (max 15 bytes): \"${s}\""
    else if s == "." || s == ".." then
      types.tryErr "libnet.interface.parseName: reserved name \"${s}\""
    else if builtins.match ".*[/:[:space:]].*" s != null then
      types.tryErr "libnet.interface.parseName: name contains '/' or ':' or whitespace: \"${s}\""
    else
      types.tryOk (mk s null null);

  parseName =
    s:
    let
      r = tryParseName s;
    in
    if r.success then r.value else builtins.throw r.error;

  # ===== Formatting =====

  # Canonical text form carries addr/prefix only. When an iface has both
  # a name and an address, toString emits only the addr/prefix — the name
  # is metadata (access via `name iface`). Linux tooling keeps the two
  # fields structurally separate (`ip addr add <addr/prefix> dev <name>`);
  # there is no widely-adopted single-string composite form. RFC 4007's
  # `%<zone>` syntax is defined only for IPv6 link-local scope, and
  # SPEC.md defers zone identifiers to v2.
  toString =
    i:
    if i.address == null then
      i.name
    else
      let
        s = if isV4 i.address then ipv4.toString i.address else ipv6.toString i.address;
      in
      "${s}/${builtins.toString i.prefix}";

  # ===== Construction =====

  make =
    addr: prefix:
    if !(types.isIp addr) then
      builtins.throw "libnet.interface.make: address must be ipv4 or ipv6"
    else if !(builtins.isInt prefix) || prefix < 0 || prefix > maxPrefix addr then
      builtins.throw "libnet.interface.make: prefix out of range"
    else
      mk null addr prefix;

  makeName =
    name:
    let
      r = tryParseName name;
    in
    if r.success then r.value else builtins.throw r.error;

  makeNamed =
    addr: prefix: name:
    if !(types.isIp addr) then
      builtins.throw "libnet.interface.makeNamed: address must be ipv4 or ipv6"
    else if !(builtins.isInt prefix) || prefix < 0 || prefix > maxPrefix addr then
      builtins.throw "libnet.interface.makeNamed: prefix out of range"
    else if !(isValidName name) then
      builtins.throw "libnet.interface.makeNamed: invalid name \"${
        if builtins.isString name then name else builtins.typeOf name
      }\""
    else
      mk name addr prefix;

  fromAddressAndNetwork =
    addr: net:
    if !(types.isIp addr) then
      builtins.throw "libnet.interface.fromAddressAndNetwork: address must be ipv4 or ipv6"
    else if !(types.isCidr net) then
      builtins.throw "libnet.interface.fromAddressAndNetwork: expected cidr as network"
    else if addr._type != net.address._type then
      builtins.throw "libnet.interface.fromAddressAndNetwork: family mismatch"
    else if !(cidr.containsAddress net addr) then
      builtins.throw "libnet.interface.fromAddressAndNetwork: address not in network"
    else
      mk null addr net.prefix;

  # ===== Combinators =====

  withName =
    name: i:
    if !(isValidName name) then
      builtins.throw "libnet.interface.withName: invalid name \"${
        if builtins.isString name then name else builtins.typeOf name
      }\""
    else
      mk name i.address i.prefix;

  withAddress =
    addr: prefix: i:
    if !(types.isIp addr) then
      builtins.throw "libnet.interface.withAddress: address must be ipv4 or ipv6"
    else if !(builtins.isInt prefix) || prefix < 0 || prefix > maxPrefix addr then
      builtins.throw "libnet.interface.withAddress: prefix out of range"
    else
      mk i.name addr prefix;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isInterface;
  isIpv4 = i: i.address != null && isV4 i.address;
  isIpv6 = i: i.address != null && !(isV4 i.address);
  hasName = i: i.name != null;
  hasAddress = i: i.address != null;

  # ===== Accessors =====

  name = i: i.name;
  address = i: i.address;
  prefix = i: i.prefix;
  version =
    i:
    if i.address == null then
      null
    else if isV4 i.address then
      4
    else
      6;

  network =
    i:
    if i.address == null then
      builtins.throw "libnet.interface.network: name-only interface has no network"
    else
      cidr.canonical (cidr.make i.address i.prefix);

  netmask =
    i:
    if i.address == null then
      builtins.throw "libnet.interface.netmask: name-only interface has no netmask"
    else
      cidr.netmask (cidr.make i.address i.prefix);

  hostmask =
    i:
    if i.address == null then
      builtins.throw "libnet.interface.hostmask: name-only interface has no hostmask"
    else
      cidr.hostmask (cidr.make i.address i.prefix);

  broadcast =
    i:
    if i.address == null then
      builtins.throw "libnet.interface.broadcast: name-only interface has no broadcast"
    else if !(isV4 i.address) then
      builtins.throw "libnet.interface.broadcast: IPv6 has no broadcast"
    else
      cidr.broadcast (cidr.make i.address i.prefix);

  # ===== Conversions =====

  toCidr =
    i:
    if i.address == null then
      builtins.throw "libnet.interface.toCidr: name-only interface has no CIDR"
    else
      network i;

  toRange =
    i:
    if i.address == null then
      builtins.throw "libnet.interface.toRange: name-only interface has no range"
    else
      ipRange.fromCidr (network i);

  # ===== Comparison =====

  eq =
    a: b:
    a.name == b.name
    && (a.address == null) == (b.address == null)
    && (
      a.address == null
      || (
        a.address._type == b.address._type
        && a.prefix == b.prefix
        && (if isV4 a.address then ipv4.eq a.address b.address else ipv6.eq a.address b.address)
      )
    );

  # Strict total order. Primary key: addr-present values sort before
  # name-only values. Within addr-present: v4 < v6, then address, then
  # prefix, then null-name < set-name, then name lex. Within name-only:
  # name lex. This preserves every legacy ordering of two addr-only
  # values.
  compare =
    a: b:
    if a.address != null && b.address == null then
      -1
    else if a.address == null && b.address != null then
      1
    else if a.address == null then
      # both name-only
      if a.name < b.name then
        -1
      else if a.name > b.name then
        1
      else
        0
    else if isV4 a.address && !(isV4 b.address) then
      -1
    else if !(isV4 a.address) && isV4 b.address then
      1
    else
      let
        addrCmp =
          if isV4 a.address then ipv4.compare a.address b.address else ipv6.compare a.address b.address;
      in
      if addrCmp != 0 then
        addrCmp
      else if a.prefix < b.prefix then
        -1
      else if a.prefix > b.prefix then
        1
      else if a.name == null && b.name == null then
        0
      else if a.name == null then
        -1
      else if b.name == null then
        1
      else if a.name < b.name then
        -1
      else if a.name > b.name then
        1
      else
        0;

  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;
in
{
  inherit
    parse
    tryParse
    parseName
    tryParseName
    toString
    make
    makeName
    makeNamed
    fromAddressAndNetwork
    withName
    withAddress
    ;
  inherit
    isValid
    isValidName
    is
    isIpv4
    isIpv6
    hasName
    hasAddress
    ;
  inherit
    name
    address
    prefix
    version
    network
    netmask
    hostmask
    broadcast
    ;
  inherit toCidr toRange;
  inherit
    eq
    lt
    le
    gt
    ge
    compare
    min
    max
    ;
}
