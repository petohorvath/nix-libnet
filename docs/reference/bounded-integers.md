# Bounded integers

`vlanId`, `mtu` and `icmpType` are tagged integers with no text form: `fromInt` constructs them and `isValid` takes an integer, not a string.

| Namespace | Range | Meaning | Arithmetic |
| --- | --- | --- | --- |
| `vlanId` | `[1, 4094]` | IEEE 802.1Q VLAN ID; 0 means untagged and 4095 is reserved. | Yes |
| `mtu` | `[68, 65535]` | IP MTU, from the RFC 791 forwarding minimum to the 16-bit length maximum. | Yes |
| `icmpType` | `[0, 255]` | ICMP or ICMPv6 message type, shared by both families. | No: adjacent types are unrelated messages. |

Value: `{ _type = <namespace>; value = Int; }`.

Suites: comparison (numeric), plus arithmetic where the table says so.

| Function | Signature | Notes |
| --- | --- | --- |
| `fromInt` | `Int → T` | Throws out of range. |
| `toInt` | `T → Int` | |
| `toString` | `T → String` | Decimal. |
| `isValid` | `Any → Bool` | An integer in range. |
| `is` | `Any → Bool` | |

Constants: `lowestValue`, `highestValue`. Named ICMP types live in [`registry.icmpTypes`](registry.md).
