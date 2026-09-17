import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

/// `about` — `screens.md` §9.5.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAboutRow)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.commonAppName, style: AppTypography.h1),
              const SizedBox(height: AppSpacing.s2),
              Text(
                l10n.settingsVersion('1.0.0+1'),
                style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextButton(
                onPressed: () => launchUrl(Uri.parse('mailto:contact@artkiddo.bencool.ca')),
                child: Text(l10n.commonContactUs),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
