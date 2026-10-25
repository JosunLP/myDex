import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../features/collection/collection_page.dart';
import '../features/dex/dex_page.dart';
import '../features/dex/pokemon_detail_page.dart';
import '../features/more/more_page.dart';
import '../features/teams/teams_page.dart';
import 'shell.dart';

/// Breite Fenster zeigen Liste und Detail nebeneinander (`/dex?form=…`),
/// schmale öffnen das Detail als eigene Seite (`/dex/pokemon/…`).
GoRouter buildRouter({String initialLocation = '/dex'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dex',
              builder: (context, state) {
                final form = state.uri.queryParameters['form'];
                return DexPage(selected: form == null ? null : FormId(form));
              },
              routes: [
                GoRoute(
                  path: 'pokemon/:formId',
                  builder: (context, state) => PokemonDetailPage(
                    formId: FormId(state.pathParameters['formId']!),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/collection',
              builder: (_, _) => const CollectionPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/teams', builder: (_, _) => const TeamsPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/more', builder: (_, _) => const MorePage())],
        ),
      ],
    ),
  ],
);

/// Öffnet ein Pokémon passend zur aktuellen Fensterbreite.
void openPokemon(BuildContext context, FormId id, {required bool wide}) {
  if (wide) {
    context.go('/dex?form=${Uri.encodeQueryComponent(id.value)}');
  } else {
    context.go('/dex/pokemon/${Uri.encodeComponent(id.value)}');
  }
}
