import 'package:local_data_transfer/local_data_transfer.dart';

import 'arkiddo_transfer_adapter.dart';

/// Small application-facing composition around the generic LAN endpoint.
///
/// Screens remain responsible for rendering/scanning QR codes and asking the
/// user to accept a manifest. This coordinator only sequences transport calls.
class ArkiddoTransferCoordinator {
  final LanTransferEndpoint endpoint;

  const ArkiddoTransferCoordinator({required this.endpoint});

  Future<TransferInvitation> createInvitation({
    Duration ttl = const Duration(minutes: 5),
  }) => endpoint.createInvitation(ttl: ttl);

  Future<TransferSession> connect(TransferInvitation invitation) =>
      endpoint.connect(invitation);

  Future<TransferSession> waitForConnection() => endpoint.waitForConnection();

  Future<void> sendBundle(
    TransferSession session,
    ArkiddoTransferBundle bundle,
  ) async {
    await session.sendMessage(
      type: 'artkiddo/transfer-manifest+json',
      payload: bundle.manifest,
    );
    for (final file in bundle.files) {
      final id = await session.sendFile(file);
      final terminal = await session.events.firstWhere(
        (event) =>
            event.transferId == id &&
            (event is TransferCompleted || event is TransferFailed),
      );
      if (terminal is TransferFailed) {
        throw terminal.error;
      }
    }
  }

  Future<void> close() => endpoint.close();
}
