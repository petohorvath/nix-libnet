/*
  libnet.vlanId

  Bounded-int validator for IEEE 802.1Q VLAN IDs. The 12-bit VLAN tag
  has 4096 possible values, of which only 1..4094 are usable:
  - 0 is the priority-tagged / untagged sentinel
  - 4095 is reserved for implementation use

  This module is intentionally tiny — a VLAN ID is just an int with a
  range. No tagged value, no parser, no arithmetic. The pure-Nix
  predicate `isValid` plus the boundary constants are exposed for
  generator and validator code outside option evaluation. The opt-in
  module type `libnet.types.vlanId` enforces the same range at
  module-eval time.

  Example:
    libnet.vlanId.isValid 100   # => true
    libnet.vlanId.isValid 0     # => false  (priority-tagged sentinel)
    libnet.vlanId.isValid 4095  # => false  (reserved)
*/
let
  lowestValue = 1;
  highestValue = 4094;

  isValid = v: builtins.isInt v && v >= lowestValue && v <= highestValue;
in
{
  inherit isValid lowestValue highestValue;
}
