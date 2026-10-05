# Every value is a tagged attribute set

Every parsed value is an attribute set with a `_type` discriminator, such as `{ _type = "ipv4"; value = 167772165; }`. Raw strings would push validation onto every caller, and untagged ints or lists cannot be told apart at runtime. The tag makes dispatch in pass-through unions safe and lets `is` check a value structurally.

Inside a composite, a field is tagged when it is a first-class value with its own operations (a CIDR's `address`, an IP endpoint's `port`, a port range's `from` and `to`) and raw when it only indexes into its parent (a CIDR's `prefix`, an IPv6 address's `words`). The same comparison and arithmetic then apply whether a port travels alone or inside a range.
