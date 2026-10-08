import 'dart:io';

import 'package:file_selector/file_selector.dart';

/// Opens the system document chooser for a vault archive (`.zip`).
///
/// Returns `null` when the parent cancels. The plugin copies a provider-backed
/// document (Android content URI, iOS security-scoped URL) into app-owned
/// cache, so the importer always reads an ordinary local file.
Future<File?> pickVaultArchiveFile() async {
  const zip = XTypeGroup(
    label: 'ZIP',
    extensions: <String>['zip'],
    mimeTypes: <String>['application/zip', 'application/x-zip-compressed'],
    uniformTypeIdentifiers: <String>['public.zip-archive'],
  );
  final picked = await openFile(acceptedTypeGroups: const [zip]);
  if (picked == null) return null;
  return File(picked.path);
}
