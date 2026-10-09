# API reference

This reference is the contract for libnet's public API: the value each namespace produces, its canonical text, and the behavior of every function. Terms follow [`GLOSSARY.md`](../../GLOSSARY.md); the reasons behind the design are in [`docs/adr/`](../adr/).

| Area | Namespaces |
| --- | --- |
| [Addresses](addresses.md) | `ipv4`, `ipv6`, `ip`, `mac` |
| [Networks](networks.md) | `cidr`, `ipRange`, `interfaceAddress` |
| [Ports and transports](ports.md) | `port`, `portRange`, `transport` |
| [Names](names.md) | `hostname`, `domain`, `dnsName`, `host`, `interfaceName` |
| [Targets](targets.md) | `ipEndpoint`, `dnsEndpoint`, `unixSocket`, `endpoint`, `ipBindpoint`, `bindpoint` |
| [URL forms](urls.md) | `socketUrl`, `bindUrl`, `secureSocketUrl`, `urlHost`, `authority`, `url`, `proxyUrl` |
| [Bounded integers](bounded-integers.md) | `vlanId`, `mtu`, `icmpType` |
| [Registry](registry.md) | `registry` |
| [Module types](module-types.md) | `withLib`, `types` |

Signatures are Haskell-style reading aids; Nix is dynamically typed. `lib/internal/` is not reachable through `libnet` and is not part of the contract.

## Standard suites

Each namespace page lists which suites it provides and documents only what differs from them or adds to them.

**Parsing**, for a kind `T`:

| Function | Signature | Behavior |
| --- | --- | --- |
| `parse` | `String → T` | Throws on invalid input. |
| `tryParse` | `String → TryResult T` | Never throws. |
| `toString` | `T → String` | Canonical text. |
| `isValid` | `String → Bool` | `(tryParse s).success`. |
| `is` | `Any → Bool` | Whether the argument is a `T` value. A string is never a value: `ipv4.is "10.0.0.1"` is `false`. |

`TryResult T` is `{ success = Bool; value = T or null; error = String or null; }`, with `error` set only on failure.

**Comparison**: `eq`, `lt`, `le`, `gt`, `ge` of type `T → T → Bool`; `compare :: T → T → Int` returning `-1`, `0` or `1`; and `min`, `max` of type `T → T → T`. Across kinds and families, `eq` is `false` and never throws, and ordering puts IPv4 before IPv6 ([ADR 0007](../adr/0007-cross-type-comparison.md)).

**Arithmetic**:

| Function | Signature | Behavior |
| --- | --- | --- |
| `add` | `Int → T → T` | Throws past either end of the kind's range. |
| `sub` | `Int → T → T` | `add` of the negated offset. |
| `diff` | `T → T → Int` | `toInt b - toInt a`. |
| `next`, `prev` | `T → T` | `add 1` and `sub 1`. |

**Address predicates**, forwarded to an address inside a composite value:

| Function | Meaning |
| --- | --- |
| `isLoopback`, `isUnspecified`, `isLinkLocal`, `isMulticast`, `isDocumentation` | Membership in the family's block. |
| `isGlobal`, `isBogon` | Family-aware routability ([ADR 0014](../adr/0014-address-classification.md)). |
| `toArpa` | Reverse-DNS name. |

Family-specific predicates such as `ipv4.isPrivate` are never forwarded; call them on the address directly.

## Conventions

- **Curry order**: the parameter comes first and the operand last, so `map (ipv4.add 1) addresses` and `map (cidr.hostAt 1) blocks` work.
- **Accessors** share their name with the field they read, such as `cidr.prefix`.
- **Errors** throw messages that begin with `libnet` and name the function. Only `tryParse` recovers ([ADR 0006](../adr/0006-parse-throws-tryparse-recovers.md)).
- **Enumeration** functions throw above a size guard and have an `*Unbounded` sibling ([ADR 0015](../adr/0015-enumeration-size-guards.md)).
- **Indexed access** (`hostAt`, `portAt`, `addressAt`, `endpointAt`) counts from 0; a negative index counts from the end, and an out-of-range index throws.
