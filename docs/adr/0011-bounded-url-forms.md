# Bounded URL forms, not a general URL parser

libnet parses a fixed set of URL shapes, each over a closed scheme registry: `socketUrl`, `bindUrl`, `secureSocketUrl`, `url` and `proxyUrl`, with `authority` and `urlHost` as reusable parts. Components such as userinfo, path, query and fragment are validated and stored as written, never percent-decoded or otherwise normalized, except that the hex digits of their percent-encodings are uppercased ([ADR 0020](0020-case-folded-at-parse.md)): each must match its RFC 3986 grammar, in ASCII with well-formed percent-encoding. `make` runs the same validators as `parse`, so a value it builds prints text that parses back to that value. Relative references, opaque URIs (`mailto:`, `urn:`) and unknown schemes are rejected.

Choices within the URL forms:

- `urlHost` is separate from `host` because the RFC 3986 registered-name grammar admits `_`, `~`, sub-delimiters and percent-encoding with no label structure. `url.toEndpoint` throws for a registered name that is not a valid DNS name. Like `host`, `urlHost` is a pass-through union, over `ip` and `regName`, so an IP host is a full `ipv4` or `ipv6` value.
- Every URL form stores its canonical scheme and derives `transport` and `isSecure` from its scheme registry. A transport plus a secure flag cannot tell `dtls` from `quic`, both TLS over UDP, and a `null` transport standing for `unix` would make `socketUrl` and `bindUrl` the only forms without a scheme. `make` takes the scheme string first and enforces what `parse` does, such as `unix` going with a Unix socket.
- `proxyUrl` requires a port because proxy default ports are not standardized.
- `url` takes scheme default ports from `registry.ports`, the single source of port numbers.
- `url.eq` and `url.compare` read an empty path as `/`, the equivalence RFC 3986 §6.2.3 gives for URLs with an authority, so `http://h` equals `http://h/`. The stored path and `toString` keep the path as given.
