import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../features/collection/collection_page.dart';
import '../features/dex/ability_page.dart';
import '../features/dex/dex_page.dart';
import '../features/dex/move_page.dart';
import '../features/dex/pokemon_detail_page.dart';
import '../features/locations/location_page.dart';
import '../features/locations/locations_page.dart';
import '../features/more/data_page.dart';
import '../features/more/help_page.dart';
import '../features/more/more_page.dart';
import '../features/more/sync_page.dart';
import '../features/teams/member_editor_page.dart';
import '../features/teams/team_editor_page.dart';
import '../features/teams/teams_page.dart';
import 'shell.dart';

/// Wide windows show list and detail side by side (`/dex?form=…`), narrow
/// ones open the detail as a page of its own (`/dex/pokemon/…`).
GoRouter buildRouter({String initialLocation = '/dex'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute(
      builder: (context, state, shell) => AppShell(shell: shell),
      // Sections keep their state (like an IndexedStack) and fade through
      // when switching.
      navigatorContainerBuilder: (context, shell, children) =>
          AnimatedBranches(index: shell.currentIndex, children: children),
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
                GoRoute(
                  path: 'move/:moveId',
                  builder: (context, state) =>
                      MovePage(moveId: MoveId(state.pathParameters['moveId']!)),
                ),
                // Location from the Pokémon view, without switching sections.
                GoRoute(
                  path: 'location/:locationId',
                  builder: (context, state) => LocationPage(
                    locationId: LocationId(state.pathParameters['locationId']!),
                  ),
                ),
                GoRoute(
                  path: 'ability/:abilityId',
                  builder: (context, state) => AbilityPage(
                    abilityId: AbilityId(state.pathParameters['abilityId']!),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/locations',
              builder: (_, _) => const LocationsPage(),
              routes: [
                GoRoute(
                  path: ':locationId',
                  builder: (context, state) => LocationPage(
                    locationId: LocationId(state.pathParameters['locationId']!),
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
            GoRoute(
              path: '/teams',
              builder: (_, _) => const TeamsPage(),
              routes: [
                GoRoute(
                  path: ':teamId',
                  builder: (context, state) =>
                      TeamEditorPage(teamId: state.pathParameters['teamId']!),
                  routes: [
                    GoRoute(
                      path: 'member/:index',
                      builder: (context, state) => MemberEditorPage(
                        teamId: state.pathParameters['teamId']!,
                        index:
                            int.tryParse(state.pathParameters['index']!) ?? -1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (_, _) => const MorePage(),
              routes: [
                GoRoute(path: 'data', builder: (_, _) => const DataPage()),
                GoRoute(path: 'help', builder: (_, _) => const HelpPage()),
                GoRoute(path: 'sync', builder: (_, _) => const SyncPage()),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Opens a Pokémon according to the current window width.
void openPokemon(BuildContext context, FormId id, {required bool wide}) {
  if (wide) {
    context.go('/dex?form=${Uri.encodeQueryComponent(id.value)}');
  } else {
    context.go('/dex/pokemon/${Uri.encodeComponent(id.value)}');
  }
}
