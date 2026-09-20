# ADR 0004: Store neutral opaque object keys

## Decision

The local schema and public interfaces use `displayObjectKey`,
`thumbnailObjectKey`, and `audioObjectKey`. They are opaque strings.

## Consequences

Public code does not infer an object path, URL, vendor, bucket, or access policy.
Local schema v1 declares these columns as `display_object_key`,
`thumbnail_object_key`, and `audio_object_key`; no provider-specific column name
exists in the baseline. Private adapters translate object keys to their own
storage operations and authorization model.
