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
- **Family**: the household a local vault is attached to. A vault is bound to
  at most one at a time; joining another requires erasing it first.
- **Member**: a person in a family. Their access `role` (parent, contributor)
  is the authorization model; their `relationLabel` ("Papy", "Tata") is a
  display label only and authorizes nothing.
- **Attribution** (`Artwork.addedBy`): which member photographed a piece. It
  is a member identifier, not a name — names are resolved from the roster at
  render time, and an artwork with no known author shows none rather than
  guessing.

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
7. Family, member and attribution are meaningful only under the `household`
   capability. Without it the local vault has one implicit owner, attribution
   stays null, and nothing in the UI implies a household exists.
