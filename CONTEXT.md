# ArtKiddo domain context

This document defines the stable vocabulary used in public code.

## Core entities

- **Artwork**: a photographed piece of a child's creative work. Its immutable
  identifier is created locally. `addedAt` is the system time at which it was
  stored; `drawnAt` is the optional date supplied by a parent.
- **Child**: a local profile to which artworks belong.
- **Story**: optional text attached to an artwork.
- **Audio story**: optional local voice recording attached to an artwork.
- **Local vault**: the device-owned store for images, audio, and metadata.
- **Object key**: an opaque identifier returned by an optional remote object
  adapter. It is not a URL and has no format in the public domain model.

## Invariants

1. The local vault is usable without remote capability, account, or network.
2. A local identifier survives any future synchronization or restore.
3. `drawnAt`, when present, is used for age presentation; otherwise use
   `addedAt` and make that distinction clear in the UI.
4. A local write is successful only after durable persistence.
5. Local artwork deletion is recoverable for its retention period; child
   deletion is intentionally irreversible.
6. The public model does not promise a backup, remote availability, or remote
   access control. Those are private-product concerns.
