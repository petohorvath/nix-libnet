let
  core = {
    ipv4 = import ./lib/ipv4.nix;
    ipv6 = import ./lib/ipv6.nix;
    ip = import ./lib/ip.nix;
    mac = import ./lib/mac.nix;
    cidr = import ./lib/cidr.nix;
    port = import ./lib/port.nix;
    portRange = import ./lib/port-range.nix;
    ipEndpoint = import ./lib/ip-endpoint.nix;
    dnsEndpoint = import ./lib/dns-endpoint.nix;
    endpoint = import ./lib/endpoint.nix;
    unixSocket = import ./lib/unix-socket.nix;
    socketUrl = import ./lib/socket-url.nix;
    ipListener = import ./lib/ip-listener.nix;
    listener = import ./lib/listener.nix;
    ipRange = import ./lib/ip-range.nix;
    interface = import ./lib/interface.nix;
    transport = import ./lib/transport.nix;
    hostname = import ./lib/hostname.nix;
    domain = import ./lib/domain.nix;
    dnsName = import ./lib/dns-name.nix;
    host = import ./lib/host.nix;
    vlanId = import ./lib/vlan-id.nix;
    mtu = import ./lib/mtu.nix;
    registry = import ./lib/registry.nix;
  };
in
core // { withLib = import ./lib/with-lib.nix core; }
