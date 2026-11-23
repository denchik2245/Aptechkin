import 'package:aptechka/app/routes.dart';
import 'package:aptechka/features/accounts/presentation/account_screen.dart';
import 'package:aptechka/features/onboarding/data/onboarding_store.dart';
import 'package:aptechka/features/onboarding/presentation/notifications_prompt_screen.dart';
import 'package:aptechka/features/onboarding/presentation/onboarding_screen.dart';
import 'package:aptechka/features/home/presentation/pharmacies_screen.dart';
import 'package:aptechka/features/inventory/presentation/kit_search_screen.dart';
import 'package:aptechka/features/inventory/presentation/kit_state_screen.dart';
import 'package:aptechka/features/inventory/presentation/add_medicine_screen.dart';
import 'package:aptechka/features/inventory/presentation/drug_catalog_screen.dart';
import 'package:aptechka/features/inventory/presentation/drug_catalog_variants_screen.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_variant.dart';
import 'package:aptechka/features/inventory/presentation/pharmacy_inventory_screen.dart';
import 'package:aptechka/features/inventory/presentation/places_screen.dart';
import 'package:aptechka/features/inventory/presentation/package_detail_screen.dart';
import 'package:aptechka/features/reminders/presentation/reminders_screen.dart';
import 'package:aptechka/features/reminders/presentation/course_detail_screen.dart';
import 'package:aptechka/features/reminders/presentation/course_editor_screen.dart';
import 'package:aptechka/features/reminders/presentation/notification_preview_screen.dart';
import 'package:aptechka/features/scanner/presentation/add_summary_screen.dart';
import 'package:aptechka/features/scanner/presentation/barcode_scanner_screen.dart';
import 'package:aptechka/features/settings/presentation/about_screen.dart';
import 'package:aptechka/features/settings/presentation/appearance_screen.dart';
import 'package:aptechka/features/settings/presentation/backup_screens.dart';
import 'package:aptechka/features/settings/presentation/help_screen.dart';
import 'package:aptechka/features/settings/presentation/notification_settings_screen.dart';
import 'package:aptechka/features/settings/presentation/settings_screen.dart';
import 'package:aptechka/features/settings/presentation/thresholds_screen.dart';
import 'package:aptechka/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  refreshListenable: OnboardingStore.completed,
  redirect: (context, state) {
    final completed = OnboardingStore.completed.value;
    final inOnboarding = state.matchedLocation.startsWith(AppRoutes.onboarding);
    if (completed == false && !inOnboarding) return AppRoutes.onboarding;
    if (completed == true && state.matchedLocation == AppRoutes.onboarding) {
      return AppRoutes.kits;
    }
    return null;
  },
  routes: [
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.notificationsPrompt,
      builder: (context, state) => const NotificationsPromptScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.kits,
              builder: (context, state) => const PharmaciesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.inventory,
              builder: (context, state) => const PharmacyInventoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.reminders,
              builder: (context, state) => const RemindersScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'appearance',
                  builder: (context, state) => const AppearanceScreen(),
                ),
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) =>
                      const NotificationSettingsScreen(),
                  routes: [
                    GoRoute(
                      path: 'digest',
                      builder: (context, state) =>
                          const DigestScheduleScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'thresholds',
                  builder: (context, state) => const ThresholdsScreen(),
                ),
                GoRoute(
                  path: 'backup',
                  builder: (context, state) => const DataSafetyScreen(),
                  routes: [
                    // Both need the saved copy or the picked file; after a
                    // page reload there is none, so they fall back.
                    GoRoute(
                      path: 'saved',
                      redirect: (context, state) => state.extra is BackupSaved
                          ? null
                          : AppRoutes.settingsBackup,
                      builder: (context, state) =>
                          BackupSavedScreen(saved: state.extra! as BackupSaved),
                    ),
                    GoRoute(
                      path: 'restore',
                      redirect: (context, state) => state.extra is RestorePick
                          ? null
                          : AppRoutes.settingsBackup,
                      builder: (context, state) =>
                          RestoreScreen(pick: state.extra! as RestorePick),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'help',
                  builder: (context, state) => const HelpScreen(),
                ),
                GoRoute(
                  path: 'about',
                  builder: (context, state) => const AboutScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/treatment/notification/:id',
      builder: (context, state) =>
          NotificationPreviewScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.treatmentNew,
      builder: (context, state) => CourseEditorScreen(
        editId: state.uri.queryParameters['edit'],
        repeatId: state.uri.queryParameters['repeat'],
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/treatment/course/:id',
      builder: (context, state) =>
          CourseDetailScreen(id: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'history',
          builder: (context, state) =>
              CourseHistoryScreen(id: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.search,
      builder: (context, state) => const KitSearchScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.account,
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.accountPrivacy,
      builder: (context, state) => const AccountPrivacyScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.medicineSelect,
      builder: (context, state) => DrugCatalogScreen(
        initialQuery: state.uri.queryParameters['q'] ?? '',
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.medicineVariants,
      builder: (context, state) => DrugCatalogVariantsScreen(
        groupKey: state.uri.queryParameters['name'] ?? '',
        initialGroup: state.extra is DrugCatalogGroup
            ? state.extra as DrugCatalogGroup
            : null,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.medicineNew,
      builder: (context, state) => AddMedicineScreen(
        initialEntry: state.extra is DrugCatalogEntry
            ? state.extra as DrugCatalogEntry
            : null,
        catalogGtin: state.uri.queryParameters['catalog'],
        initialVariant: state.extra is DrugCatalogVariant
            ? state.extra as DrugCatalogVariant
            : null,
        catalogGtins: state.uri.queryParameters['candidates']
            ?.split(',')
            .where((value) => value.isNotEmpty)
            .toList(),
        scannedGtin: state.uri.queryParameters['scanned'],
        scannedExpiry: DateTime.tryParse(
          state.uri.queryParameters['expiry'] ?? '',
        ),
        scanSource: state.uri.queryParameters['source'],
        initialName: state.uri.queryParameters['name'],
        batch: state.uri.queryParameters['batch'] == '1',
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/medicine/:id/edit',
      builder: (context, state) =>
          AddMedicineScreen(editId: state.pathParameters['id']),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/medicine/:id',
      builder: (context, state) =>
          PackageDetailScreen(packageId: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.places,
      builder: (context, state) => const PlacesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/kits/:kit/state',
      builder: (context, state) =>
          KitStateScreen(kitId: state.pathParameters['kit']!),
      routes: [
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: ':category',
          builder: (context, state) => KitCategoryScreen(
            kitId: state.pathParameters['kit']!,
            category: state.pathParameters['category']!,
          ),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.scanner,
      builder: (context, state) => BarcodeScannerScreen(
        pickOnly: state.uri.queryParameters['pick'] == '1',
        batch: state.uri.queryParameters['batch'] == '1',
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: AppRoutes.addSummary,
      builder: (context, state) => const AddSummaryScreen(),
    ),
  ],
);
