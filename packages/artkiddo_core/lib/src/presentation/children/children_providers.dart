import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../../local/repositories/children_repository.dart';
import '../../domain/child.dart';

final childrenRepositoryProvider = Provider<ChildrenRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final vault = ref.watch(localVaultProvider);
  return DriftChildrenRepository(db, vault);
});

final allChildrenStreamProvider = StreamProvider<List<Child>>((ref) {
  final repository = ref.watch(childrenRepositoryProvider);
  return repository.watchAll();
});

/// Number of artworks per child for child row subtitles.
final artworkCountByChildProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final repository = ref.watch(childrenRepositoryProvider);
  // Re-run whenever the artwork or children streams change so the counts
  // stay in sync after a create/delete.
  ref.watch(allChildrenStreamProvider);
  return repository.countArtworksByChild();
});
