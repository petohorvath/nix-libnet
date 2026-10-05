# Scope: syntax and arithmetic, not resolution

libnet parses, validates, formats and computes on network values; it never looks anything up. Evaluation stays pure and reproducible, and the library carries no data that goes stale outside the RFCs it implements.

Out of scope:

- DNS resolution or any live query. Formatting a reverse-DNS name (`toArpa`) and validating hostname syntax are in scope.
- Data that needs external files: GeoIP, WHOIS, ASN, or the Public Suffix List. This is why `domain` has no `tld` accessor: callers usually mean the registrable suffix (`co.uk`), which only the PSL can answer.
- Internationalized domain names, TLS certificates and keys, packet-filter or iptables rule DSLs, and full interface configuration.
- General URL processing (see [ADR 0011](0011-bounded-url-forms.md)).
- IPv6 zone identifiers (`fe80::1%eth0`), which are rare in static configuration. This is deferred, not refused.
