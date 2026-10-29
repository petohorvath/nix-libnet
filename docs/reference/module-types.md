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
- **Integer types** (`types.port`, `types.vlanId`, `types.mtu`, `types.icmpType`) accept an integer in the namespace's range or its decimal string, both validated by its `isValid`, and merge to an integer.
- **`mk`**: every type has `mk value`, which returns a valid value unchanged and throws a `libnet.types.<name>.mk` error otherwise, describing a wrong argument as every other function does, such as `expected string, got portRange value`, so `default` and `example` fail at definition. The integer types' `mk` also converts a string to an integer.
- **Documentation**: every type has a noun-phrase `description`.

## Types

| Type                                                                                            | Accepts                                                        |
| ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `ipv4`, `ipv6`, `ip`                                                                            | An address of that family, or either.                          |
| `mac`                                                                                           | A MAC address in any input form; not normalized.               |
| `cidr`, `ipv4Cidr`, `ipv6Cidr`                                                                  | A CIDR with host bits zero, optionally restricted to a family. |
| `ipRange`                                                                                       | `from-to`.                                                     |
| `interfaceAddress`, `ipv4InterfaceAddress`, `ipv6InterfaceAddress`                              | `address/prefix`, optionally restricted to a family.           |
| `interfaceName`                                                                                 | A Linux interface name.                                        |
| `port`                                                                                          | A port as an integer or decimal string; merges to an integer.  |
| `portRange`                                                                                     | A port or `from-to`.                                           |
| `transport`                                                                                     | `tcp`, `udp` or `sctp`.                                        |
| `hostname`, `domain`, `dnsName`, `host`                                                         | The matching name kind.                                        |
| `ipEndpoint`, `dnsEndpoint`, `unixSocket`, `endpoint`                                           | The matching target.                                           |
| `ipBindpoint`, `bindpoint`                                                                      | The matching bind target.                                      |
| `socketUrl`, `bindUrl`, `secureSocketUrl`, `url`, `urlHost`, `regName`, `authority`, `proxyUrl` | The matching URL form or part.                                 |
| `vlanId`, `mtu`, `icmpType`                                                                     | An integer or decimal string; merges to an integer.            |
