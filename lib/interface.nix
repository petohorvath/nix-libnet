let
  parse' = import ./internal/parse.nix;
  types  = import ./internal/types.nix;
  ipv4   = import ./ipv4.nix;
  ipv6   = import ./ipv6.nix;
  cidr   = import ./cidr.nix;
  range  = import ./range.nix;

  mk = addr: prefix: { _type = "interface"; address = addr; inherit prefix; };

  isV4 = addr: addr._type == "ipv4";

  maxPrefix = addr: if isV4 addr then 32 else 128;

  # ===== Parsing =====

  tryParse = s:
    if !(builtins.isString s)
    then types.tryErr "libnet.interface.parse: input must be a string"
    else
      let parts = parse'.splitOn "/" s; in
        if builtins.length parts != 2
        then types.tryErr "libnet.interface.parse: missing '/': \"${s}\""
        else
          let
            addrStr = builtins.elemAt parts 0;
            prefStr = builtins.elemAt parts 1;
            isV6Str = parse'.countOccurrences ":" addrStr > 0;
            addrRes = if isV6Str then ipv6.tryParse addrStr else ipv4.tryParse addrStr;
            prefInt = parse'.decimal prefStr;
          in
            if !addrRes.success
            then types.tryErr "libnet.interface.parse: ${addrRes.error}"
            else if prefInt == null
            then types.tryErr "libnet.interface.parse: invalid prefix \"${prefStr}\""
            else if prefInt > maxPrefix addrRes.value
            then types.tryErr "libnet.interface.parse: prefix /${prefStr} out of range"
            else types.tryOk (mk addrRes.value prefInt);

  parse = s:
    let r = tryParse s;
    in if r.success then r.value else builtins.throw r.error;

  toString = i:
    let s = if isV4 i.address then ipv4.toString i.address else ipv6.toString i.address;
    in "${s}/${builtins.toString i.prefix}";

  make = addr: prefix:
    if !(types.isIp addr)
    then builtins.throw "libnet.interface.make: address must be ipv4 or ipv6"
    else if !(builtins.isInt prefix) || prefix < 0 || prefix > maxPrefix addr
    then builtins.throw "libnet.interface.make: prefix out of range"
    else mk addr prefix;

  fromAddressAndNetwork = addr: net:
    if !(types.isIp addr)
    then builtins.throw "libnet.interface.fromAddressAndNetwork: address must be ipv4 or ipv6"
    else if !(types.isCidr net)
    then builtins.throw "libnet.interface.fromAddressAndNetwork: expected cidr as network"
    else if addr._type != net.address._type
    then builtins.throw "libnet.interface.fromAddressAndNetwork: family mismatch"
    else if !(cidr.containsAddress net addr)
    then builtins.throw "libnet.interface.fromAddressAndNetwork: address not in network"
    else mk addr net.prefix;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isInterface;
  isIpv4 = i: isV4 i.address;
  isIpv6 = i: !(isV4 i.address);

  # ===== Accessors =====

  address = i: i.address;
  prefix  = i: i.prefix;
  version = i: if isV4 i.address then 4 else 6;

  network = i:
    # Derive the canonical cidr by zeroing host bits.
    cidr.canonical (cidr.make i.address i.prefix);

  netmask  = i: cidr.netmask  (cidr.make i.address i.prefix);
  hostmask = i: cidr.hostmask (cidr.make i.address i.prefix);

  broadcast = i:
    if !(isV4 i.address)
    then builtins.throw "libnet.interface.broadcast: IPv6 has no broadcast"
    else cidr.broadcast (cidr.make i.address i.prefix);

  # ===== Conversions =====

  toCidr = i: network i;

  toRange = i: range.fromCidr (network i);

  # ===== Comparison =====

  eq = a: b:
    a.address._type == b.address._type
    && a.prefix == b.prefix
    && (if isV4 a.address then a.address.value == b.address.value
        else a.address.words == b.address.words);

  compare = a: b:
    if isV4 a.address && !(isV4 b.address) then -1
    else if !(isV4 a.address) && isV4 b.address then 1
    else
      let
        addrCmp = if isV4 a.address
                  then ipv4.compare a.address b.address
                  else ipv6.compare a.address b.address;
      in
        if addrCmp != 0 then addrCmp
        else if a.prefix < b.prefix then -1
        else if a.prefix > b.prefix then 1
        else 0;

  lt = a: b: compare a b == -1;
  le = a: b: compare a b <= 0;
  gt = a: b: compare a b == 1;
  ge = a: b: compare a b >= 0;
  min = a: b: if le a b then a else b;
  max = a: b: if ge a b then a else b;
in
{
  inherit parse tryParse toString make fromAddressAndNetwork;
  inherit isValid is isIpv4 isIpv6;
  inherit address prefix version network netmask hostmask broadcast;
  inherit toCidr toRange;
  inherit eq lt le gt ge compare min max;
}
