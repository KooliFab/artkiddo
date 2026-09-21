/// Conflict/cursor arithmetic, kept pure and separate from
/// [SyncEngine]'s I/O so the two rules the client actually needs are
/// each one small, directly-testable function:
///
/// 1. **Never let a `pull` clobber or resurrect a row this vault has
///    an unpushed local change for.** The server is only authoritative
///    for a row once *this* device's own pending write for it has
///    reached the server — until then, applying a pulled snapshot
///    would silently discard a local edit or delete that simply
///    hasn't gone out yet.
/// 2. **The cursor always advances to the maximum server `updated_at`
///    seen, including on rows that were skipped by rule 1.** Otherwise
///    a permanently-stuck outbox entry would pin the cursor forever
///    and force `pull` to re-fetch the same page on every sync.
///
/// Delete-wins and last-write-wins are *not* arbitrated here: they are
/// enforced server-side (a database trigger rejecting updates to
/// already-deleted rows — see [DeletedRowUpdateRejectedException] —
/// and the database's own "last write to commit wins" for ordinary
/// rows) — this module only decides what the *client* does with what
/// the server already resolved.
library;

/// Result of planning a `pull` apply for one entity kind.
class PullApplyPlan<T> {
  /// Rows to actually write into the local Drift tables, in the order
  /// they were pulled.
  final List<T> toApply;

  /// The new cursor for this entity stream, or `null` if the pulled
  /// page was empty (leave that stream cursor untouched in that case
  /// — there is nothing to advance past).
  final DateTime? newCursor;

  const PullApplyPlan({required this.toApply, required this.newCursor});
}

/// Plans which of the pulled rows should be applied locally, and how
/// far the pull cursor should advance.
///
/// [idOf]/[updatedAtOf] extract the identity and server timestamp from
/// each row (works for both `RemoteChildRow` and
/// `RemoteArtworkRow` without either needing a shared interface).
/// [pendingLocalIds] is the current outbox's set of entity ids with an
/// unpushed local change for this entity kind
/// (`SyncOutboxRepository.pendingEntityIds`).
PullApplyPlan<T> planPullApply<T>({
  required List<T> pulled,
  required String Function(T row) idOf,
  required DateTime Function(T row) updatedAtOf,
  required Set<String> pendingLocalIds,
}) {
  final toApply = <T>[];
  DateTime? maxUpdatedAt;

  for (final row in pulled) {
    final updatedAt = updatedAtOf(row);
    if (maxUpdatedAt == null || updatedAt.isAfter(maxUpdatedAt)) {
      maxUpdatedAt = updatedAt;
    }

    if (pendingLocalIds.contains(idOf(row))) {
      // This vault has a write for this id still sitting in the
      // outbox. Skip it this cycle — it will be reconsidered on the
      // next `pull`, by which point either this device's push has
      // drained (and the server now reflects it) or it hasn't (and
      // skipping again is still correct).
      continue;
    }

    toApply.add(row);
  }

  return PullApplyPlan(toApply: toApply, newCursor: maxUpdatedAt);
}
