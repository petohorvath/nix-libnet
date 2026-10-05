# Module types validate but keep strings

Option values typed with `libnet.types.*` stay strings after merge, matching NixOS idioms such as `networking.hostName`. Code that needs structure calls `parse` explicitly.

The integer kinds are the exception: `types.port` accepts an integer or a decimal string and merges to an integer, and `types.vlanId`, `types.mtu` and `types.icmpType` take integers. Every type validates with the core `isValid`, so module checks and runtime parsing cannot drift.
