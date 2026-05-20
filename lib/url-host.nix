/*
  libnet.urlHost

  The host component of a URL authority (RFC 3986 §3.2.2) — the `host`
  field of `libnet.url`, and usable standalone. Deliberately distinct
  from `libnet.host`: a URL host is `IP-literal | IPv4address | reg-name`,
  where reg-name is a loose ASCII set (adds `_`, `~`, sub-delims,
  `%`-encoding) with no DNS label structure. Looser and less composable
  than `libnet.host` — an IP host carries a tagged `ip`; a reg-name is an
  opaque string.

  Example:
    libnet.urlHost.parse "[::1]"
    => { _type = "urlHost"; kind = "ip"; ip = <ipv6 ::1>; name = null; }

    libnet.urlHost.parse "my_host"
    => { _type = "urlHost"; kind = "regName"; ip = null; name = "my_host"; }
*/
let
  ip = import ./ip.nix;
  ipv4 = import ./ipv4.nix;
  ipv6 = import ./ipv6.nix;
  dnsName = import ./dns-name.nix;
  parse' = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  types = import ./internal/types.nix;

  # reg-name = *( unreserved / pct-encoded / sub-delims ); we require >= 1.
  regNamePattern = "([-A-Za-z0-9._~!$&'()*+,;=]|%[0-9A-Fa-f][0-9A-Fa-f])+";

  mkIp = v: {
    _type = "urlHost";
    kind = "ip";
    ip = v;
    name = null;
  };
  mkReg = s: {
    _type = "urlHost";
    kind = "regName";
    ip = null;
    name = s;
  };

  # ===== Parsing =====

  tryParse =
    s:
    if !(builtins.isString s) then
      types.tryErr "libnet.urlHost.parse: input must be a string"
    else if s == "" then
      types.tryErr "libnet.urlHost.parse: empty host"
    else if parse'.startsWith "[" s then
      if parse'.endsWith "]" s then
        let
          inner = builtins.substring 1 (builtins.stringLength s - 2) s;
          r = ipv6.tryParse inner;
        in
        if r.success then
          types.tryOk (mkIp r.value)
        else
          types.tryErr "libnet.urlHost.parse: invalid IPv6 literal \"${s}\""
      else
        types.tryErr "libnet.urlHost.parse: unclosed IPv6 literal \"${s}\""
    else
      let
        v4 = ipv4.tryParse s;
      in
      if v4.success then
        types.tryOk (mkIp v4.value)
      else if builtins.match regNamePattern s != null then
        types.tryOk (mkReg s)
      else
        types.tryErr "libnet.urlHost.parse: invalid host \"${s}\"";

  parse =
    s:
    let
      r = tryParse s;
    in
    if r.success then r.value else builtins.throw r.error;

  toString =
    h:
    if h.kind == "ip" then
      (if ip.isIpv6 h.ip then "[${ip.toString h.ip}]" else ip.toString h.ip)
    else
      h.name;

  # ===== Predicates =====

  isValid = s: (tryParse s).success;
  is = types.isUrlHost;
  isIp = h: h.kind == "ip";
  isRegName = h: h.kind == "regName";

  # ===== Conversion =====

  # → libnet.host when it qualifies (an IP, or a reg-name that is also a
  # valid dnsName); null otherwise (e.g. underscore reg-names).
  toHost =
    h:
    if h.kind == "ip" then
      h.ip
    else
      let
        r = dnsName.tryParse h.name;
      in
      if r.success then r.value else null;

  # ===== Comparison =====

  lc = dnsLabel.toLowerAscii;

  eq =
    a: b:
    if a.kind != b.kind then
      false
    else if a.kind == "ip" then
      ip.eq a.ip b.ip
    else
      lc a.name == lc b.name;

  # IP-literals sort before reg-names; within each, by address / by
  # case-folded name.
  compare =
    a: b:
    if a.kind == "ip" && b.kind == "regName" then
      -1
    else if a.kind == "regName" && b.kind == "ip" then
      1
    else if a.kind == "ip" then
      ip.compare a.ip b.ip
    else
      let
        la = lc a.name;
        lb = lc b.name;
      in
      if la < lb then
        -1
      else if la > lb then
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
    toString
    isValid
    is
    isIp
    isRegName
    toHost
    eq
    compare
    lt
    le
    gt
    ge
    min
    max
    regNamePattern
    ;
}
