# ADR 0001: Keep the public foundation local-first

## Decision

The public application must create, read, edit, and recover local artwork
without an account, configuration, or network connection. Local persistence and
files are authoritative for the public experience.

## Consequences

Remote behavior may enhance a private product but cannot be required for public
success. A local write completes only after durable storage. Remote failures do
not erase or silently replace local data.
