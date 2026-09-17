import 'dart:convert';
import 'dart:io';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:artkiddo_local/transfer/arkiddo_transfer_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'exports and imports domain data without coupling the transport to Drift',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'artkiddo-transfer-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final masterpiecesDirectory = Directory('${directory.path}/masterpieces')
        ..createSync(recursive: true);
      File(
        '${masterpiecesDirectory.path}/m1.jpg',
      ).writeAsBytesSync([1, 2, 3, 4]);
      final vault = LocalVault(documentsDirProvider: () async => directory);
      final child = Child(
        id: 'c1',
        name: 'Mila',
        birthDate: DateTime(2020, 1, 2),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final masterpiece = Masterpiece(
        id: 'm1',
        childId: child.id,
        relativeImagePath: 'masterpieces/m1.jpg',
        addedAt: DateTime(2024, 1, 2),
        story: 'Un soleil',
      );

      final bundle = await ArkiddoTransferExporter(
        vault: vault,
      ).build(children: [child], masterpieces: [masterpiece]);

      expect(bundle.files, hasLength(1));
      expect(
        await bundle.files.single.openRead().fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        ),
        [1, 2, 3, 4],
      );
      final document = const ArkiddoTransferImporter().decode(bundle.manifest);
      expect(document.children.single['name'], 'Mila');
      expect(document.masterpieces.single['story'], 'Un soleil');
      expect(jsonDecode(utf8.decode(bundle.manifest)), isA<Map>());
    },
  );
}
