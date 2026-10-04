/*
  libnet.dnsName

  Pass-through union over Hostname and Domain — a DNS name that is not
  an IP literal. This is the "name" half of `host` (host = ip |
  dnsName). `parse` dispatches by label count: a single label parses
  as a hostname, multiple labels as a domain. IP literals are rejected
  (use `libnet.ip` for those) — that is what distinguishes a dnsName
  from a bare `domain`, which accepts all-numeric dotted forms.

  No new `_type` tag: the result is the underlying hostname or domain
  value; consumers branch on `value._type`. Same pattern as
  `libnet.ip` and `libnet.host`.

  Example:
    libnet.dnsName.parse "nas"            # tagged hostname
    libnet.dnsName.parse "pool.ntp.org"   # tagged domain
    libnet.dnsName.parse "192.0.2.1"      # throws — that's an IP
*/
let
  types = import ./internal/types.nix;
  ip = import ./ip.nix;
  hostname = import ./hostname.nix;
  domain = import ./domain.nix;

  # ===== Parsing =====

  /*
    Parse a DNS name without throwing, for callers that branch on
    validity or report the error themselves.

    `input`: candidate hostname or domain string.

    Returns a tryResult `{ success, value, error }` holding the
    hostname or domain value on success, or an error message for IP
    literals and invalid names.
  */
  tryParse =
    input:
    if !(builtins.isString input) then
      types.tryErr "libnet.dnsName.parse: input must be a string"
    else if ip.isValid input then
      types.tryErr "libnet.dnsName.parse: \"${input}\" is an IP address, not a DNS name"
    else
      let
        hostnameResult = hostname.tryParse input;
      in
      if hostnameResult.success then
        hostnameResult
      else
        let
          domainResult = domain.tryParse input;
        in
        if domainResult.success then
          domainResult
        else
          types.tryErr "libnet.dnsName.parse: \"${input}\" is not a valid hostname or domain";

  /*
    Parse a DNS name that is not an IP literal.

    `input`: single-label hostname or multi-label domain string.

    Returns a hostname value for one label or a domain value for
    several; throws on IP literals and invalid names.
  */
  parse =
    input:
    let
      result = tryParse input;
    in
    if result.success then result.value else throw result.error;

  /*
    Render a DNS name as a string.

    `name`: hostname or domain value.

    Returns the name exactly as parsed, preserving case; throws for
    any other value.
  */
  toString =
    name:
    if types.isHostname name then
      hostname.toString name
    else if types.isDomain name then
      domain.toString name
    else
      throw "libnet.dnsName.toString: expected hostname or domain value";

  # ===== Predicates =====

  /*
    Check whether a value parses as a DNS name.

    `input`: any value; non-strings are invalid.

    Returns true when `parse` would succeed.
  */
  isValid = input: (tryParse input).success;

  /*
    Recognize a tagged DNS name value.

    `value`: any value.

    Returns true when `value` carries the `hostname` or `domain` tag.
  */
  is = value: types.isHostname value || types.isDomain value;

  /*
    Recognize a tagged hostname value.

    `value`: any value.

    Returns true when `value` carries the `hostname` tag.
  */
  isHostname = value: types.isHostname value;

  /*
    Recognize a tagged domain value.

    `value`: any value.

    Returns true when `value` carries the `domain` tag.
  */
  isDomain = value: types.isDomain value;

  # ===== Normalization =====

  /*
    Lowercase a DNS name so equal names share one spelling.

    `name`: hostname or domain value.

    Returns a value of the same type with an ASCII-lowercased `value`;
    throws for any other value.
  */
  normalize =
    name:
    if types.isHostname name then
      hostname.normalize name
    else if types.isDomain name then
      domain.normalize name
    else
      throw "libnet.dnsName.normalize: expected hostname or domain value";

  # ===== Comparison =====
  #
  # Cross-family order: hostname (single label) sorts before domain
  # (multi label). Within a family, dispatches to that family's own
  # case-insensitive comparison.

  familyRank =
    value:
    if types.isHostname value then
      0
    else if types.isDomain value then
      1
    else
      throw "libnet.dnsName.compare: expected hostname or domain value";

  /*
    Test two DNS names for equality, ignoring case.

    `a`, `b`: values to compare.

    Returns true when both are hostnames or both are domains and they
    match case-insensitively; false otherwise, without throwing.
  */
  eq =
    a: b:
    if types.isHostname a && types.isHostname b then
      hostname.eq a b
    else if types.isDomain a && types.isDomain b then
      domain.eq a b
    else
      false;

  /*
    Order two DNS names for sorting: hostnames before domains, then
    case-insensitively within a family.

    `a`, `b`: hostname or domain values.

    Returns -1, 0, or 1 as `a` sorts before, equal to, or after `b`;
    throws when either is not a hostname or domain.
  */
  compare =
    a: b:
    let
      rankA = familyRank a;
      rankB = familyRank b;
    in
    if rankA < rankB then
      -1
    else if rankA > rankB then
      1
    else if rankA == 0 then
      hostname.compare a b
    else
      domain.compare a b;

  /*
    Test whether one DNS name sorts strictly before another.

    `a`, `b`: hostname or domain values.

    Returns true when `compare a b` is -1.
  */
  lt = a: b: compare a b == -1;

  /*
    Test whether one DNS name sorts before or equal to another.

    `a`, `b`: hostname or domain values.

    Returns true when `compare a b` is -1 or 0.
  */
  le = a: b: compare a b <= 0;

  /*
    Test whether one DNS name sorts strictly after another.

    `a`, `b`: hostname or domain values.

    Returns true when `compare a b` is 1.
  */
  gt = a: b: compare a b == 1;

  /*
    Test whether one DNS name sorts after or equal to another.

    `a`, `b`: hostname or domain values.

    Returns true when `compare a b` is 1 or 0.
  */
  ge = a: b: compare a b >= 0;

  /*
    Pick the DNS name that sorts first.

    `a`, `b`: hostname or domain values.

    Returns `a` when `le a b`, otherwise `b`.
  */
  min = a: b: if le a b then a else b;

  /*
    Pick the DNS name that sorts last.

    `a`, `b`: hostname or domain values.

    Returns `a` when `ge a b`, otherwise `b`.
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
    isDomain
    isHostname
    isValid
    le
    lt
    max
    min
    normalize
    parse
    toString
    tryParse
    ;
}
