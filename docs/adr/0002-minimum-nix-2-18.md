# Minimum Nix version 2.18

libnet supports Nix 2.18 and later. Every builtin it needs (`bitAnd`, `bitOr`, `bitXor`, `match`, `split`, `foldl'`, `genList`) exists there. Nix has no shift operators, so `lib/internal/bits.nix` emulates shifts with multiplication and `div` by powers of two. Using a newer builtin is a compatibility change and needs its own decision.
