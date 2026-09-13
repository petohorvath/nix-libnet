/*
  libnet.vlanId

  IEEE 802.1Q VLAN ID — a tagged int in `[1, 4094]`. The 12-bit VLAN
  tag has 4096 values, of which only 1..4094 are usable: 0 is the
  priority-tagged / untagged sentinel and 4095 is reserved.

  Note: `diff a b` returns `toInt b - toInt a` (second arg minus first),
  matching the other scalar modules for consistency.

  Tagged like `libnet.port` so a validated VLAN ID is distinguishable
  from a bare int (`is`). There is no string `parse`: VLAN IDs are
  written as integers, so the constructor is `fromInt`. The opt-in
  module type `libnet.types.vlanId` validates and returns a bare int
  (coerced, like `types.port`), so NixOS configs stay `vlanId = 100;`.

  Example:
    libnet.vlanId.fromInt 100   # => { _type = "vlanId"; value = 100; }
    libnet.vlanId.isValid 0     # => false  (priority-tagged sentinel)
    libnet.vlanId.isValid 4095  # => false  (reserved)
*/
import ./internal/bounded-int.nix {
  typeName = "vlanId";
  lowestValue = 1;
  highestValue = 4094;
  arithmetic = true;
}
