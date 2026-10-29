# Module types validate but keep strings

Option values typed with `libnet.types.*` stay strings after merge, matching NixOS idioms such as `networking.hostName`. Code that needs structure calls `parse` explicitly.

The bounded integers are the exception: `types.port`, `types.vlanId`, `types.mtu` and `types.icmpType` accept an integer or a decimal string and merge to an integer. Every type validates with the core `isValid`, so module checks and runtime parsing cannot drift.
