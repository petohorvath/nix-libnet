/*
  nix-unit entry point for the libnet test suites.

  The core suites run without nixpkgs. Pass `lib` to add the module-type
  suite, which needs `nixpkgs.lib`.

  Example:
    nix-unit tests/unit.nix
    nix-unit --arg lib 'import <nixpkgs/lib>' tests/unit.nix
*/
{
  lib ? null,
}:
let
  harness = import ./harness.nix;

  importSuite = path: import path { inherit harness; };

  coreSuites = {
    authority = importSuite ./authority.nix;
    bindUrl = importSuite ./bind-url.nix;
    bindpoint = importSuite ./bindpoint.nix;
    cidr = importSuite ./cidr.nix;
    crossTypeEquality = importSuite ./cross-type-equality.nix;
    dnsEndpoint = importSuite ./dns-endpoint.nix;
    dnsName = importSuite ./dns-name.nix;
    domain = importSuite ./domain.nix;
    endpoint = importSuite ./endpoint.nix;
    host = importSuite ./host.nix;
    hostname = importSuite ./hostname.nix;
    icmpType = importSuite ./icmp-type.nix;
    interfaceAddress = importSuite ./interface-address.nix;
    interfaceName = importSuite ./interface-name.nix;
    internal = {
      bits = importSuite ./internal/bits.nix;
      carry = importSuite ./internal/carry.nix;
      dnsLabel = importSuite ./internal/dns-label.nix;
      format = importSuite ./internal/format.nix;
      parse = importSuite ./internal/parse.nix;
      types = importSuite ./internal/types.nix;
    };
    ip = importSuite ./ip.nix;
    ipBindpoint = importSuite ./ip-bindpoint.nix;
    ipEndpoint = importSuite ./ip-endpoint.nix;
    ipRange = importSuite ./ip-range.nix;
    ipv4 = importSuite ./ipv4.nix;
    ipv6 = importSuite ./ipv6.nix;
    mac = importSuite ./mac.nix;
    mtu = importSuite ./mtu.nix;
    port = importSuite ./port.nix;
    portRange = importSuite ./port-range.nix;
    proxyUrl = importSuite ./proxy-url.nix;
    registry = importSuite ./registry.nix;
    secureSocketUrl = importSuite ./secure-socket-url.nix;
    socketUrl = importSuite ./socket-url.nix;
    transport = importSuite ./transport.nix;
    unixSocket = importSuite ./unix-socket.nix;
    url = importSuite ./url.nix;
    urlHost = importSuite ./url-host.nix;
    vlanId = importSuite ./vlan-id.nix;
  };

  moduleTypeSuites =
    if lib == null then { } else { types = import ./types.nix { inherit harness lib; }; };
in
coreSuites // moduleTypeSuites
