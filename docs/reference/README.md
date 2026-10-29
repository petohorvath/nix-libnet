# API reference

This reference is the contract for libnet's public API: the value each namespace produces, its canonical text, and the behavior of every function. Terms follow [`GLOSSARY.md`](../../GLOSSARY.md); the reasons behind the design are in [`docs/adr/`](../adr/).

| Area                                    | Namespaces                                                                                      |
| --------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [Addresses](addresses.md)               | `ipv4`, `ipv6`, `ip`, `mac`                                                                     |
| [Networks](networks.md)                 | `cidr`, `ipRange`, `interfaceAddress`                                                           |
| [Ports and transports](ports.md)        | `port`, `portRange`, `transport`                                                                |
| [Names](names.md)                       | `hostname`, `domain`, `dnsName`, `host`, `interfaceName`                                        |
| [Targets](targets.md)                   | `ipEndpoint`, `dnsEndpoint`, `unixSocket`, `endpoint`, `ipBindpoint`, `bindpoint`               |
| [URL forms](urls.md)                    | `socketUrl`, `bindUrl`, `secureSocketUrl`, `urlHost`, `regName`, `authority`, `url`, `proxyUrl` |
| [Bounded integers](bounded-integers.md) | `port`, `vlanId`, `mtu`, `icmpType`                                                             |
| [Registry](registry.md)                 | `registry`                                                                                      |
| [Module types](module-types.md)         | `withLib`, `types`                                                                              |

Signatures are Haskell-style reading aids; Nix is dynamically typed. `lib/internal/` is not reachable through `libnet` and is not part of the contract.

## Standard suites

Each namespace page lists which suites it provides and documents only what differs from them or adds to them.

**Parsing**, for a kind `T`:

| Function   | Signature           | Behavior                                                                                         |
| ---------- | ------------------- | ------------------------------------------------------------------------------------------------ |
| `parse`    | `String → T`        | Throws on invalid input, including a non-string.                                                 |
| `tryParse` | `Any → TryResult T` | Never throws; fails for a non-string.                                                            |
| `toString` | `T → String`        | Canonical text.                                                                                  |
| `isValid`  | `Any → Bool`        | `(tryParse s).success`.                                                                          |
| `is`       | `Any → Bool`        | Whether the argument is a `T` value. A string is never a value: `ipv4.is "10.0.0.1"` is `false`. |

`TryResult T` is `{ success = Bool; value = T or null; error = String or null; }`, with `error` set only on failure. The `error` is the message `parse` would throw, naming `<ns>.parse`.

**Comparison**: `eq`, `lt`, `le`, `gt`, `ge` of type `T → T → Bool`; `compare :: T → T → Int` returning `-1`, `0` or `1`; and `min`, `max` of type `T → T → T`. `eq` ignores spelling that does not change meaning, such as the case of a case-insensitive component or a port equal to the scheme default, and counts every stored component. `compare a b` is `0` exactly when `eq a b`. Across kinds and families, and for operands that are not tagged values, `eq` is `false` and never throws, and ordering puts IPv4 before IPv6 ([ADR 0007](../adr/0007-cross-type-comparison.md)).

**Arithmetic**:

| Function       | Signature     | Behavior                                    |
| -------------- | ------------- | ------------------------------------------- |
| `add`          | `Int → T → T` | Throws past either end of the kind's range. |
| `sub`          | `Int → T → T` | `add` of the negated offset.                |
| `diff`         | `T → T → Int` | `toInt b - toInt a`.                        |
| `next`, `prev` | `T → T`       | `add 1` and `sub 1`.                        |

**Address predicates**, forwarded to an address inside a composite value:

| Function                                                                       | Meaning                                                                       |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| `isLoopback`, `isUnspecified`, `isLinkLocal`, `isMulticast`, `isDocumentation` | Membership in the family's block.                                             |
| `isGlobal`, `isBogon`                                                          | Family-aware routability ([ADR 0014](../adr/0014-address-classification.md)). |
| `toArpa`                                                                       | Reverse-DNS name.                                                             |

Family-specific predicates such as `ipv4.isPrivate` are never forwarded; call them on the address directly. Composites may forward accessors and predicates from a nested part in the same way, as `url.host` reads the host of `url.authority`.

## Conventions

- **Curry order**: the parameter comes first and the operand last, so `map (ipv4.add 1) addresses` and `map (cidr.addressAt 1) blocks` work.
- **Relations** read in English order: `isXOf a b` is "a is X of b", as in Python's `subnet_of` and Haskell's `isPrefixOf`. Partially apply the converse to filter the other way: `filter (cidr.isSupernetOf net) blocks` keeps blocks inside `net`.
- **One name per operation**: the library has no function aliases. Input spellings, such as `ssl` for `tls` or `any` for the wildcard address, are not aliases.
- **Accessors** share their name with the field they read, such as `cidr.prefix`. A scalar's generic `value` field has no accessor; read it with `toString` or `toInt`.
- **Union predicates**: a pass-through union has one `is<Member>` predicate per direct member, such as `host.isIp` and `host.isDnsName`. Test a leaf kind with its own `is`, such as `hostname.is`.
- **Constants** are tagged values of the kind, such as `ipv4.loopback` and `transport.values`; integer domain bounds, named with `min` and `max`, such as `port.maxValue` and `interfaceName.maxLength`; or scheme tables, such as `url.schemes`. They are named for their meaning in libnet, not copied from C headers.
- **Tagged results**: functions return tagged values for tagged kinds, so `url.defaultPort` returns a `Port`. Constant tables, such as `url.schemes` and `registry.ports`, and integer domain bounds hold plain literals.
- **Constructors**: `make` takes a tagged value for a tagged field and a raw value for a raw one ([ADR 0004](../adr/0004-tagged-values.md)), so `portRange.make` takes two `Port` values and `cidr.make` an `Ip` and an integer prefix. Build tagged arguments with `parse` or `fromInt`.
- **Decimal text**: every decimal number in parsed text, such as a port, a port range bound or a prefix length, is digits only, without sign, whitespace or leading zeros; `0` itself is valid ([ADR 0013](../adr/0013-strict-input-canonical-output.md)).
- **Argument kinds**: every function checks the kind of each argument, a tagged value's `_type` or a raw value's builtin type, and throws `libnet.<ns>.<fn>: expected <kind>, got <kind>` on a mismatch, such as for `port.toString 80` or `port.add 1.5 p`. Only `is`, the union `is<Member>` predicates, `eq`, `isValid` and `tryParse` accept any value, and they never throw. The check reads only the tag, so a value with the right `_type` and malformed fields gives undefined results ([ADR 0007](../adr/0007-cross-type-comparison.md)).
- **Errors** read `libnet.<ns>.<fn>: <detail>` and name, once, the function the caller called, even when another function does the work: `port.prev` at the lower bound reports `libnet.port.prev`. A parse failure names `<ns>.parse`, including the `error` that `tryParse` returns. Only `tryParse` recovers ([ADR 0006](../adr/0006-parse-throws-tryparse-recovers.md)).
- **Enumeration** functions throw above a size guard and have an `*Unbounded` sibling ([ADR 0015](../adr/0015-enumeration-size-guards.md)).
- **Indexed access** (`addressAt`, `portAt`, `endpointAt`) counts from 0; a negative index counts from the end, and an out-of-range index throws.
