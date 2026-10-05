# Strict parsing, canonical output

Parsers accept every standard spelling but reject ambiguous ones, and `toString` emits one canonical form:

- IPv4 octets with leading zeros are rejected (`01.2.3.4`), avoiding octal confusion (RFC 6943 §3.1.1).
- IPv6 accepts compression, mixed case and embedded IPv4, and emits RFC 5952 text.
- MAC accepts colon, hyphen, Cisco-dot and bare forms in any case, and emits lowercase colon-separated text.
- Endpoints require brackets around IPv6 (`[::1]:80`), per RFC 3986 §3.2.2.
- Port ranges emit `-` and also accept the iptables `:` separator.
- Hostnames reject the underscore that nixpkgs' `networking.hostName` tolerates, keeping to RFC 1123.

Canonical output means `parse` then `toString` is stable on canonical input. Wildcard bindpoint spellings (`*:80`, `any:80`, `:80`) all print as `:80`.
