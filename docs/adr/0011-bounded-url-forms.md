# Bounded URL forms, not a general URL parser

libnet parses a fixed set of URL shapes, each over a closed scheme registry: `socketUrl`, `bindUrl`, `secureSocketUrl`, `url` and `proxyUrl`, with `authority` and `urlHost` as reusable parts. Components such as userinfo, path, query and fragment are validated, stored verbatim and never percent-decoded or normalized: each must match its RFC 3986 grammar, in ASCII with well-formed percent-encoding. `make` runs the same validators as `parse`, so a value it builds prints text that parses back to that value. Relative references, opaque URIs (`mailto:`, `urn:`) and unknown schemes are rejected.

Choices within the URL forms:

- `urlHost` is separate from `host` because the RFC 3986 registered-name grammar admits `_`, `~`, sub-delimiters and percent-encoding with no label structure. `url.toEndpoint` throws for a registered name that is not a valid DNS name. Like `host`, `urlHost` is a pass-through union, over `ip` and `regName`, so an IP host is a full `ipv4` or `ipv6` value.
- `secureSocketUrl` stores the scheme rather than a transport plus a secure flag, since `dtls` and `quic` are both TLS over UDP.
- `proxyUrl` requires a port because proxy default ports are not standardized.
- `url` takes scheme default ports from `registry.ports`, the single source of port numbers.
- `url.eq` and `url.compare` read an empty path as `/`, the equivalence RFC 3986 §6.2.3 gives for URLs with an authority, so `http://h` equals `http://h/`. The stored path and `toString` keep the path as given.
