/*
  Internal: URL authority host (RFC 3986 §3.2.2).

  The host component of a URL — deliberately NOT libnet.host. A URL host
  is `IP-literal | IPv4address | reg-name`, where reg-name is a loose
  ASCII set (adds `_`, `~`, sub-delims, %-encoding) with no DNS label
  structure. Used only by libnet.url; not part of the public attrset.

  Value: { _type = "urlHost"; kind = "ip" | "regName";
           ip = <ip | null>; name = <string | null>; }
*/
let
  ip = import ../ip.nix;
  ipv4 = import ../ipv4.nix;
  ipv6 = import ../ipv6.nix;
  dnsName = import ../dns-name.nix;
  parse' = import ./parse.nix;
  dnsLabel = import ./dns-label.nix;

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

  # Returns a urlHost value, or null on failure.
  tryParse =
    s:
    if !(builtins.isString s) || s == "" then
      null
    else if parse'.startsWith "[" s then
      if parse'.endsWith "]" s then
        let
          inner = builtins.substring 1 (builtins.stringLength s - 2) s;
          r = ipv6.tryParse inner;
        in
        if r.success then mkIp r.value else null
      else
        null
    else
      let
        v4 = ipv4.tryParse s;
      in
      if v4.success then
        mkIp v4.value
      else if builtins.match regNamePattern s != null then
        mkReg s
      else
        null;

  toString =
    h:
    if h.kind == "ip" then
      (if ip.isIpv6 h.ip then "[${ip.toString h.ip}]" else ip.toString h.ip)
    else
      h.name;

  isValid = s: tryParse s != null;
  is = v: builtins.isAttrs v && v ? _type && v._type == "urlHost";
  isIp = h: h.kind == "ip";
  isRegName = h: h.kind == "regName";

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
in
{
  inherit
    tryParse
    toString
    isValid
    is
    isIp
    isRegName
    toHost
    eq
    compare
    regNamePattern
    ;
}
