# Networks

## `libnet.cidr`

Value: `{ _type = "cidr"; address = Ipv4 or Ipv6; prefix = Int; }` with `prefix` in `[0, 32]` or `[0, 128]` by family. The address may keep host bits (`10.0.0.5/24` parses); `canonical` zeros them. `toString` prints the stored address.

Suites: parsing, comparison. Comparison orders by family, network, then prefix, and `eq` compares canonical networks, so `10.0.0.0/24` equals `10.0.0.5/24`.

**Construction and accessors**

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `Ip → Int → Cidr` | Validates the prefix for the family. |
| `fromAddress` | `Ip → Cidr` | `/32` or `/128`. |
| `address`, `prefix` | `Cidr → Ip`, `Cidr → Int` | Stored fields. |
| `version` | `Cidr → Int` | `4` or `6`. |
| `isIpv4`, `isIpv6` | `Cidr → Bool` | |
| `canonical` | `Cidr → Cidr` | Host bits zeroed. |
| `isCanonical` | `Cidr → Bool` | |

**Derived addresses and counts**

| Function | Signature | Notes |
| --- | --- | --- |
| `network` | `Cidr → Ip` | Host bits zeroed. |
| `topAddress` | `Cidr → Ip` | Host bits set. |
| `broadcast` | `Cidr → Ipv4` | Throws for IPv6. |
| `netmask`, `hostmask` | `Cidr → Ip` | `/24` gives `255.255.255.0` and `0.0.0.255`. |
| `firstHost` | `Cidr → Ip` | `network`, plus one except for IPv4 `/31`–`/32` and IPv6 `/127`–`/128` (RFC 6164). |
| `lastHost` | `Cidr → Ip` | `topAddress`, minus one for IPv4 `/30` and wider. |
| `size` | `Cidr → Int` | Address count. Throws at 2⁶³ or more (IPv6 prefixes below `/65`). |
| `numHosts` | `Cidr → Int` | Usable hosts, `firstHost` through `lastHost`. |

**Enumeration**

| Function | Signature | Notes |
| --- | --- | --- |
| `hostAt` | `Int → Cidr → Ip` | Offset from `network`; `-1` is `topAddress`. |
| `hosts` | `Cidr → [Ip]` | Usable hosts. Throws when `size` exceeds 2¹⁶. |
| `hostsUnbounded` | `Cidr → [Ip]` | No guard. |

**Relationships**, all `false` across families:

| Function | Signature | Notes |
| --- | --- | --- |
| `contains` | `Cidr → (Ip or Cidr) → Bool` | Dispatches on the second argument. |
| `containsAddress`, `containsCidr` | `Cidr → Ip → Bool`, `Cidr → Cidr → Bool` | Single-kind forms. |
| `isSubnetOf` | `Cidr → Cidr → Bool` | `isSubnetOf a b` is `a ⊆ b`, as in Python's `subnet_of`. |
| `isSupernetOf` | `Cidr → Cidr → Bool` | `isSupernetOf a b` is `b ⊆ a`. |
| `overlaps` | `Cidr → Cidr → Bool` | Symmetric. |

**Restructuring and set algebra**

| Function | Signature | Notes |
| --- | --- | --- |
| `subnet` | `Int → Cidr → [Cidr]` | Splits into 2ⁿ blocks, `n` bits longer. `subnet 2` of a `/24` gives four `/26`s. |
| `supernet` | `Int → Cidr → Cidr` | `n` bits shorter. `supernet 8` of `10.1.0.0/24` gives `10.0.0.0/16`. |
| `summarize` | `[Cidr] → [Cidr]` | Minimal sorted cover: merges siblings, drops duplicates and covered blocks, handles each family separately. Python's `collapse_addresses`. |
| `exclude` | `Cidr → Cidr → [Cidr]` | `exclude parent child` covers `parent \ child` minimally. Throws when `child` is outside `parent`. |
| `intersect` | `Cidr → Cidr → Cidr or null` | The smaller block when one contains the other, else `null`. |

## `libnet.ipRange`

Value: `{ _type = "ipRange"; from = Ip; to = Ip; }`, same family, `from ≤ to`. Canonical text is `from-to` with IPv6 unbracketed: `10.0.0.1-10.0.0.50`, `2001:db8::1-2001:db8::ff`.

Suites: parsing, comparison (by family, `from`, then `to`).

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `Ip → Ip → IpRange` | Throws on mixed families or `to < from`. |
| `fromAddress` | `Ip → IpRange` | A single address. |
| `fromCidr` | `Cidr → IpRange` | `network` to `topAddress`. |
| `toCidrs` | `IpRange → [Cidr]` | Minimal exact CIDR cover. |
| `from`, `to` | `IpRange → Ip` | |
| `version` | `IpRange → Int` | |
| `size` | `IpRange → Int` | Throws at 2⁶³ or more. |
| `isIpv4`, `isIpv6`, `isSingleton` | `IpRange → Bool` | |
| `contains` | `IpRange → Ip → Bool` | |
| `overlaps`, `isAdjacent` | `IpRange → IpRange → Bool` | Symmetric; `false` across families. |
| `isSubrangeOf`, `isSuperrangeOf` | `IpRange → IpRange → Bool` | Subject first, as in `cidr.isSubnetOf`. |
| `merge` | `IpRange → IpRange → IpRange or null` | Union when overlapping or adjacent, else `null`. |
| `addressAt` | `Int → IpRange → Ip` | Offset from `from`. |
| `addresses` | `IpRange → [Ip]` | Throws when `size` exceeds 2¹⁶. |
| `addressesUnbounded` | `IpRange → [Ip]` | No guard. |

## `libnet.interfaceAddress`

Value: `{ _type = "interfaceAddress"; address = Ip; prefix = Int; }`. Text is `address/prefix` with host bits preserved; a bare address without `/prefix` is rejected.

Suites: parsing, comparison (by family, address, then prefix), address predicates.

| Function | Signature | Notes |
| --- | --- | --- |
| `make` | `Ip → Int → InterfaceAddress` | Validates the prefix for the family. |
| `fromAddress` | `Ip → InterfaceAddress` | `/32` or `/128`. |
| `fromAddressAndNetwork` | `Ip → Cidr → InterfaceAddress` | Throws when the address is outside the network. |
| `address`, `prefix`, `version` | | Accessors. |
| `isIpv4`, `isIpv6` | `InterfaceAddress → Bool` | |
| `network` | `InterfaceAddress → Cidr` | Canonical network. |
| `netmask`, `hostmask` | `InterfaceAddress → Ip` | |
| `broadcast` | `InterfaceAddress → Ipv4` | Throws for IPv6. |
| `toCidr` | `InterfaceAddress → Cidr` | Keeps the host bits. |
| `toRange` | `InterfaceAddress → IpRange` | The network as a range. |
