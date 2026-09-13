# Neutral synchronization contract

`src/contracts/sync_backend.dart` and related types define the operations needed
for convergence without exposing a provider, endpoint, table, or wire format. A
private adapter owns encoding, decoding, authentication, and compatibility with
its pinned backend contract.

The public contract does not assume an account or network. The local journey is
complete with `AppCapabilities.local`.
