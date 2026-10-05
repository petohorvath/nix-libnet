# Lenient comparison across families and kinds

Comparison follows one rule set everywhere, so mixed inputs behave predictably:

- `eq` returns `false` for values of different kinds or families, and for operands that are not tagged values (`{ }`, `null`, `1`). It never throws. A malformed tagged value such as `{ _type = "cidr"; }` gives undefined results.
- Ordering (`lt`, `compare`, `min` and the rest) sorts IPv4 before IPv6, so `sort` works on mixed-family lists without partitioning. Union namespaces define a fixed order between their members. Ordering across unrelated kinds, such as a port against an address, is undefined.
- Containment and overlap predicates return `false` across families.
- Arithmetic throws on overflow, and `ip.diff` across families throws.

A strict variant (`compareStrict`) was rejected. Callers who need strictness check `version` first.
