# Text that reads as IPv4 is never a name

C resolvers parse addresses with `inet_aton`, which reads `127.1`, `010.0.0.1`, `0x7f.0.0.1` and `2130706433` as IPv4 addresses. Text like this is rejected as a DNS name, so libnet never passes it to a resolver as a name that the resolver would treat as an address. The rule is that a DNS name's rightmost label is neither all digits nor `0x` followed by hex digits.

- `domain` enforces the rule on its rightmost label, since no top-level domain is numeric (RFC 3696 §2). `domain` and `ip` no longer overlap.
- `hostname` keeps the shape of a Linux kernel hostname, so `hostname.parse "1234"` succeeds. `dnsName` rejects such a hostname, and so do the kinds built on it: `host`, `dnsEndpoint`, `endpoint` and the socket URL forms.
- `regName` applies the same rule, although RFC 3986 reads only a dotted quad as an IP literal, because curl and browsers connect to `http://127.1/` as `127.0.0.1`. Like browsers, it ignores one trailing dot, so `127.1.` is rejected too. A URL host is then never one address to libnet and another to the client.

This extends the strict parsing of [ADR 0013](0013-strict-input-canonical-output.md), which rejects leading zeros in IPv4 octets for the same reason.
