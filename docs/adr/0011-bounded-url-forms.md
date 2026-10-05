# Bounded URL forms, not a general URL parser

libnet parses a fixed set of URL shapes, each over a closed scheme registry: `socketUrl`, `bindUrl`, `secureSocketUrl`, `url` and `proxyUrl`, with `authority` and `urlHost` as reusable parts. Components such as userinfo, path, query and fragment are stored verbatim, never percent-decoded or normalized. Relative references, opaque URIs (`mailto:`, `urn:`) and unknown schemes are rejected.

Choices within the URL forms:

- `urlHost` is separate from `host` because the RFC 3986 registered-name grammar admits `_`, `~`, sub-delimiters and percent-encoding with no label structure. `url.toEndpoint` throws for a registered name that is not a valid DNS name.
- `secureSocketUrl` stores the scheme rather than a transport plus a secure flag, since `dtls` and `quic` are both TLS over UDP.
- `proxyUrl` requires a port because proxy default ports are not standardized.
- `url` takes scheme default ports from `registry.ports`, the single source of port numbers.
