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

final artworkCountByChildProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final repository = ref.watch(childrenRepositoryProvider);
  ref.watch(allChildrenStreamProvider);
  return repository.countArtworksByChild();
});
