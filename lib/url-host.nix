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
  parsing = import ./internal/parse.nix;
  dnsLabel = import ./internal/dns-label.nix;
  types = import ./internal/types.nix;

  lowerAscii = dnsLabel.toLowerAscii;

  # reg-name = *( unreserved / pct-encoded / sub-delims ); we require >= 1.
  regNamePattern = "([-A-Za-z0-9._~!$&'()*+,;=]|%[0-9A-Fa-f][0-9A-Fa-f])+";

  mkIp = address: {
    _type = "urlHost";
    kind = "ip";
    ip = address;
    name = null;
  };
  mkRegName = name: {
    _type = "urlHost";
    kind = "regName";
    ip = null;
    inherit name;
  };

  # ===== Parsing =====

  /*
    Parse a URL host without throwing, for callers that branch on validity.

    `input`: a bracketed IPv6 literal (`[::1]`), dotted IPv4, or a non-empty
    reg-name (unreserved, sub-delims, and `%XX` escapes).

    Returns a tryResult: `{ success = true; value = <urlHost>; }` or
    `{ success = false; error = <string>; }`. Never throws.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.urlHost.parse: input must be a string"
    else if input == "" then
      types.tryErr "libnet.urlHost.parse: empty host"
    else if parsing.startsWith "[" input then
      if parsing.endsWith "]" input then
        let
          inner = builtins.substring 1 (builtins.stringLength input - 2) input;
          result = ipv6.tryParse inner;
        in
        if result.success then
          types.tryOk (mkIp result.value)
        else
          types.tryErr "libnet.urlHost.parse: invalid IPv6 literal \"${input}\""
      else
        types.tryErr "libnet.urlHost.parse: unclosed IPv6 literal \"${input}\""
    else
      let
        ipv4Result = ipv4.tryParse input;
      in
      if ipv4Result.success then
        types.tryOk (mkIp ipv4Result.value)
      else if builtins.match regNamePattern input != null then
        types.tryOk (mkRegName input)
      else
        types.tryErr "libnet.urlHost.parse: invalid host \"${input}\"";

  /*
    Parse a URL host, for values that must be valid.

    `input`: host text as accepted by `tryParse`.

    Returns a urlHost value; throws on invalid input.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a URL host as it appears in a URL authority.

    `urlHost`: a urlHost value.

    Returns the host text: IPv6 addresses re-bracketed, reg-names verbatim
    (case preserved).
  */
  toString =
    urlHost:
    if urlHost.kind == "ip" then
      (if ip.isIpv6 urlHost.ip then "[${ip.toString urlHost.ip}]" else ip.toString urlHost.ip)
    else
      urlHost.name;

  # ===== Predicates =====

  /*
    Check whether a string parses as a URL host.

    `input`: candidate host text.

    Returns true when `tryParse` succeeds.
  */
  isValid = input: (tryParse input).success;

  /*
    Check whether a value is a urlHost value.

    `value`: any value.

    Returns true for a urlHost-tagged attrset.
  */
  is = value: types.isUrlHost value;

  /*
    Check whether a URL host is an IP address (IPv4 or bracketed IPv6).

    `urlHost`: a urlHost value.

    Returns true for the `ip` kind.
  */
  isIp = urlHost: urlHost.kind == "ip";

  /*
    Check whether a URL host is a reg-name rather than an IP address.

    `urlHost`: a urlHost value.

    Returns true for the `regName` kind.
  */
  isRegName = urlHost: urlHost.kind == "regName";

  # ===== Conversion =====

  /*
    Convert a URL host to a `libnet.host`, bridging the looser URL grammar
    to the composable host types.

    `urlHost`: a urlHost value.

    Returns the IP value, or the `dnsName` value when the reg-name is a valid
    DNS name; null otherwise (for example, names containing underscores).
  */
  toHost =
    urlHost:
    if urlHost.kind == "ip" then
      urlHost.ip
    else
      let
        result = dnsName.tryParse urlHost.name;
      in
      if result.success then result.value else null;

  # ===== Comparison =====

  /*
    Test two URL hosts for equality.

    `a`, `b`: urlHost values.

    Returns true when both have the same kind and equal IPs, or reg-names
    that match case-insensitively. Never throws on mismatched types.
  */
  eq =
    a: b:
    if !types.hasSameTag a b || a.kind != b.kind then
      false
    else if a.kind == "ip" then
      ip.eq a.ip b.ip
    else
      lowerAscii a.name == lowerAscii b.name;

  /*
    Order two URL hosts: IP literals before reg-names, IPs by address, and
    reg-names by case-folded name.

    `a`, `b`: urlHost values.

    Returns -1, 0, or 1.
  */
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
        nameA = lowerAscii a.name;
        nameB = lowerAscii b.name;
      in
      if nameA < nameB then
        -1
      else if nameA > nameB then
        1
      else
        0;

  /*
    Check whether one URL host sorts before another.

    `a`, `b`: urlHost values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Check whether one URL host sorts before or equal to another.

    `a`, `b`: urlHost values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Check whether one URL host sorts after another.

    `a`, `b`: urlHost values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Check whether one URL host sorts after or equal to another.

    `a`, `b`: urlHost values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the lesser of two URL hosts by `compare`.

    `a`, `b`: urlHost values.

    Returns `a` when it sorts first or equal, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the greater of two URL hosts by `compare`.

    `a`, `b`: urlHost values.

    Returns `a` when it sorts last or equal, otherwise `b`.
  */
  max = a: b: if ge a b then a else b;
in
{
  inherit
    compare
    eq
    ge
    gt
    is
    isIp
    isRegName
    isValid
    le
    lt
    max
    min
    parse
    regNamePattern
    toHost
    toString
    tryParse
    ;
}
