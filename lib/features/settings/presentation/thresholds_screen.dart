import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_chip.dart';
import 'package:aptechka/core/ui/settings_list.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:aptechka/features/settings/domain/settings_summary.dart';
import 'package:aptechka/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// «Настройки / Когда предупреждать» (1157:24437): the «Срок истекает» and
/// «Мало осталось» thresholds shared by cards, filters and the digest.
class ThresholdsScreen extends ConsumerWidget {
  const ThresholdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(appControllerProvider).asData?.value;
    if (state == null) {
      return const SettingsPage(title: 'Когда предупреждать', children: []);
    }
    final settings = state.settings;
    final matches = thresholdMatches(state, DateTime.now());
    return SettingsPage(
      title: 'Когда предупреждать',
      children: [
        SettingsSection(
          title: 'Срок годности',
          footnote:
              'Учитываем и срок после вскрытия, если он указан. Дата на '
              'упаковке не меняется.',
          child: _ChoiceCard(
            title: 'Показывать «Срок истекает» за',
            chips: [
              for (final days in AppSettings.expiryWarningChoices)
                AppChip(
                  label: russianCount(days, 'день', 'дня', 'дней'),
                  selected: settings.expiryWarningDays == days,
                  onTap: () => saveSettings(
                    context,
                    ref,
                    (s) => s.copyWith(expiryWarningDays: days),
                  ),
                ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Остаток',
          footnote:
              'Единицы берутся из упаковки: таблетки, капсулы, флаконы. '
              'Пустые упаковки отмечаются всегда.',
          child: _ChoiceCard(
            title: 'Показывать «Мало осталось», когда в упаковке',
            chips: [
              for (final count in AppSettings.lowStockChoices)
                AppChip(
                  label: '$count ед.',
                  selected: settings.lowStockThreshold == count,
                  onTap: () => saveSettings(
                    context,
                    ref,
                    (s) => s.copyWith(lowStockThreshold: count),
                  ),
                ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Сейчас под условия попадают',
          footnote: 'Пороги одинаковы для карточек, фильтров и сводки.',
          child: SettingsGroup(
            children: [
              if (matches.total == 0)
                SettingsRow(
                  icon: 'box',
                  iconColor: palette.success,
                  title: 'Ничего',
                  subtitle: 'Сроки и остатки в порядке',
                  trailing: SettingsTrailing.none,
                )
              else
                SettingsRow(
                  icon: 'box',
                  iconColor: palette.warning,
                  title: matches.title,
                  subtitle: matches.details,
                  onTap: () => context.go(AppRoutes.kits),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// White «card» with a Body/Medium question and wrapping chips (8 pt gaps).
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.title, required this.chips});
  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) => SettingsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    ),
  );
}
