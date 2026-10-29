# Case is folded at parse

Hostnames, domains, registered names and the hosts of URL forms are case-insensitive, so `parse` lowercases them and `toString` prints the lowercase form, as it already did for IPv6, MAC addresses and URL schemes. A registered name also uppercases the hex digits of its percent-encodings (RFC 3986 §6.2.2.1). Every value then has one stored spelling, `eq` and `compare` are structural, and no kind needs a `normalize`.

## Considered Options

- **Preserve case, fold in `eq`, and offer `normalize`.** This was the 0.1 design. `normalize` had to exist on every kind that holds a name, including endpoints, authorities and every URL form, and `toString` was not canonical text.

## Consequences

`hostname.toString (hostname.parse "MyHost")` is `"myhost"`. NixOS option values keep the user's spelling, because module types merge to the input string ([ADR 0016](0016-module-types-keep-strings.md)). Components that are case-sensitive keep their case: userinfo, path, query and fragment ([ADR 0011](0011-bounded-url-forms.md)), interface names and Unix socket paths.
