# Address classification: bogons and global addresses

`isBogon` is the union of named special-purpose classes per family (loopback, private, link-local, documentation and so on). `isGlobal` is exactly `!isBogon` for IPv4. For IPv6 it also excludes IPv4-mapped, IPv4-compatible and 6to4 addresses: those are routable but are not native global unicast, so they are not bogons and not global either.

`registry.bogons` lists the same space as CIDR literals for iteration and display, decomposed differently from the predicate. `tests/registry.nix` checks that the first and last address of every registry entry satisfies `isBogon`, so adding a bogon means updating both the registry and the predicate.
