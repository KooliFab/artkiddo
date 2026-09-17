# ADR 0005: Local data transfer is separate from domain synchronization

Status: accepted
Date: 2026-09-14

## Context

The account-free ArtKiddo application needs a manual way to move profiles,
stories, images, and recorded audio between two nearby devices. Moving bytes is
not the same operation as synchronizing a household: the receiving app must
choose its data format, validate records, resolve conflicts, and update Drift.

## Decision

Implement one optional package, `local_data_transfer`, in its own repository
outside this one. It owns the transport-neutral models, events, errors, and the
staging/commit contract, plus the Wi-Fi/hotspot WebSocket transport and QR
invitation codec behind the `TransferEndpoint` seam.

The application owns serialization, selection, acceptance, conflict policy,
database writes, and LocalVault integration. Arkiddo's adapter sends images and
recorded audio as binary `FileSource` values and commits verified files only
after its manifest has been accepted. No code is exported through
`artkiddo_core` and no transfer capability is initialized by the local app's
default bootstrap.

The v1 invitation is short-lived and contains a bearer token. The handshake
authenticates the peer with HMAC-SHA256. Payload encryption is deliberately not
claimed by v1; a future encrypted transport must be added before using this on
an untrusted network.

## Cross-repository impact

- Classification: public-local-only (optional manual LAN capability).
- Public/local behavior: consume the external `local_data_transfer` package and
  add an app-level Arkiddo serializer/file handler; the existing offline path
  remains unchanged. The package lives in its own repository and carries its own
  loopback tests, so this repository holds no transfer package source.
- Private mobile/cloud behavior: not applicable for this public implementation;
  private compositions may consume the packages later.
- Web behavior: not applicable.
- Backend behavior: not applicable.
- Public contracts or domain models changed: no `artkiddo_core` contract or
  schema change; new standalone transfer contracts only.
- Private backend contract changed: not applicable.
- Capability or composition change: the LAN endpoint is opt-in and is not
  created by `ArtKiddoBootstrap`.
- Local schema/file migration: not applicable; transfer staging is disposable.
- Remote protocol/backend migration: not applicable.
- Public tests: adapter tests here; package model, loopback LAN, and
  staging/commit tests live in the `local_data_transfer` repository.
- Private mobile tests: physical Android/iOS matrix remains a release gate.
- Web tests: not applicable.
- Backend tests: not applicable.
- Compatibility window: protocol version 1 rejects incompatible invitations.
- Release order, SHA locks, and rollback: publish `local_data_transfer` from its
  own repository, then pin its version in consumers. Rollback is removing the
  optional endpoint while the local application continues to run.
- Architecture/ADR documents to update: this ADR, current-state map, and the
  repository map.

## Consequences

This boundary keeps the generic package reusable for any Dart or Flutter app and
keeps Arkiddo's Drift model private to the app adapter. Because the package holds
no Flutter dependency and ships a single entry point, consumers take one
dependency and no coordinated two-package release is needed. The `dart:io`
transport means the package does not support the web, which this repository's
composition does not target. It also means v1 is a manual,
foreground transfer and does not provide background sync, merge semantics,
cross-session resume, Bluetooth/Nearby discovery, or live audio streaming.
