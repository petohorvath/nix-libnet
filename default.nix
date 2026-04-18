let
  core = {
    ipv4 = import ./lib/ipv4.nix;
    ipv6 = import ./lib/ipv6.nix;
    ip = import ./lib/ip.nix;
    mac = import ./lib/mac.nix;
    cidr = import ./lib/cidr.nix;
    port = import ./lib/port.nix;
    portRange = import ./lib/port-range.nix;
    endpoint = import ./lib/endpoint.nix;
    listener = import ./lib/listener.nix;
    ipRange = import ./lib/ip-range.nix;
    interface = import ./lib/interface.nix;
    registry = import ./lib/registry.nix;
  };
in
core // { withLib = import ./lib/with-lib.nix core; }
