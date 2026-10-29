# Bounded integers

`port`, `vlanId`, `mtu` and `icmpType` are tagged integers written in decimal. `parse` accepts decimal digits only: no sign, whitespace, hex or leading zeros. `port` adds the RFC 6335 classes and their constants, documented in [`ports.md`](ports.md).

| Namespace  | Range         | Meaning                                                                   | Arithmetic                                 |
| ---------- | ------------- | ------------------------------------------------------------------------- | ------------------------------------------ |
| `port`     | `[0, 65535]`  | TCP, UDP or SCTP port number.                                             | Yes                                        |
| `vlanId`   | `[1, 4094]`   | IEEE 802.1Q VLAN ID; 0 means untagged and 4095 is reserved.               | Yes                                        |
| `mtu`      | `[68, 65535]` | IP MTU, from the RFC 791 forwarding minimum to the 16-bit length maximum. | Yes                                        |
| `icmpType` | `[0, 255]`    | ICMP or ICMPv6 message type, shared by both families.                     | No: adjacent types are unrelated messages. |

Value: `{ _type = <namespace>; value = Int; }`.

Suites: parsing, comparison (numeric), plus arithmetic where the table says so.

| Function  | Signature | Notes                |
| --------- | --------- | -------------------- |
| `fromInt` | `Int → T` | Throws out of range. |
| `toInt`   | `T → Int` |                      |

Constants: `lowestValue`, `highestValue`. Named ICMP types live in [`registry.icmpTypes`](registry.md).
