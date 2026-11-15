# Module types merge to canonical values

Every libnet module type merges to its canonical value. A string type merges to the canonical text of its namespace, `toString (parse value)`, and a bounded integer type merges to its integer, as before. This follows from [ADR 0013](0013-strict-input-canonical-output.md): input may take any accepted spelling, output takes one. It supersedes [ADR 0016](0016-module-types-keep-strings.md), under which string types merged to the definition as written and the bounded integers were the exception.

Merging compares the canonical text of every definition, so two spellings of one value from different modules, such as `02-00-00-00-00-0A` and `02:00:00:00:00:0a`, merge instead of conflicting, and consumers can compare option values as strings, such as to find two NICs with one MAC address. Two different values still conflict, and the error shows each definition as written. `mk` returns the canonical text, as the integer types' `mk` returns an integer, so a `default` reads as the option merges. `check`, type names, descriptions and declaration merging are unchanged.

Canonical text is libnet's form, not any other program's syntax. A consumer that writes an option value into another program's configuration formats it from `parse`, since `*:80` merges to `:80` and `ssl://h:443` to `tls://h:443`.

## Consequences

- Option values are respelled: `MyHost` merges to `myhost` ([ADR 0020](0020-case-folded-at-parse.md)), IPv6 to RFC 5952 text, MAC addresses to lowercase colon-separated text, `80:90` to `80-90`, `*:80` and `any:80` to `:80`, and `http://proxy:3128/` to `http://proxy:3128`. Types whose canonical text is the input, such as `interfaceName` and `unixSocket`, merge as before.
- A consumer's `apply` or wrapper type that calls `toString (parse value)` is redundant. A consumer that needs the user's spelling declares `lib.types.addCheck lib.types.str libnet.<namespace>.isValid`.
- An option value's canonical text follows from its type, so every declaration of a field agrees on it, where an `apply` holds for one declaration only.

## Considered options

- **A canonical type beside each string type**, such as `types.canonical.mac`. It doubles the types and their tests, needs a rule for how a plain and a canonical declaration of one option interact, and leaves the default type as the one that causes the comparison bug.
- **Merge to tagged values.** Tagged values have no `__toString`, so `"${cfg.mac}"` would fail, unlike the string values that NixOS options usually hold. Adding `__toString` would change the value shape of [ADR 0004](0004-tagged-values.md) and put a function in values that `==` compares.
