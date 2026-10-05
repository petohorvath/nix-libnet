# Throwing parse, recoverable tryParse, and nothing else

`parse` throws on invalid input, and `tryParse` returns `{ success; value; error; }` instead. Parsing is the one place untrusted input enters, so it alone gets a recoverable form. Other failure paths (arithmetic overflow, out-of-range indexing, oversized enumeration) throw; callers guard them with predicates such as `isValid`, `contains` or `size`. A `tryAdd` or `tryHostAt` family would double the API surface for little gain.

Every thrown message starts with `libnet` and names the function, such as `libnet.portRange.ports: range too large`, so failures are easy to grep.
