# Data invariants

Testable rules that local storage and the optional remote backup must keep.
Tests cite them as `INV-xx`; multi-device scenario tests are numbered `Sxx`
in their file headers.

## A validated local edit never disappears without an explicit deletion

- **INV-01** — A receipt clears only what was sent: an edit validated while
  an earlier one is in flight stays pending.
- **INV-02** — A pull never overwrites a local value that has not been sent.
- **INV-03** — No validated edit is lost, whatever the order of events.

## A needed media file is never replaced or deleted

- **INV-04** — A referenced media version is never deleted or overwritten.
- **INV-05** — A file is deleted only after its last reference is removed.

## An incomplete backup is never reported as saved

- **INV-06** — "Saved" means the row is acknowledged and every media version
  it references is verified remotely.
- **INV-07** — A status never lies by omission: failed, conflicting or pending
  work stays visible.

## An interruption never leaves an unrecoverable operation

- **INV-08** — An interruption between any two writes of an operation can be
  resumed.
- **INV-09** — Replaying an operation (same operation id) is idempotent.

## A conflicting value is never lost without a trace

- **INV-10** — A field edited differently on two devices loses no value: one
  wins, the other is kept in the local history of replaced values.
- **INV-11** — A deletion wins over a concurrent edit without resurrecting the
  item; the edit is kept.

## A restore never produces references without files

- **INV-12** — Pulling the change journal misses no change, whatever the page
  boundaries or commit order.
- **INV-13** — A restore (remote or archive) leaves no reference without its
  file.
- **INV-14** — An artwork is never applied without its parent child row.

## Release and boundaries

- **INV-15** — A release build uses only published, pinned dependencies.
- **INV-16** — The account-free path stands alone: no remote capability is
  needed to use or test the core.
- **INV-17** — Remote storage is never purged for inactivity or after delivery;
  only an explicit purge or the trash expiry removes data.
