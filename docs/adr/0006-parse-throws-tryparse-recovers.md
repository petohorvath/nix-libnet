# Throwing parse, recoverable tryParse, and nothing else

`parse` throws on invalid input, and `tryParse` returns `{ success; value; error; }` instead. Parsing is the one place untrusted input enters, so it alone gets a recoverable form. Other failure paths (arithmetic overflow, out-of-range indexing, oversized enumeration) throw; callers guard them with predicates such as `isValid`, `contains` or `size`. A `tryAdd` or `tryAddressAt` family would double the API surface for little gain. A missing answer is not a failure: an operation that may have no result, such as `ipRange.merge` of distant ranges, returns `null`, while a conversion outside its domain, such as `ipv6.toIpv4` of an unmapped address, throws.

Every thrown message reads `libnet.<ns>.<fn>: <detail>` and names, once, the public function the caller called, such as `libnet.portRange.ports: range too large`, so failures are easy to grep and point at the call site. Shared code never names itself: it returns a detail without a prefix, or takes the caller's name, so `port.prev` at the lower bound reports `libnet.port.prev`, not the `port.sub` it shares code with. A union names itself and keeps its member's detail, so `ip.parse "300.1.1.1"` reports `libnet.ip.parse: invalid octet in "300.1.1.1"`.

The one exception is `tryParse`, which returns the error `parse` would throw, so its `error` names `<ns>.parse`.
