import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Offline-Hilfe zu den Grundbegriffen der App.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final topics = [
      (Icons.sports_esports_outlined, l10n.helpGameTitle, l10n.helpGameBody),
      (Icons.rule, l10n.helpAvailabilityTitle, l10n.helpAvailabilityBody),
      (Icons.search, l10n.helpSearchTitle, l10n.helpSearchBody),
      (Icons.place_outlined, l10n.helpLocationsTitle, l10n.helpLocationsBody),
      (
        Icons.check_circle_outline,
        l10n.helpCollectionTitle,
        l10n.helpCollectionBody,
      ),
      (Icons.groups_outlined, l10n.helpTeamsTitle, l10n.helpTeamsBody),
      (Icons.volume_up_outlined, l10n.helpSpeechTitle, l10n.helpSpeechBody),
      (Icons.save_alt, l10n.helpBackupTitle, l10n.helpBackupBody),
      (Icons.cloud_sync_outlined, l10n.helpSyncTitle, l10n.helpSyncBody),
      (Icons.shield_outlined, l10n.helpPrivacyTitle, l10n.helpPrivacyBody),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        children: [
          for (final (icon, title, body) in topics)
            ExpansionTile(
              leading: Icon(icon),
              title: Text(title),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              childrenPadding: const EdgeInsets.fromLTRB(
                Space.l,
                0,
                Space.l,
                Space.l,
              ),
              children: [SelectableText(body)],
            ),
        ],
      ),
    );
  }
}
