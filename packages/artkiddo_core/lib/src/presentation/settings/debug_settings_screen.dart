import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../debug/demo_seed.dart';
import '../../domain/action_result.dart';
import '../gallery/gallery_providers.dart';
import '../providers/core_providers.dart';
import '../theme/app_tokens.dart';

/// Screen accessible only in debug mode to perform debug/QA operations,
/// such as seeding test demo data or deleting all stored photos.
class DebugSettingsScreen extends ConsumerStatefulWidget {
  const DebugSettingsScreen({super.key});

  @override
  ConsumerState<DebugSettingsScreen> createState() =>
      _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends ConsumerState<DebugSettingsScreen> {
  bool _isDeleting = false;
  bool _isSeeding = false;

  Future<void> _confirmSeedDemoData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: const Text('Injecter les données de démo ?'),
        content: const Text(
          'Cette action va créer les profils démo (Léa et Noah) et injecter les 8 œuvres de démonstration avec leurs photos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Injecter'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSeeding = true);
    final db = ref.read(appDatabaseProvider);
    final repo = ref.read(artworksRepositoryProvider);

    try {
      final count = await seedDebugDemoData(
        db: db,
        createArtwork: (childId, sourceImageFile, addedAt, story) =>
            repo.create(
              childId: childId,
              sourceImageFile: sourceImageFile,
              addedAt: addedAt,
              story: story,
            ),
        force: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count œuvre(s) de démo injectée(s) avec succès.'),
          duration: AppMotion.snackBar,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text("Erreur lors de l'injection : $e"),
          duration: AppMotion.snackBar,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  Future<void> _confirmDeleteAllPhotos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: const Text('Supprimer toutes les photos ?'),
        content: const Text(
          'Attention : Cette action est irréversible. Toutes les œuvres enregistrées et leurs images locales seront définitivement effacées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final repo = ref.read(artworksRepositoryProvider);
    final result = await repo.deleteAllPhotos();

    if (!mounted) return;
    setState(() => _isDeleting = false);

    switch (result) {
      case ActionSuccess(value: final count):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count photo(s) supprimée(s) avec succès.'),
            duration: AppMotion.snackBar,
          ),
        );
      case ActionFailed(failure: final f):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Erreur lors de la suppression : ${f.runtimeType}'),
            duration: AppMotion.snackBar,
          ),
        );
      case ActionCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Disponible uniquement en mode debug')),
      );
    }

    final isBusy = _isDeleting || _isSeeding;

    return Scaffold(
      appBar: AppBar(title: const Text('Debug / Réglages')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bug_report_outlined,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      'Menu visible uniquement en debug mode.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'DONNÉES LOCALES',
              style: AppTypography.label.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s2),
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: _isSeeding
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.auto_fix_high_outlined,
                            color: AppColors.accent,
                          ),
                    title: Text(
                      'Injecter les données démo (Seed)',
                      style: AppTypography.bodyStrong,
                    ),
                    subtitle: Text(
                      'Crée Léa et Noah et injecte 8 œuvres de démonstration.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    onTap: isBusy ? null : _confirmSeedDemoData,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: _isDeleting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.delete_forever_outlined,
                            color: AppColors.danger,
                          ),
                    title: Text(
                      'Supprimer toutes les photos',
                      style: AppTypography.bodyStrong.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    subtitle: Text(
                      'Efface toutes les œuvres en base et leurs fichiers images.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    onTap: isBusy ? null : _confirmDeleteAllPhotos,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
