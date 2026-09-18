import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/action_result.dart';
import '../local/database/app_database.dart';

/// Loads the shared QA gallery in debug builds when the local database is empty.
///
/// The original project documents eight synthetic `demo-*.png` illustrations,
/// but those source files are not tracked. Deterministic drawings keep this
/// fixture usable by both the local app and private cloud composition without
/// shipping real children's photos or uploading fixture data.
Future<void> seedDebugDemoData({
  required AppDatabase db,
  required Future<ActionResult<String>> Function(
    String childId,
    File sourceImageFile,
    DateTime addedAt,
    String? story,
  )
  createArtwork,
}) async {
  if (!kDebugMode) return;
  if ((await (db.select(db.childrenTable)..limit(1)).get()).isNotEmpty) return;

  const leaId = 'debug-demo-child-lea';
  const noahId = 'debug-demo-child-noah';
  final children = [
    (id: leaId, name: 'Léa', birthDate: DateTime(2021, 3, 14)),
    (id: noahId, name: 'Noah', birthDate: DateTime(2023, 11, 2)),
  ];
  final artworks = [
    (
      leaId,
      DateTime(2026, 9, 3),
      "C'est notre maison, avec le chat sur le toit parce qu'il aime regarder les oiseaux.",
    ),
    (noahId, DateTime(2026, 9, 1), null),
    (
      leaId,
      DateTime(2026, 8, 28),
      'Un dinosaure qui mange une fraise dans le ciel.',
    ),
    (
      leaId,
      DateTime(2026, 8, 19),
      'La fusée va chercher grand-maman sur la lune.',
    ),
    (noahId, DateTime(2026, 8, 11), 'Des ronds. Beaucoup de ronds.'),
    (leaId, DateTime(2026, 7, 2), null),
    (noahId, DateTime(2026, 6, 21), 'Papa avec des cheveux jaunes.'),
    (
      leaId,
      DateTime(2026, 6, 6),
      "L'arc-en-ciel après la pluie, avec les flaques.",
    ),
  ];

  for (final child in children) {
    await db
        .into(db.childrenTable)
        .insert(
          ChildrenTableCompanion.insert(
            id: child.id,
            name: child.name,
            birthDate: child.birthDate,
            createdAt: DateTime(2026, 6, 1),
            updatedAt: DateTime(2026, 6, 1),
            syncState: const Value('synced'),
          ),
        );
  }

  final tempDir = await getTemporaryDirectory();
  try {
    for (var i = 0; i < artworks.length; i++) {
      final (childId, addedAt, story) = artworks[i];
      final source = File(p.join(tempDir.path, 'artkiddo-debug-demo-$i.png'));
      await source.writeAsBytes(_drawDemo(i));
      final result = await createArtwork(childId, source, addedAt, story);
      if (result case ActionSuccess(value: final id)) {
        await (db.update(
          db.masterpiecesTable,
        )..where((t) => t.id.equals(id))).write(
          const MasterpiecesTableCompanion(syncState: Value('synced')),
        );
        await (db.delete(
          db.syncOutboxTable,
        )..where((t) => t.entityId.equals(id))).go();
      }
    }
  } finally {
    for (var i = 0; i < artworks.length; i++) {
      final file = File(p.join(tempDir.path, 'artkiddo-debug-demo-$i.png'));
      if (await file.exists()) await file.delete();
    }
  }
}

List<int> _drawDemo(int index) {
  final canvas = image.Image(width: 900, height: 700);
  final colours = [
    image.ColorRgb8(244, 114, 94),
    image.ColorRgb8(76, 175, 155),
    image.ColorRgb8(244, 190, 74),
    image.ColorRgb8(117, 103, 196),
    image.ColorRgb8(235, 111, 161),
    image.ColorRgb8(90, 164, 218),
    image.ColorRgb8(249, 145, 76),
    image.ColorRgb8(99, 181, 112),
  ];
  image.fill(canvas, color: image.ColorRgb8(255, 249, 239));
  image.drawCircle(
    canvas,
    x: 450,
    y: 350,
    radius: 215,
    color: colours[index % colours.length],
  );
  image.drawCircle(
    canvas,
    x: 300 + (index * 37) % 300,
    y: 230,
    radius: 85,
    color: colours[(index + 3) % colours.length],
  );
  image.drawCircle(
    canvas,
    x: 250,
    y: 500,
    radius: 48,
    color: colours[(index + 5) % colours.length],
  );
  image.drawCircle(
    canvas,
    x: 650,
    y: 500,
    radius: 62,
    color: colours[(index + 1) % colours.length],
  );
  return image.encodePng(canvas);
}
