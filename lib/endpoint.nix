/*
  libnet.endpoint

  An IP address paired with a port. Parses the v4 dotted form
  ("host:port") and the v6 bracketed form ("[host]:port").

  Example:
    libnet.endpoint.parse "192.0.2.1:8080"
    => { _type = "endpoint"; address = <ipv4>; port = <port 8080>; }

    libnet.endpoint.toString (libnet.endpoint.parse "[2001:db8::1]:80")
    => "[2001:db8::1]:80"
*/
let
  parse' = import ./internal/parse.nix;
  types = import ./internal/types.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  port = import ./port.nix;

  mk = addr: pt: {
    _type = "endpoint";
    address = addr;
    port = pt;
  };

  # ===== Parsing =====

  # Bracketed form: [<ipv6>]:<port>
  tryParseBracketed =
    s:
    let
      parts = parse'.splitOn "]:" s;
    in
    if builtins.length parts != 2 then
      types.tryErr "libnet.endpoint.parse: malformed bracketed form \"${s}\""
    else
      let
        left = builtins.elemAt parts 0;
        portStr = builtins.elemAt parts 1;
        hasOpenBracket = builtins.stringLength left >= 1 && builtins.substring 0 1 left == "[";
        addrStr =
          if hasOpenBracket then builtins.substring 1 (builtins.stringLength left - 1) left else null;
      in
      if addrStr == null then
        types.tryErr "libnet.endpoint.parse: missing '[' in \"${s}\""
      else
        let
          addrRes = ipv6.tryParse addrStr;
          portRes = port.tryParse portStr;
        in
        if !addrRes.success then
          types.tryErr "libnet.endpoint.parse: invalid IPv6 in \"${s}\""
        else if !portRes.success then
          types.tryErr "libnet.endpoint.parse: invalid port in \"${s}\""
        else
          types.tryOk (mk addrRes.value portRes.value);

  # Unbracketed form: <ipv4>:<port>. Exactly one ':'.
  tryParseV4Form =
    s:
    if parse'.countOccurrences ":" s != 1 then
      types.tryErr "libnet.endpoint.parse: unbracketed IPv6 is ambiguous, use [addr]:port: \"${s}\""
    else
      let
        parts = parse'.splitOn ":" s;
        addrStr = builtins.elemAt parts 0;
        portStr = builtins.elemAt parts 1;
        addrRes = ipv4.tryParse addrStr;
        portRes = port.tryParse portStr;
      in
      if !addrRes.success then
        types.tryErr "libnet.endpoint.parse: invalid IPv4 in \"${s}\""
      else if !portRes.success then
        types.tryErr "libnet.endpoint.parse: invalid port in \"${s}\""
      else
        types.tryOk (mk addrRes.value portRes.value);

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.endpoint.parse: input must be a string"
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
    ep:
    let
      portStr = port.toString ep.port;
    in
    if types.isIpv4 ep.address then
      "${ipv4.toString ep.address}:${portStr}"
    else
      "[${ipv6.toString ep.address}]:${portStr}";

  toUri = toString;

  make =
    addr: pt:
    if !(types.isIp addr) then
      builtins.throw "libnet.endpoint.make: address must be ipv4 or ipv6"
    else if !(types.isPort pt) then
      builtins.throw "libnet.endpoint.make: expected port value"
    else
      mk addr pt;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isEndpoint;
  isIpv4 = ep: types.isIpv4 ep.address;
  isIpv6 = ep: types.isIpv6 ep.address;

  # ===== Accessors =====

  address = ep: ep.address;
  port_ = ep: ep.port;
  version = ep: if types.isIpv4 ep.address then 4 else 6;

  # ===== Forwarded predicates (apply to address) =====

  fwd =
    v4Fn: v6Fn: ep:
    if types.isIpv4 ep.address then v4Fn ep.address else v6Fn ep.address;

  isLoopback = fwd ipv4.isLoopback ipv6.isLoopback;
  isUnspecified = fwd ipv4.isUnspecified ipv6.isUnspecified;
  isLinkLocal = fwd ipv4.isLinkLocal ipv6.isLinkLocal;
  isMulticast = fwd ipv4.isMulticast ipv6.isMulticast;
  isDocumentation = fwd ipv4.isDocumentation ipv6.isDocumentation;
  isGlobal = fwd ipv4.isGlobal ipv6.isGlobal;
  isBogon = fwd ipv4.isBogon ipv6.isBogon;
  toArpa = fwd ipv4.toArpa ipv6.toArpa;

  # ===== Comparison =====

  eq =
    a: b:
    a.address._type == b.address._type
    && (if types.isIpv4 a.address then ipv4.eq a.address b.address else ipv6.eq a.address b.address)
    && port.eq a.port b.port;

  compare =
    a: b:
    if types.isIpv4 a.address && types.isIpv6 b.address then
      -1
    else if types.isIpv6 a.address && types.isIpv4 b.address then
      1
    else
      let
        addrCmp =
          if types.isIpv4 a.address then
            ipv4.compare a.address b.address
          else
            ipv6.compare a.address b.address;
      in
      if addrCmp != 0 then addrCmp else port.compare a.port b.port;

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
    toUri
    make
    ;
  inherit
    isValid
    is
    isIpv4
    isIpv6
    ;
  inherit address version;
  port = port_;
  inherit
    isLoopback
    isUnspecified
    isLinkLocal
    isMulticast
    isDocumentation
    isGlobal
    isBogon
    toArpa
    ;
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
