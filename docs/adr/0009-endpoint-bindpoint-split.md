# Separate connect-side endpoints from bind-side bindpoints

An endpoint answers "connect to where?" and a bindpoint answers "bind where?". Keeping them as separate types gives outbound code a type-level guarantee that it never receives an absent address or a port range where a concrete target is required. Endpoints check syntax, not reachability ([ADR 0003](0003-syntax-not-resolution.md)): the unspecified address and port 0 are valid in an endpoint, and a bindpoint whose address is `0.0.0.0` or `::` materializes into endpoints holding that address. Only a bindpoint without an address has no endpoint form, because it names no address to connect to.

The split has deliberate asymmetries:

- A bindpoint is what `bind(2)` takes: an optional address and a port range. It carries no transport (a bound UDP socket never listens), so `bindUrl` adds a scheme that names the transport, as `socketUrl` does for endpoints.
- A bindpoint has no DNS-name member: a host binds an address it owns, so `localhost` is rejected.
- Endpoints split by resolution: an IP endpoint is resolved, so address predicates such as `isLoopback` are meaningful; a DNS endpoint is not and exposes none.
- A Unix socket belongs to both unions because the same path serves bind and connect.
- `ipBindpoint.endpoints` materializes a bindpoint into endpoints. Wrapping an endpoint as a bindpoint is a one-liner and has no helper.
