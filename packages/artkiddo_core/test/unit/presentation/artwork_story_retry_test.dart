// Regression test for D45 (`.scratch/aaa-ui-ux/review-ui-ux.md`, passe finale).
//
// Le garde d'ecriture de l'anecdote etait `if (!_save.isIdle) return`. Apres
// un echec, l'etat restait `ActionError`, donc « Enregistrer » ne repartait
// jamais : le parent perdait le texte qu'il venait d'ecrire, alors que
// `screens.md` §5 promet de le conserver. C'est le meme defaut que D09, dans
// l'etat local d'un widget plutot que dans un controleur — ce qui l'avait
// soustrait au premier balayage.
//
// Le test verifie la propriete qui compte : un echec puis un nouvel essai
// aboutit a une ecriture durable.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

/// Depot qui echoue le nombre de fois demande, puis delegue reellement.
class _FlakyArtworks implements ArtworksRepository {
  _FlakyArtworks(this._inner, {required int failures}) : _remaining = failures;

  final ArtworksRepository _inner;
  int _remaining;

  @override
  Future<ActionResult<void>> updateStory({
    required String id,
    required String? story,
  }) async {
    if (_remaining > 0) {
      _remaining--;
      return ActionFailed(LocalWriteFailure());
    }
    return _inner.updateStory(id: id, story: story);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late LocalVault vault;
  late DriftArtworksRepository artworks;
  late DriftChildrenRepository children;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('artkiddo_d45_');
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(dir.path, 'test.sqlite'))),
    );
    vault = LocalVault(documentsDirProvider: () async => dir);
    children = DriftChildrenRepository(db, vault);
    artworks = DriftArtworksRepository(db, vault);
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test(
    'un echec d ecriture d anecdote n empeche pas le rejeu, et le rejeu est durable',
    () async {
      final created = await children.create(
        name: 'Lea',
        birthDate: DateTime(2021, 4, 3),
      );
      final childId = (created as ActionSuccess<String>).value;

      final source = File(p.join(dir.path, 'src.jpg'))
        ..writeAsBytesSync(List<int>.filled(64, 7));
      final art = await artworks.create(
        childId: childId,
        sourceImageFile: source,
        addedAt: DateTime(2026, 9, 3),
      );
      final artId = (art as ActionSuccess<String>).value;

      final flaky = _FlakyArtworks(artworks, failures: 1);

      // Premier essai : echec annonce comme tel, aucune ecriture.
      final first = await flaky.updateStory(id: artId, story: 'Un chat bleu');
      expect(first, isA<ActionFailed<void>>());
      expect((await artworks.getById(artId))!.story, isNull);

      // Second essai, sans rien reinitialiser : il doit aboutir.
      final second = await flaky.updateStory(id: artId, story: 'Un chat bleu');
      expect(second, isA<ActionSuccess<void>>());
      expect((await artworks.getById(artId))!.story, 'Un chat bleu');
    },
  );
}
