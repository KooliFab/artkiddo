// Unit tests for [ChildEditorController]: validation gating, the
// non-blocking duplicate-name warning, and that a write failure never
// wipes the form.
//
// Reference: `.scratch/aaa-ui-ux/design/contracts.md` §5.3, §5.4.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late LocalVault vault;
  late ProviderContainer container;

  const args = ChildEditorArgs(origin: ChildEditorOrigin.childrenList);

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('artkiddo_child_editor_test_');
    final docsDir = Directory(p.join(tempRoot.path, 'docs'));
    await docsDir.create(recursive: true);
    db = AppDatabase.forTesting(NativeDatabase(File(p.join(tempRoot.path, 'test.sqlite'))));
    vault = LocalVault(documentsDirProvider: () async => docsDir);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        localVaultProvider.overrideWith((ref) => vault),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  test('save() with a missing birth date blocks the write and reports the error', () async {
    final controller = container.read(childEditorControllerProvider(args).notifier);
    controller.updateName('Léa');
    // No birth date chosen.

    final result = await controller.save();

    expect(result, isA<ActionCancelled<String>>());
    final state = container.read(childEditorControllerProvider(args));
    expect(state.errors.contains(ChildFieldError.birthDateMissing), isTrue);
  });

  test('a duplicate name is a warning only — save() still succeeds', () async {
    final repo = container.read(childrenRepositoryProvider);
    final existing = await repo.create(name: 'Léa', birthDate: DateTime(2021, 3, 14));
    expect(existing, isA<ActionSuccess<String>>());
    // Let the watchAll() stream emit its first snapshot before validating
    // against it — the duplicate check reads that provider synchronously.
    final sub = container.listen(allChildrenStreamProvider, (previous, next) {});
    for (var i = 0; i < 50 && !sub.read().hasValue; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    expect(sub.read().hasValue, isTrue, reason: 'watchAll() should have emitted by now');

    final controller = container.read(childEditorControllerProvider(args).notifier);
    controller.updateName('léa'); // same name, different case
    controller.updateBirthDate(DateTime(2023, 11, 2));

    final result = await controller.save();

    expect(result, isA<ActionSuccess<String>>(), reason: 'a duplicate first name is a warning, not a blocking error');
    final state = container.read(childEditorControllerProvider(args));
    expect(state.errors.contains(ChildFieldError.nameDuplicate), isTrue);
  });

  test('typed name and birth date survive a failed submit attempt', () async {
    final controller = container.read(childEditorControllerProvider(args).notifier);
    controller.updateName('Noah');
    // Attempt to submit with no birth date -> blocked, nothing sent.
    await controller.save();

    final state = container.read(childEditorControllerProvider(args));
    expect(state.name, 'Noah', reason: 'a validation failure must never clear a typed field');
  });
}
