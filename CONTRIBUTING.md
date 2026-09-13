# Contributing to ArtKiddo

Thank you for improving the offline-first foundation.

Before submitting a change, read the repository map and the public-code rules.
Keep all public documentation, comments, identifiers, and commit messages in
English. User-facing localizations may of course remain translated.

Every feature proposal and pull request must state its effect on each boundary:

- public/local foundation;
- private mobile client;
- private web client;
- private backend.

Use **not applicable** where a boundary is unaffected. Public changes must keep
the account-free path functional and testable without network access. Do not add
provider SDKs, backend identifiers, wire formats, secrets, remote schemas, or
monetization to this repository.

Run the verification commands in the root README and include relevant migration
tests when changing local persistence. By submitting a contribution, you accept
the [CLA](CLA.md).
