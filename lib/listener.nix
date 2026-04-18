let
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  port = import ./port.nix;
  portRange = import ./portRange.nix;
  endpoint = import ./endpoint.nix;

  mk = addr: pr: {
    _type = "listener";
    address = addr;
    portRange = pr;
  };

  isV4 = addr: addr._type == "ipv4";
  isV6 = addr: addr._type == "ipv6";

  # ===== Port-field parser (hyphen form only; iptables colon form would
  #       collide with addr:port separator) =====

  parsePortField =
    s:
    let
      parts = parse'.splitOn "-" s;
    in
    if builtins.length parts == 1 then
      let
        n = parse'.decimal s;
      in
      if n == null || n < 0 || n > 65535 then null else portRange.make n n
    else if builtins.length parts == 2 then
      let
        f = parse'.decimal (builtins.elemAt parts 0);
        t = parse'.decimal (builtins.elemAt parts 1);
      in
      if f == null || t == null then
        null
      else if f < 0 || t > 65535 || f > t then
        null
      else
        portRange.make f t
    else
      null;

  # ===== Parsing =====

  tryParseNullAddr =
    portStr:
    let
      prOpt = parsePortField portStr;
    in
    if prOpt == null then
      types.tryErr "libnet.listener.parse: invalid port field \"${portStr}\""
    else
      types.tryOk (mk null prOpt);

  tryParseBracketed =
    s:
    let
      parts = parse'.splitOn "]:" s;
    in
    if builtins.length parts != 2 then
      types.tryErr "libnet.listener.parse: malformed bracketed form \"${s}\""
    else
      let
        left = builtins.elemAt parts 0;
        portStr = builtins.elemAt parts 1;
        hasOpenBracket = builtins.stringLength left >= 1 && builtins.substring 0 1 left == "[";
        addrStr =
          if hasOpenBracket then builtins.substring 1 (builtins.stringLength left - 1) left else null;
      in
      if addrStr == null then
        types.tryErr "libnet.listener.parse: missing '[' in \"${s}\""
      else
        let
          addrRes = ipv6.tryParse addrStr;
          prOpt = parsePortField portStr;
        in
        if !addrRes.success then
          types.tryErr "libnet.listener.parse: invalid IPv6 in \"${s}\""
        else if prOpt == null then
          types.tryErr "libnet.listener.parse: invalid port field in \"${s}\""
        else
          types.tryOk (mk addrRes.value prOpt);

  tryParseV4Form =
    s:
    if parse'.countOccurrences ":" s != 1 then
      types.tryErr "libnet.listener.parse: unbracketed IPv6 is ambiguous, use [addr]:port: \"${s}\""
    else
      let
        parts = parse'.splitOn ":" s;
        addrStr = builtins.elemAt parts 0;
        portStr = builtins.elemAt parts 1;
        addrRes = ipv4.tryParse addrStr;
        prOpt = parsePortField portStr;
      in
      if !addrRes.success then
        types.tryErr "libnet.listener.parse: invalid IPv4 in \"${s}\""
      else if prOpt == null then
        types.tryErr "libnet.listener.parse: invalid port field in \"${s}\""
      else
        types.tryOk (mk addrRes.value prOpt);

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.listener.parse: input must be a string"
    else if parse'.startsWith "*:" s then
      tryParseNullAddr (parse'.stripPrefix "*:" s)
    else if parse'.startsWith "any:" s then
      tryParseNullAddr (parse'.stripPrefix "any:" s)
    else if parse'.startsWith ":" s then
      tryParseNullAddr (parse'.stripPrefix ":" s)
    else if parse'.startsWith "[" s then
      tryParseBracketed s
    else
      tryParseV4Form s;

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    lst:
    let
      prStr = portRange.toString lst.portRange;
    in
    if lst.address == null then
      ":${prStr}"
    else if isV4 lst.address then
      "${ipv4.toString lst.address}:${prStr}"
    else
      "[${ipv6.toString lst.address}]:${prStr}";

  make =
    addr: pr:
    if addr != null && !(types.isIp addr) then
      builtins.throw "libnet.listener.make: address must be ipv4, ipv6, or null"
    else if !(types.isPortRange pr) then
      builtins.throw "libnet.listener.make: expected portRange value"
    else
      mk addr pr;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isListener;

  isAnyAddress =
    lst:
    lst.address == null
    || (isV4 lst.address && lst.address.value == 0)
    || (
      isV6 lst.address
      &&
        lst.address.words == [
          0
          0
          0
          0
        ]
    );

  isWildcard = isAnyAddress;

  isRange = lst: !(portRange.isSingleton lst.portRange);

  isIpv4 = lst: lst.address != null && isV4 lst.address;
  isIpv6 = lst: lst.address != null && isV6 lst.address;

  # ===== Accessors =====

  address = lst: lst.address;
  portRange' = lst: lst.portRange;
  version =
    lst:
    if lst.address == null then
      null
    else if isV4 lst.address then
      4
    else
      6;

  # ===== Expansion =====

  toEndpointsUnbounded =
    lst:
    if lst.address == null then
      builtins.throw "libnet.listener.toEndpoints: null address cannot be materialized into endpoints"
    else
      let
        ports = portRange.portsUnbounded lst.portRange;
      in
      map (pt: endpoint.make lst.address pt) ports;

  toEndpoints =
    lst:
    let
      sz = portRange.size lst.portRange;
    in
    if sz > 4096 then
      builtins.throw "libnet.listener.toEndpoints: range too large (${builtins.toString sz} > 4096); use toEndpointsUnbounded"
    else
      toEndpointsUnbounded lst;

  endpointAt =
    n: lst:
    if lst.address == null then
      builtins.throw "libnet.listener.endpoint: null address cannot be materialized"
    else
      let
        sz = portRange.size lst.portRange;
        idx = if n < 0 then sz + n else n;
      in
      if idx < 0 || idx >= sz then
        builtins.throw "libnet.listener.endpoint: index out of range [0, ${builtins.toString sz})"
      else
        let
          pt = port.fromInt (lst.portRange.from + idx);
        in
        endpoint.make lst.address pt;

  # ===== Comparison =====

  eq =
    a: b:
    (
      a.address == null && b.address == null
      || (
        a.address != null
        && b.address != null
        && a.address._type == b.address._type
        && (if isV4 a.address then ipv4.eq a.address b.address else ipv6.eq a.address b.address)
      )
    )
    && portRange.eq a.portRange b.portRange;

  compare =
    a: b:
    if a.address == null && b.address != null then
      -1
    else if a.address != null && b.address == null then
      1
    else if
      a.address == null # both null
    then
      portRange.compare a.portRange b.portRange
    else if isV4 a.address && isV6 b.address then
      -1
    else if isV6 a.address && isV4 b.address then
      1
    else
      let
        addrCmp =
          if isV4 a.address then ipv4.compare a.address b.address else ipv6.compare a.address b.address;
      in
      if addrCmp != 0 then addrCmp else portRange.compare a.portRange b.portRange;

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
    toString
    make
    ;
  inherit
    isValid
    is
    isAnyAddress
    isWildcard
    isRange
    isIpv4
    isIpv6
    ;
  inherit address version;
  portRange = portRange';
  inherit toEndpoints toEndpointsUnbounded;
  endpoint = endpointAt;
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
