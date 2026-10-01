// Reproduction of data loss #1: renaming a child while its push is in flight.
//
// Before the fix, the push read the child row (old name), sent it, and only
// then cleared the outbox entry by `seq`. A rename made during the send was
// collapsed into that still-present entry, so the acknowledgement removed the
// only record of the rename and the pull that followed overwrote the new name
// with the server's old one.
//
// Fixed by the operation outbox (L02): the rename is its own operation, and
// the acknowledgement removes only the operation that was sent.

import 'dart:async';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'operation_sync_test.dart' show FakeProtocolBackend, Node;

void main() {
  late FakeProtocolBackend backend;
  late Node node;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    backend = FakeProtocolBackend();
    node = await Node.create(backend);
  });

  tearDown(() => node.close());

  test(
    'a rename made while the child is being pushed survives the sync',
    () async {
      final birthDate = DateTime(2019, 3, 1);
      final id = await node.newChild('Ancien');

      // The server applies the patch, then the answer is parked until the
      // test has edited locally while the push is in flight.
      final entered = Completer<void>();
      final gate = Completer<void>();
      backend.beforeReply = (_) async {
        if (!entered.isCompleted) entered.complete();
        await gate.future;
      };

      // Start the full sync (push then pull) and stop it inside the push.
      final sync = node.sync();
      await entered.future;

      expect(
        await node.children.update(
          id: id,
          name: 'Nouveau',
          birthDate: birthDate,
        ),
        isA<ActionSuccess<void>>(),
      );

      backend.beforeReply = null;
      gate.complete();
      await sync;

      final local = await node.children.getById(id);
      final pending = await node.outbox.countPending();
      final server = backend.entity(SyncEntityType.child, id)!;

      expect(
        local?.name,
        'Nouveau',
        reason:
            'the pull must not bring back the pre-rename value '
            '(syncState=${local?.syncState}, pending=$pending, '
            'server=${server.values['name']})',
      );
      expect(
        pending > 0 || server.values['name'] == 'Nouveau',
        isTrue,
        reason:
            'the rename must still be pending or already on the server '
            '(pending=$pending, server=${server.values['name']})',
      );
    },
  );
}
