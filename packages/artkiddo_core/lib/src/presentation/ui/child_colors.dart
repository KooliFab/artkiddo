import '../../domain/child.dart';

/// Stable colour index per child: creation order within the family, ties
/// broken by id, so every screen and device gives a child the same colour
/// without storing it. Feed the result to `AppChildColors`.
Map<String, int> childColorIndexes(Iterable<Child> children) {
  final ordered = [...children]
    ..sort((a, b) {
      final byDate = a.createdAt.compareTo(b.createdAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  return {for (var i = 0; i < ordered.length; i++) ordered[i].id: i};
}
