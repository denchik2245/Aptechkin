import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/empty_state_card.dart';
import 'package:aptechka/core/ui/nav_bars.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_state.dart';
import 'package:aptechka/features/inventory/presentation/widgets/category_row.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_card.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shell of both screens: «nav bar / title», content, tab bar on «Аптечка».
class _KitStateScaffold extends ConsumerWidget {
  const _KitStateScaffold({required this.title, required this.builder});
  final String title;
  final Widget Function(BuildContext context, AppState state) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: context.palette.background,
    extendBody: true,
    bottomNavigationBar: const AppNavigationBar(selectedIndex: 0),
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          TitleNavBar(title: title),
          Expanded(
            child: AsyncValueView(
              value: ref.watch(appControllerProvider),
              data: (state) => Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.maxContentWidth,
                  ),
                  child: builder(context, state),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

const _listPadding = EdgeInsets.fromLTRB(16, 8, 16, 132);

/// «Состояние аптечки» (863:12158): categories by the «Для чего» marks,
/// «Нет или мало» and «Достаточно».
class KitStateScreen extends StatelessWidget {
  const KitStateScreen({required this.kitId, super.key});
  final String kitId;

  @override
  Widget build(BuildContext context) => _KitStateScaffold(
    title: 'Состояние аптечки',
    builder: (context, state) {
      final palette = context.palette;
      final kit = state.pharmacies.where((item) => item.id == kitId);
      if (kit.isEmpty) return const _Missing('Аптечка не найдена');
      final rows = kitCategories(
        state,
        kitId,
        DateTime.now(),
        warningDays: state.settings.expiryWarningDays,
      );
      final lacking = [
        for (final row in rows)
          if (row.level != CategoryLevel.enough) row,
      ];
      final enough = [
        for (final row in rows)
          if (row.level == CategoryLevel.enough) row,
      ];
      List<Widget> group(String title, List<KitCategoryState> items) => [
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
        for (final row in items) ...[
          const SizedBox(height: 8),
          CategoryRow(
            row: row,
            onTap: () => context.push(
              AppRoutes.kitStateCategory(kitId, row.category.name),
            ),
          ),
        ],
      ];
      return ListView(
        padding: _listPadding,
        children: [
          Semantics(
            header: true,
            child: Text(
              '«${kit.first.name}» по категориям',
              style: AppTypography.h2.copyWith(color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Считаем по вашим отметкам «Для чего» и срокам. Это ориентир, а не '
            'рекомендация к покупке — состав аптечки лучше обсудить с врачом.',
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
          if (lacking.isNotEmpty) ...group('Нет или мало', lacking),
          if (enough.isNotEmpty) ...group('Достаточно', enough),
        ],
      );
    },
  );
}

/// «Состояние аптечки / Категория» (863:12343) and «Пустая категория»
/// (863:12448).
class KitCategoryScreen extends ConsumerWidget {
  const KitCategoryScreen({
    required this.kitId,
    required this.category,
    super.key,
  });
  final String kitId;
  final String category;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    await ref.read(appControllerProvider.notifier).selectPharmacy(kitId);
    if (context.mounted) await context.push(AppRoutes.scanner);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = KitCategory.parse(category);
    return _KitStateScaffold(
      title: parsed?.label ?? 'Категория',
      builder: (context, state) {
        if (parsed == null ||
            !state.pharmacies.any((item) => item.id == kitId)) {
          return const _Missing('Категория не найдена');
        }
        final now = DateTime.now();
        final warningDays = state.settings.expiryWarningDays;
        final row = kitCategory(
          state,
          kitId,
          parsed,
          now,
          warningDays: warningDays,
        );
        if (row.isEmpty) {
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: _listPadding.copyWith(top: 66 + 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 132 - 66 - 8).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: EmptyStateCard(
                    image: 'assets/illustrations/onboarding/empty-medicines.png',
                    imageZoom: 1.1146,
                    title: parsed.emptyTitle,
                    text: parsed.emptyText,
                    buttonLabel: 'Добавить лекарство',
                    onPressed: () => _add(context, ref),
                  ),
                ),
              ),
            ),
          );
        }
        final banner = categoryBanner(state, kitId, row, now);
        final kitNames = {for (final kit in state.pharmacies) kit.id: kit.name};
        Widget card(Medicine package, {bool withKit = false}) => PackageCard(
          package: package,
          now: now,
          warningDays: warningDays,
          place: withKit
              ? [
                  ?kitNames[package.pharmacyId],
                  if (package.location.trim().isNotEmpty)
                    package.location.trim(),
                ].join(' · ')
              : null,
          onTap: () => context.push(AppRoutes.medicine(package.id)),
        );
        return ListView(
          padding: _listPadding,
          children: [
            if (banner != null) ...[
              StatusBanner(
                tone: switch (banner.tone) {
                  CategoryBannerTone.warning => StatusBannerTone.warning,
                  CategoryBannerTone.fail => StatusBannerTone.fail,
                  CategoryBannerTone.info => StatusBannerTone.info,
                },
                title: banner.title,
                text: banner.text,
              ),
              const SizedBox(height: 8),
            ],
            for (final package in row.here) ...[
              card(package),
              const SizedBox(height: 8),
            ],
            for (final package in row.elsewhere) ...[
              card(package, withKit: true),
              const SizedBox(height: 8),
            ],
            AppButton.secondary(
              label: 'Добавить лекарство',
              onPressed: () => _add(context, ref),
            ),
          ],
        );
      },
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: AppTypography.bodyMedium.copyWith(
        color: context.palette.textSecondary,
      ),
    ),
  );
}
