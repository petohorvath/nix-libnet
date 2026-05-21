{
  lib ? null,
}:
let
  harness = import ./harness.nix;
  inherit (harness) runTests prefix;

  importTests = name: import (./. + "/${name}") { inherit harness; };

  coreTests =
    prefix "bits" (importTests "bits.nix")
    // prefix "ipv4" (importTests "ipv4.nix")
    // prefix "mac" (importTests "mac.nix")
    // prefix "carry" (importTests "carry.nix")
    // prefix "ipv6" (importTests "ipv6.nix")
    // prefix "cidr" (importTests "cidr.nix")
    // prefix "ip" (importTests "ip.nix")
    // prefix "ipRange" (importTests "ip-range.nix")
    // prefix "iface" (importTests "interface.nix")
    // prefix "port" (importTests "port.nix")
    // prefix "pr" (importTests "port-range.nix")
    // prefix "ipEndpoint" (importTests "ip-endpoint.nix")
    // prefix "dnsEndpoint" (importTests "dns-endpoint.nix")
    // prefix "endpoint" (importTests "endpoint.nix")
    // prefix "unixSocket" (importTests "unix-socket.nix")
    // prefix "socketUrl" (importTests "socket-url.nix")
    // prefix "secureSocketUrl" (importTests "secure-socket-url.nix")
    // prefix "url" (importTests "url.nix")
    // prefix "urlHost" (importTests "url-host.nix")
    // prefix "authority" (importTests "authority.nix")
    // prefix "proxyUrl" (importTests "proxy-url.nix")
    // prefix "ipListener" (importTests "ip-listener.nix")
    // prefix "listener" (importTests "listener.nix")
    // prefix "transport" (importTests "transport.nix")
    // prefix "hostname" (importTests "hostname.nix")
    // prefix "domain" (importTests "domain.nix")
    // prefix "dnsName" (importTests "dns-name.nix")
    // prefix "host" (importTests "host.nix")
    // prefix "vlanId" (importTests "vlan-id.nix")
    // prefix "mtu" (importTests "mtu.nix")
    // prefix "registry" (importTests "registry.nix")
    // prefix "iparse" (importTests "internal/parse.nix")
    // prefix "ifmt" (importTests "internal/format.nix")
    // prefix "itype" (importTests "internal/types.nix")
    // prefix "idns" (importTests "internal/dns-label.nix");

  typeTests =
    if lib != null then prefix "types" (import ./types.nix { inherit harness lib; }) else { };

in
runTests (coreTests // typeTests)
