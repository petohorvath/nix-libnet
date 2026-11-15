# Shared code moves to `lib/internal/` only when it needs no public namespace

Code that several namespaces share lives in `lib/internal/` when it needs no public namespace, and `lib/internal/` imports only `lib/internal/`, so dependencies point from the namespace files down to the internal modules. Shared code whose errors name a public function takes that function as `caller`, as `address.ipv4.add "ip.add"` and `address.ipv6.fromBytes "ip.fromBytes"` do.

Shared code that needs a public namespace stays in that namespace's file. Each detail parser, `tryParseDetail`, uses its file's private helpers and constructors, and the composite ones call other namespaces' public functions, such as `port.tryParse` in `authority`. A namespace file exports such code apart from its public functions, with a comment saying that it is not public API, and `default.nix` removes it from `libnet`, which a test checks. The contract is `libnet`; a direct import of a file under `lib/` is not part of it.

## Considered options

- **Move every detail parser into `lib/internal/`.** Each would take its file's parsing helpers along, and the composite ones would make `lib/internal/` import the namespace files. Moving only the ones that need no public namespace, today `ipv4` and `ipv6`, would split the detail parsers between two places.
- **A thin public file per namespace**, with each namespace file moved whole into `lib/internal/` and `lib/<namespace>.nix` reduced to a `removeAttrs` over it. It hides the detail parsers from a direct import of the file, which is outside the contract, at the cost of moving fifteen files and every namespace they import.
