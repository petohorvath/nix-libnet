# libnet

Pure-Nix library for IP, MAC, CIDR, port, ipEndpoint, listener, range, and
interface values. Zero nixpkgs dependency in the core.

- **IPv4**, **IPv6**, **MAC** addresses — parse, format, predicates, arithmetic, comparison
- **CIDR** — network math, containment, iteration, subnet/supernet, set algebra
  (summarize/exclude/intersect)
- **Ports** + **PortRange** — RFC 6335 classification; service-name table in [`libnet.registry.ports`](./lib/registry.nix)
- **Endpoint** (`ADDR:PORT`) — `ipEndpoint` (IP), `dnsEndpoint` (name), `unixSocket` (path), `endpoint` (union)
- **Listener** — `ipListener` (`[ADDR]:PORT[-END]`), `unixSocket`, `listener` (union)
- **Range** — non-CIDR address ranges, `toCidrs` conversion
- **Interface** — address-on-subnet descriptor (Python `IPv4Interface` analog)
- **Reverse DNS** (`toArpa`) for both families
- **EUI-64** derivation per RFC 4291
- **NixOS module types** — opt-in via `libnet.withLib lib` (core stays dep-free)

See [`SPEC.md`](./SPEC.md) for the full specification.

## Quick start

```nix
let
  libnet = import ./nix-libnet;

  addr      = libnet.ipv4.parse "10.0.0.5";
  block     = libnet.cidr.parse "10.0.0.0/24";
  contains  = libnet.cidr.contains block addr;      # true
  broadcast = libnet.cidr.broadcast block;           # 10.0.0.255

  macAddr   = libnet.mac.parse "aa:bb:cc:dd:ee:ff";
  eui64     = libnet.ipv6.fromEui64
                (libnet.cidr.parse "2001:db8::/64")
                macAddr;                             # 2001:db8::a8bb:ccff:fedd:eeff

  ep        = libnet.ipEndpoint.parse "[::1]:443";
  addr      = libnet.ipEndpoint.address ep;          # ::1
  p         = libnet.ipEndpoint.port ep;             # 443

  listener  = libnet.ipListener.parse ":8080-8082";
  isWild    = libnet.ipListener.isAnyAddress listener; # true

  summary   = libnet.cidr.summarize [
                (libnet.cidr.parse "10.0.0.0/25")
                (libnet.cidr.parse "10.0.0.128/25")
              ];
  # => [ 10.0.0.0/24 ]

in
  libnet.ipv4.toString broadcast
```

## NixOS module types (opt-in)

```nix
let
  libnet = (import ./nix-libnet).withLib pkgs.lib;
  inherit (libnet) types;
in {
  options.mySvc.bind        = lib.mkOption { type = types.ipv4;     default = "0.0.0.0"; };
  options.mySvc.bind6       = lib.mkOption { type = types.ipv6;     default = "::"; };
  options.mySvc.macAddr     = lib.mkOption { type = types.mac;      example = "aa:bb:cc:dd:ee:ff"; };
  options.mySvc.allowedCidr = lib.mkOption { type = types.ipv4Cidr; default = "10.0.0.0/8"; };
  options.mySvc.port        = lib.mkOption { type = types.port;     default = 8080; };
  options.mySvc.listen      = lib.mkOption { type = types.listener; default = ":8080"; };

  config.services.my-service.args = [
    "--bind=${config.mySvc.bind}"
    # Parse explicitly when structural access is needed:
    "--gateway=${libnet.ipv4.toString
       (libnet.ipv4.fromInt
         ((libnet.ipv4.toInt (libnet.ipv4.parse config.mySvc.bind)) + 1))}"
  ];
}
```

**Option values stay as strings after merge** — matching existing NixOS idioms
(`networking.interfaces.*.address` etc.). Downstream code calls
`libnet.ipv4.parse` (or similar) explicitly when it needs structural access.
Port is the one exception: `types.port` coerces to int.

## Namespaces

| Namespace | Entry points (representative) |
|---|---|
| [`libnet.ipv4`](./lib/ipv4.nix) | parse, toString, fromInt/toInt, predicates (isPrivate/isLoopback/…), toArpa, arithmetic |
| [`libnet.ipv6`](./lib/ipv6.nix) | parse (RFC 5952), toString, from/toWords/Groups/Bytes, fromEui64, IPv4-mapped interop |
| [`libnet.ip`](./lib/ip.nix) | Unified dispatch (auto-detect v4/v6); forwarded predicates and toArpa |
| [`libnet.mac`](./lib/mac.nix) | parse (4 formats), toString(Hyphen/Cisco/Bare), OUI/NIC split, setLocal/setMulticast, toEui64 |
| [`libnet.cidr`](./lib/cidr.nix) | parse, network, broadcast, netmask, hostAt(n), hosts, contains, subnet, supernet, summarize, exclude, intersect |
| [`libnet.port`](./lib/port.nix) | parse, predicates (isWellKnown/…), arithmetic, comparison |
| [`libnet.portRange`](./lib/port-range.nix) | parse (hyphen/colon), merge, contains, ports, toStringColon |
| [`libnet.ipEndpoint`](./lib/ip-endpoint.nix) | IP addr:port, parse (RFC 3986 bracketed), forwarded address predicates |
| [`libnet.dnsEndpoint`](./lib/dns-endpoint.nix) | DNS name:port (rejects IP literals), parse, address/port |
| [`libnet.endpoint`](./lib/endpoint.nix) | pass-through union over ipEndpoint + dnsEndpoint + unixSocket; dispatches on shape (no new tag) |
| [`libnet.unixSocket`](./lib/unix-socket.nix) | Unix domain socket (pathname or @abstract); complete target, no port |
| [`libnet.socketUrl`](./lib/socket-url.nix) | socket address in URL form `<scheme>://<endpoint>` (tcp/udp/sctp/unix); bounded, not a general URL parser |
| [`libnet.url`](./lib/url.nix) | absolute URL `<scheme>://[user@]host[:port][/path][?query][#frag]` over a closed scheme registry; parse, toEndpoint, accessors; components stored verbatim |
| [`libnet.urlHost`](./lib/url-host.nix) | URL-authority host (RFC 3986 IP-literal/reg-name); looser than `host`; parse, toHost, isIp/isRegName |
| [`libnet.ipListener`](./lib/ip-listener.nix) | IP bind spec; parse with `*` / `any` / `:port` wildcards, endpoints, endpointAt(n) |
| [`libnet.listener`](./lib/listener.nix) | pass-through union over ipListener + unixSocket (no new tag) |
| [`libnet.ipRange`](./lib/ip-range.nix) | parse, contains, merge, toCidrs, fromCidr |
| [`libnet.interface`](./lib/interface.nix) | parse (preserves host bits), network, toCidr, toRange |
| [`libnet.transport`](./lib/transport.nix) | tcp/udp/sctp transport-layer enum, parse, isTcp/isUdp/isSctp, eq |
| [`libnet.hostname`](./lib/hostname.nix) | single-label RFC 1123 hostname (1-63 chars), parse, normalize, case-insensitive eq/compare |
| [`libnet.domain`](./lib/domain.nix) | multi-label DNS name (>=2 labels), parent, isSubdomainOf, toHostname, normalize, case-insensitive eq/compare |
| [`libnet.dnsName`](./lib/dns-name.nix) | pass-through union over hostname + domain (rejects IP literals); the "name" half of host |
| [`libnet.host`](./lib/host.nix) | pass-through union over ip + dnsName; dispatches on input shape (no new tag) |
| [`libnet.vlanId`](./lib/vlan-id.nix) | IEEE 802.1Q VLAN ID (tagged int in [1, 4094]); fromInt/toInt, isValid, arithmetic, comparison |
| [`libnet.mtu`](./lib/mtu.nix) | IP MTU (tagged int in [68, 65535]); fromInt/toInt, isValid, arithmetic, comparison |
| [`libnet.registry`](./lib/registry.nix) | `bogons.{ipv4,ipv6}` CIDR lists, `ports.{tcp,udp}` service-name tables, `icmpTypes.{ipv4,ipv6}` message-type tables |
| `libnet.withLib lib` | Inject `nixpkgs.lib` to unlock `types.*` module option types |

## Design highlights

**Tagged values.** Every parsed value is a tagged attrset
(`{ _type = "ipv4"; value = …; }` etc.) so runtime dispatch is safe.

**Uniform API.** Every family exposes the same skeleton: `parse` / `tryParse` /
`toString` / `fromX` / `toX` / `isValid` / `is` / predicates / `add` / `sub` /
`diff` / `next` / `prev` / `eq` / `lt` / `le` / `gt` / `ge` / `compare` / `min` /
`max`. Learn one, know them all.

**Curry-friendly.** Operators come first, operand last. `map (ipv4.add 1)
[a b c]` works.

**Two parse surfaces.** `parse` throws on invalid input; `tryParse` returns
`{ success; value; error; }` — ideal for user-supplied config.

**No nixpkgs in the core.** All logic is pure Nix builtins. Module-type support
is opt-in via `libnet.withLib lib` to keep the core usable in dep-free contexts.

**Comprehensive test coverage.** Every public function, every `throws` branch,
every predicate (positive and negative), every CIDR prefix boundary, and every
arithmetic carry/borrow case is exercised.

## Running the tests

```sh
# All checks across every supported system (core + full):
nix flake check

# Core tests only (dep-free eval, wrapped as a derivation):
nix build .#checks.x86_64-linux.core

# Full suite (adds NixOS module-type tests; pulls nixpkgs.lib):
nix build .#checks.x86_64-linux.full
```

Tests evaluate at `.drv` instantiation time — a failing test aborts the build
with the harness's formatted diff via `builtins.throw`. A passing check
produces an empty `$out`.

**Why two checks?** They encode two separate contracts:

- `core` — passing proves the library itself has **zero nixpkgs dependency**
  (the whole suite evaluates with `lib = null`). If any core file ever reaches
  into `nixpkgs.lib`, this check breaks.
- `full` — supersets `core` and additionally runs the module-type tests
  against real `nixpkgs.lib`, proving `withLib` integration works.

The library itself (`self.lib`) stays dep-free; `inputs.nixpkgs` is used only
to wrap the eval harness as a derivation and to supply `nixpkgs.lib` to the
module-type tests.

## Requirements

- Nix 2.18 or later (for `bitAnd` / `bitOr` / `bitXor` / `match` / `split`).

## Future work

See the [Future Work section of SPEC.md](./SPEC.md#future-work-post-v1-roadmap)
for the v2 roadmap. Highlights include deterministic address assignment
(hash-based), IPv6 zone identifiers,
well-known port reverse lookup, solicited-node multicast derivation, and a
route type.

## License

MIT — see [LICENSE](./LICENSE).
