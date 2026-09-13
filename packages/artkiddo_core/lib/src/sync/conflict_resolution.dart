library;

class PullApplyPlan<T> {
  final List<T> toApply;

  final DateTime? newCursor;

  const PullApplyPlan({required this.toApply, required this.newCursor});
}

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
      continue;
    }

    toApply.add(row);
  }

  return PullApplyPlan(toApply: toApply, newCursor: maxUpdatedAt);
}
