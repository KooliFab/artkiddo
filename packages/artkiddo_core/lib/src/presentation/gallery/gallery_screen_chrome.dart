part of 'gallery_screen.dart';

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const height = 52.0;

  final Widget child;
  const _FilterHeaderDelegate({required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}

class _FilterBar extends StatelessWidget {
  final List<Child> children;
  final GalleryFilter filter;
  final double margin;
  final ValueChanged<GalleryFilter> onSelect;
  const _FilterBar({
    required this.children,
    required this.filter,
    required this.margin,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sorted = [...children]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ColoredBox(
      color: AppColors.paper,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: margin),
        children: [
          AppFilterChip(
            label: l10n.galleryFilterAll,
            selected: filter is AllChildren,
            onTap: () => onSelect(const AllChildren()),
          ),
          for (final child in sorted)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.s2),
              child: AppFilterChip(
                label: child.name,
                selected: switch (filter) {
                  OneChild(childId: final selectedId) => selectedId == child.id,
                  _ => false,
                },
                onTap: () => onSelect(OneChild(child.id)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Transient month pill shown over the feed while it scrolls.
///
/// Decorative for assistive technology: every tile already announces its
/// own date, and a label that appears and fades on motion would only repeat
/// it out of context.
class _ScrollMonthLabel extends StatelessWidget {
  final ValueListenable<String?> month;
  final ValueListenable<bool> visible;
  const _ScrollMonthLabel({required this.month, required this.visible});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (context, isVisible, child) => AnimatedOpacity(
            opacity: isVisible ? 1 : 0,
            duration: AppMotion.standard,
            curve: AppMotion.curve,
            child: child,
          ),
          child: ValueListenableBuilder<String?>(
            valueListenable: month,
            builder: (context, value, _) => value == null
                ? const SizedBox.shrink()
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4,
                        vertical: AppSpacing.s2,
                      ),
                      child: Text(
                        value,
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final bool compact;
  const _ShareButton({
    required this.enabled,
    required this.onPressed,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (compact) {
      // Icon-only on narrow screens: the "Share" label would otherwise
      // steal the width the "ArtKiddo" title needs and get it cropped.
      return IconButton(
        tooltip: l10n.shareGalleryHeading,
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
          foregroundColor: AppColors.onAccent,
          backgroundColor: AppColors.share,
          disabledForegroundColor: AppColors.inkDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
        ),
        icon: const Icon(Icons.ios_share_outlined, size: 18),
      );
    }
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.ios_share_outlined, size: 18),
      label: Text(l10n.shareGalleryHeading),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, kMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: AppColors.onAccent,
        backgroundColor: AppColors.share,
        disabledForegroundColor: AppColors.inkDisabled,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        textStyle: AppTypography.label,
      ),
    );
  }
}

/// People surface. Its local default is the children list, so the tooltip
/// names whichever destination this build actually opens: a composition
/// substituting a household hub says "Famille", the account-free build says
/// "Enfants". Labelling the local build "Famille" would promise a household
/// that no account-free composition has.
class _FamilyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool opensHousehold;
  const _FamilyButton({required this.onPressed, required this.opensHousehold});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: opensHousehold ? l10n.familyTitle : l10n.childrenTitle,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
      ),
      icon: const Icon(Icons.people_outline),
    );
  }
}

/// Global settings live one tap from the gallery, not buried inside the
/// family hub. The debug-only screen is reached from inside settings.
class _SettingsButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SettingsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.settingsTitle,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
      ),
      icon: const Icon(Icons.settings_outlined, color: AppColors.ink),
    );
  }
}

class _ArtistPickerSheet extends StatelessWidget {
  final List<Child> children;
  const _ArtistPickerSheet({required this.children});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s5,
          AppSpacing.s3,
          AppSpacing.s5,
          AppSpacing.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.artworkShareGallery, style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s1),
            Text(
              l10n.shareGalleryPickerBody,
              style: AppTypography.body.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.s3),
            for (final child in children)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: AppSpacing.s2,
                leading: CircleAvatar(
                  backgroundColor: AppColors.shareSurface,
                  foregroundColor: AppColors.share,
                  child: Text(
                    child.name.isEmpty ? '?' : child.name[0].toUpperCase(),
                  ),
                ),
                title: Text(child.name, style: AppTypography.bodyStrong),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(child),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaptureSourceSheet extends StatelessWidget {
  const _CaptureSourceSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s5,
          AppSpacing.s3,
          AppSpacing.s5,
          AppSpacing.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.galleryAddArtwork, style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s2),
            _CaptureSourceRow(
              icon: Icons.camera_alt_outlined,
              title: l10n.captureSourceCameraTitle,
              subtitle: l10n.captureSourceCameraBody,
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            _CaptureSourceRow(
              icon: Icons.photo_library_outlined,
              title: l10n.captureSourceGalleryTitle,
              subtitle: l10n.captureSourceGalleryBody,
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureSourceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _CaptureSourceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: AppSpacing.s3,
    leading: Icon(icon, size: 28, color: AppColors.accent),
    title: Text(title, style: AppTypography.bodyStrong),
    subtitle: Text(
      subtitle,
      style: AppTypography.body.copyWith(color: AppColors.inkMuted),
    ),
    onTap: onTap,
  );
}
