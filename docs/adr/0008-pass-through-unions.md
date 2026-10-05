# Unions return the member's value and add no tag

`ip`, `dnsName`, `host`, `endpoint` and `bindpoint` accept any of their members and return the member's own tagged value, not a wrapper. A literal address parsed through `host` is a full `ipv4` or `ipv6` value with all of its predicates, and callers branch on `_type` or the union's `is*` predicates.

Dispatch tries IP forms first: a dotted quad is also a valid four-label domain, and callers almost always mean the address. Unions over heterogeneous members (`endpoint`, `bindpoint`) expose only parsing, predicates, `toString` and comparison; member-specific accessors stay in the member namespace.
