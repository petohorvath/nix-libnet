/*
  libnet.vlanId

  IEEE 802.1Q VLAN ID — a tagged int in `[1, 4094]`. The 12-bit VLAN
  tag has 4096 values, of which only 1..4094 are usable: 0 is the
  priority-tagged / untagged sentinel and 4095 is reserved.

  Note: `diff a b` returns `toInt b - toInt a` (second arg minus first),
  matching the other scalar modules for consistency.

  A bounded integer like `libnet.port`: `parse` reads decimal text,
  `fromInt` lifts a computed integer, and `is` tells a validated VLAN ID
  from a bare int. The opt-in module type `libnet.types.vlanId` accepts
  an integer or its decimal string and merges to an integer, so NixOS
  configs stay `vlanId = 100;`.

  Example:
    libnet.vlanId.parse "100"     # => { _type = "vlanId"; value = 100; }
    libnet.vlanId.isValid "0"     # => false  (priority-tagged sentinel)
    libnet.vlanId.isValid "4095"  # => false  (reserved)
*/
import ./internal/bounded-int.nix {
  typeName = "vlanId";
  minValue = 1;
  maxValue = 4094;
  arithmetic = true;
}
