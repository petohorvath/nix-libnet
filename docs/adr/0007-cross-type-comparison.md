# Lenient comparison across families and kinds

Comparison follows one rule set everywhere, so mixed inputs behave predictably:

- `eq` returns `false` for values of different kinds or families, and for operands that are not tagged values (`{ }`, `null`, `1`). It never throws. A malformed tagged value such as `{ _type = "cidr"; }` gives undefined results.
- Ordering (`lt`, `compare`, `min` and the rest) sorts IPv4 before IPv6, so `sort` works on mixed-family lists without partitioning. Union namespaces define a fixed order between their members.
- Containment and overlap predicates return `false` across families.
- Arithmetic throws on overflow, and `ip.diff` across families throws.

A strict variant (`compareStrict`) was rejected. Callers who need strictness check `version` first.

## Argument kinds

Leniency stops at `eq`. Every other function checks the kind of each argument, a tagged value's `_type` or a raw value's builtin type, and throws `libnet.<ns>.<fn>: expected <kind>, got <kind>` on a mismatch, so a mistake surfaces at the call site instead of as a quiet `false` or a malformed value. `port.add 1.5 p` throws rather than storing a float, and `port.toString 80` throws a libnet error rather than a raw Nix one. The message describes the bad value by its tag or builtin type, never by coercing it to a string, so a set or function argument cannot cause a coercion error.

- Only `is`, the union `is<Member>` predicates, `eq`, `isValid` and `tryParse` accept any value, so they can serve as guards; they return `false` or a failed result and never throw.
- A single-kind namespace accepts only its own kind, and a union any of its members. Ordering across unrelated kinds, such as a port against an address, therefore throws.
- A relation still returns `false` for an address or block of the other family, because both arguments are of a kind the function accepts.
- The check reads only the tag. A value with the right `_type` and malformed fields gives undefined results.
