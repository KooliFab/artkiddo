import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../local/logging/log.dart';
import '../../local/storage/vault_archive_manifest.dart';
import '../../local/storage/vault_rescue_export.dart';
import '../providers/core_providers.dart';
import '../theme/app_tokens.dart';
import '../ui/app_button.dart';

/// Export and import of the complete archive (`local-only`: no account, no
/// network).
///
/// The export hands the ZIP to the system share sheet. Nothing here may say
/// the data is kept or backed up: sharing a file stores it nowhere by itself,
/// so the messages only tell the parent to check where it went. A partial
/// export is always called partial.
class VaultArchiveScreen extends ConsumerStatefulWidget {
  const VaultArchiveScreen({super.key});

  @override
  ConsumerState<VaultArchiveScreen> createState() => _VaultArchiveScreenState();
}

enum _Tone { info, warning, error }

class _VaultArchiveScreenState extends ConsumerState<VaultArchiveScreen> {
  bool _busy = false;
  String? _progress;
  String? _message;
  _Tone _tone = _Tone.info;

  void _show(String message, _Tone tone) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _progress = null;
      _message = message;
      _tone = tone;
    });
  }

  Future<void> _export() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
      _progress = l10n.vaultArchiveExportProgress(0, 0);
    });
    try {
      final result = await ref
          .read(vaultArchiveExporterProvider)
          .shareArchive(
            onProgress: (completed, total) {
              if (!mounted) return;
              setState(
                () => _progress = l10n.vaultArchiveExportProgress(
                  completed,
                  total,
                ),
              );
            },
          );
      if (result.isPartial) {
        _show(
          l10n.vaultArchiveExportPartial(result.missing.length),
          _Tone.warning,
        );
      } else {
        _show(l10n.vaultArchiveExportDone, _Tone.info);
      }
    } on RescueExportInsufficientSpaceException catch (error) {
      _show(
        l10n.vaultRescueInsufficientSpace(
          formatRescueBytes(error.requiredBytes, l10n.localeName),
        ),
        _Tone.error,
      );
    } catch (e, st) {
      Log.e('Export de l’archive impossible', e, st, 'Vault');
      _show(l10n.vaultArchiveExportFailed, _Tone.error);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    final picker = ref.read(vaultArchivePickerProvider);
    if (picker == null) return;
    final l10n = AppLocalizations.of(context);
    final importer = ref.read(vaultArchiveImporterProvider);
    setState(() {
      _busy = true;
      _message = null;
      _progress = l10n.vaultArchiveImportProgress;
    });
    try {
      final file = await picker();
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final result = await importer.importArchive(file);
      final lines = <String>[
        if (!result.changedAnything)
          l10n.vaultArchiveImportNothingNew
        else if (result.addedArtworks + result.addedChildren > 0)
          l10n.vaultArchiveImportDone(
            result.addedArtworks,
            result.addedChildren,
          )
        else if (result.keptAside == 0)
          l10n.vaultArchiveImportRestored,
        if (result.keptAside > 0)
          l10n.vaultArchiveImportKeptAside(result.keptAside),
      ];
      _show(lines.join('\n'), _Tone.info);
    } on VaultArchiveImportException catch (error) {
      Log.w('Archive refusée : $error', 'Vault');
      _show(switch (error.failure) {
        VaultArchiveFailure.unsupportedVersion =>
          l10n.vaultArchiveImportUnsupported,
        VaultArchiveFailure.corruptedMedia => l10n.vaultArchiveImportCorrupted,
        VaultArchiveFailure.notAnArchive ||
        VaultArchiveFailure.invalidManifest => l10n.vaultArchiveImportInvalid,
      }, _Tone.error);
    } catch (e, st) {
      Log.e('Import de l’archive impossible', e, st, 'Vault');
      _show(l10n.vaultArchiveImportFailed, _Tone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canImport = ref.watch(vaultArchivePickerProvider) != null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vaultArchiveTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          children: [
            Text(
              l10n.vaultArchiveIntro,
              style: AppTypography.body.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s4),
            AppButton(
              label: l10n.vaultArchiveExportAction,
              icon: Icons.ios_share,
              fullWidth: true,
              onPressed: _busy ? null : _export,
            ),
            if (canImport) ...[
              const SizedBox(height: AppSpacing.s3),
              AppButton(
                label: l10n.vaultArchiveImportAction,
                icon: Icons.file_open_outlined,
                variant: AppButtonVariant.secondary,
                fullWidth: true,
                onPressed: _busy ? null : _import,
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            if (_progress != null)
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Text(_progress!, style: AppTypography.body),
                    ),
                  ],
                ),
              )
            else if (_message != null)
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: switch (_tone) {
                      _Tone.info => AppColors.sageSurface,
                      _Tone.warning => AppColors.ochreSurface,
                      _Tone.error => AppColors.accentSurface,
                    },
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_message!, style: AppTypography.body),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
