# ADR 0004: Store neutral opaque object keys

## Decision

The local schema and public interfaces use `displayObjectKey`,
`thumbnailObjectKey`, and `audioObjectKey`. They are opaque strings.

## Consequences

Public code does not infer an object path, URL, vendor, bucket, or access policy.
Schema v11 renames historical provider-specific columns in place. Private
adapters translate object keys to their own storage operations and authorization
model.
