/*
  nix-unit entry point for the unit suites. Each argument defaults to the
  root flake's locked input, so local runs need none. Pass
  `--arg nixpkgs null` to run without nixpkgs, as the `unit-core` entry
  does; the module-type suite then has no tests.
*/
let
  rootInputs = (builtins.getFlake (toString ../..)).inputs;
in
{
  nixpkgs ? rootInputs.nixpkgs,
  system ? builtins.currentSystem,
}:
let
  testContext = import ../test-context.nix { inherit nixpkgs system; };
in
{
  authority = import ./authority.nix testContext;
  bind-url = import ./bind-url.nix testContext;
  bindpoint = import ./bindpoint.nix testContext;
  cidr = import ./cidr.nix testContext;
  cross-type-equality = import ./cross-type-equality.nix testContext;
  dns-endpoint = import ./dns-endpoint.nix testContext;
  dns-name = import ./dns-name.nix testContext;
  domain = import ./domain.nix testContext;
  endpoint = import ./endpoint.nix testContext;
  host = import ./host.nix testContext;
  hostname = import ./hostname.nix testContext;
  icmp-type = import ./icmp-type.nix testContext;
  interface-address = import ./interface-address.nix testContext;
  interface-name = import ./interface-name.nix testContext;
  internal = {
    bits = import ./internal/bits.nix testContext;
    carry = import ./internal/carry.nix testContext;
    dns-label = import ./internal/dns-label.nix testContext;
    format = import ./internal/format.nix testContext;
    parse = import ./internal/parse.nix testContext;
    types = import ./internal/types.nix testContext;
  };
  ip = import ./ip.nix testContext;
  ip-bindpoint = import ./ip-bindpoint.nix testContext;
  ip-endpoint = import ./ip-endpoint.nix testContext;
  ip-range = import ./ip-range.nix testContext;
  ipv4 = import ./ipv4.nix testContext;
  ipv6 = import ./ipv6.nix testContext;
  mac = import ./mac.nix testContext;
  mtu = import ./mtu.nix testContext;
  port = import ./port.nix testContext;
  port-range = import ./port-range.nix testContext;
  proxy-url = import ./proxy-url.nix testContext;
  registry = import ./registry.nix testContext;
  secure-socket-url = import ./secure-socket-url.nix testContext;
  socket-url = import ./socket-url.nix testContext;
  transport = import ./transport.nix testContext;
  types = import ./types.nix testContext;
  unix-socket = import ./unix-socket.nix testContext;
  url = import ./url.nix testContext;
  url-host = import ./url-host.nix testContext;
  vlan-id = import ./vlan-id.nix testContext;
}
