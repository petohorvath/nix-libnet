let
  core = {
    ipv4      = import ./lib/ipv4.nix;
    ipv6      = import ./lib/ipv6.nix;
    ip        = import ./lib/ip.nix;
    mac       = import ./lib/mac.nix;
    cidr      = import ./lib/cidr.nix;
    port      = import ./lib/port.nix;
    portRange = import ./lib/portRange.nix;
    endpoint  = import ./lib/endpoint.nix;
    listener  = import ./lib/listener.nix;
    range     = import ./lib/range.nix;
    interface = import ./lib/interface.nix;
  };

  withLibFactory = import ./lib/withLib.nix;
in
  core // { withLib = withLibFactory core; }
