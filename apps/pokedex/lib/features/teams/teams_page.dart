import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/game_context_selector.dart';

class TeamsPage extends StatelessWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.teamsTitle),
        actions: const [
          GameContextSelector(),
          SizedBox(width: Space.s),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.groups_outlined, size: 48),
                const SizedBox(height: Space.l),
                Text(l10n.teamsComingBody, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
