# Module types

`libnet.withLib lib` returns the core library plus `types`, a set of NixOS option types, and `withLib` itself; `lib` is `nixpkgs.lib` ([ADR 0001](../adr/0001-pure-nix-core.md)). The core that `import` returns has no `types`. The flake's `lib` output is `withLib` applied to the flake's `nixpkgs` input, so it has `types` already; with `inputs.nix-libnet.inputs.nixpkgs.follows = "nixpkgs"`, they are built against the consumer's own `lib` ([ADR 0022](../adr/0022-flake-lib-includes-module-types.md)). Calling `withLib` on any result, the flake's `lib` included, returns the core with `types` built against the new `lib`.

```nix
let
  libnet = (import ./nix-libnet).withLib lib;
  # With flakes: libnet = inputs.nix-libnet.lib;
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

- **String types** accept a string that the matching core `isValid` accepts and merge to its canonical text, `toString (parse value)` of the namespace; the family-restricted types print with `cidr` or `interfaceAddress` ([ADR 0023](../adr/0023-module-types-merge-to-canonical-values.md)). Definitions with the same canonical text merge, so `02-00-00-00-00-0A` and `02:00:00:00:00:0a` merge to `02:00:00:00:00:0a`. Definitions with different canonical text conflict, and the error shows each as written. Canonical text is libnet's form, not another program's syntax: `*:80` merges to `:80`, so a consumer that writes a value into another program's configuration formats it from `parse`. A consumer that needs the user's spelling declares `lib.types.addCheck lib.types.str libnet.<namespace>.isValid`.
- **Integer types** (`types.port`, `types.vlanId`, `types.mtu`, `types.icmpType`) accept an integer in the namespace's range or its decimal string, both validated by its `isValid`, and merge to an integer.
- **`mk`**: every type has `mk value`, which returns a valid value as the option merges it, canonical text for a string type and an integer for an integer type, such as `"02:00:00:00:00:0a"` for `types.mac.mk "02-00-00-00-00-0A"`, and throws a `libnet.types.<name>.mk` error otherwise, so `default` and `example` fail at definition. The error carries the detail that the core `tryParse` reports, without its `libnet.<namespace>.parse` prefix, such as `libnet.types.dnsName.mk: "1.2.3.4" is an IP address, not a DNS name`. A family-restricted type names the family, such as `libnet.types.ipv4Cidr.mk: "::/0" is an IPv6 CIDR, not an IPv4 CIDR`. A wrong argument is described as every other function describes it, such as `expected string, got portRange value`.
- **Declarations**: two declarations of an option with the same type, such as `types.ipv4` or `listOf types.cidr`, merge to that type, as nixpkgs types do. Declarations with different types, such as `types.ipv4` and `types.ipv6`, conflict.
- **Documentation**: every type's `name` is its libnet name, such as `vlanId`, and its `description` is a noun phrase without an article, as nixpkgs writes its own, so `listOf types.ipv4` reads `list of IPv4 address (dotted-quad)`. The integer types' descriptions give the range and both forms, such as `VLAN ID (1–4094, integer or decimal string)`.

## Types

| Type                                                                                            | Accepts                                                        |
| ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `ipv4`, `ipv6`, `ip`                                                                            | An address of that family, or either.                          |
| `mac`                                                                                           | A MAC address in any input form.                               |
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
