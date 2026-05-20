{
  lib ? null,
}:
let
  harness = import ./harness.nix;
  inherit (harness) runTests prefix;

  tryImport =
    name:
    let
      p = ./. + "/${name}";
    in
    if builtins.pathExists p then import p { inherit harness; } else { };

  coreTests =
    prefix "bits" (tryImport "bits.nix")
    // prefix "ipv4" (tryImport "ipv4.nix")
    // prefix "mac" (tryImport "mac.nix")
    // prefix "carry" (tryImport "carry.nix")
    // prefix "ipv6" (tryImport "ipv6.nix")
    // prefix "cidr" (tryImport "cidr.nix")
    // prefix "ip" (tryImport "ip.nix")
    // prefix "ipRange" (tryImport "ip-range.nix")
    // prefix "iface" (tryImport "interface.nix")
    // prefix "port" (tryImport "port.nix")
    // prefix "pr" (tryImport "port-range.nix")
    // prefix "ipEndpoint" (tryImport "ip-endpoint.nix")
    // prefix "ln" (tryImport "listener.nix")
    // prefix "transport" (tryImport "transport.nix")
    // prefix "hostname" (tryImport "hostname.nix")
    // prefix "domain" (tryImport "domain.nix")
    // prefix "host" (tryImport "host.nix")
    // prefix "vlanId" (tryImport "vlan-id.nix")
    // prefix "mtu" (tryImport "mtu.nix")
    // prefix "registry" (tryImport "registry.nix")
    // prefix "iparse" (tryImport "internal/parse.nix")
    // prefix "ifmt" (tryImport "internal/format.nix")
    // prefix "itype" (tryImport "internal/types.nix")
    // prefix "idns" (tryImport "internal/dns-label.nix");

  typeTests =
    if lib != null && builtins.pathExists (./. + "/types.nix") then
      prefix "types" (import ./types.nix { inherit harness lib; })
    else
      { };

in
runTests (coreTests // typeTests)
