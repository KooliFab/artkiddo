# Neutral synchronization contract

`src/contracts/sync_backend.dart` and related types define the operations needed
for convergence without exposing a provider, endpoint, table, or wire format. A
An application adapter owns encoding, decoding, authentication, and protocol
compatibility.

The public contract does not assume an account or network. The local journey is
complete with `AppCapabilities.local`.

## Versioned audio writes

`AudioWrite` carries keep/replace/delete and the expected revision. A missing cache means keep, never delete. Replacement uploads immutable bytes before committing metadata; the first photo row is committed before its audio reservation. Conflicts retain local files and pending writes for an explicit choice. An acknowledgement cannot clear a newer local edit. Drift v4 migrates all supported v1–v3 vaults forward without clearing files.
