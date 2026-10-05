# Module types

`libnet.withLib lib` returns the core library plus `types`, a set of NixOS option types; `lib` is `nixpkgs.lib` ([ADR 0001](../adr/0001-pure-nix-core.md)).

```nix
let
  libnet = (import ./nix-libnet).withLib lib;
in
{
  options.services.example = {
    bind = lib.mkOption {
      type = libnet.types.ipv4;
      default = "0.0.0.0";
    };
    port = lib.mkOption {
      type = libnet.types.port;
      default = 8080;
    };
    peers = lib.mkOption {
      type = lib.types.listOf libnet.types.ipEndpoint;
      default = [ ];
    };
  };
}
```

## Behavior

- **String types** accept a string that the matching core `isValid` accepts and merge to that string unchanged ([ADR 0016](../adr/0016-module-types-keep-strings.md)). Definitions merge with `mergeEqualOption`: conflicting definitions are an error.
- **`types.port`** accepts an integer in `[0, 65535]` or its decimal string and merges to an integer.
- **`types.vlanId`, `types.mtu`, `types.icmpType`** are `lib.types.ints.between` over the namespace's range, validated by its `isValid`.
- **`mk`**: every type has `mk value`, which returns a valid value unchanged and throws a `libnet.types.<name>.mk` error otherwise, so `default` and `example` fail at definition. `types.port.mk` also converts a string to an integer.
- **Documentation**: every type has a noun-phrase `description`.

## Types

| Type | Accepts |
| --- | --- |
| `ipv4`, `ipv6`, `ip` | An address of that family, or either. |
| `mac` | A MAC address in any input form; not normalized. |
| `cidr`, `ipv4Cidr`, `ipv6Cidr` | A CIDR, optionally restricted to a family. |
| `ipRange` | `from-to`. |
| `interfaceAddress`, `ipv4InterfaceAddress`, `ipv6InterfaceAddress` | `address/prefix`, optionally restricted to a family. |
| `interfaceName` | A Linux interface name. |
| `port` | An integer or decimal string; merges to an integer. |
| `portRange` | A port or `from-to`. |
| `transport` | `tcp`, `udp` or `sctp`. |
| `hostname`, `domain`, `dnsName`, `host` | The matching name kind. |
| `ipEndpoint`, `dnsEndpoint`, `unixSocket`, `endpoint` | The matching target. |
| `ipBindpoint`, `bindpoint` | The matching bind target. |
| `socketUrl`, `bindUrl`, `secureSocketUrl`, `url`, `urlHost`, `authority`, `proxyUrl` | The matching URL form or part. |
| `vlanId`, `mtu`, `icmpType` | An integer in the namespace's range. |
