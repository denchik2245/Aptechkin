import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/settings_list.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:aptechka/features/settings/domain/settings_summary.dart';
import 'package:aptechka/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// «Настройки / Оформление» (1159:24373): theme, text size and a sample
/// card that shows the chosen size right away.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final settings = ref.watch(appControllerProvider).asData?.value.settings;
    if (settings == null) {
      return const SettingsPage(title: 'Оформление', children: []);
    }
    return SettingsPage(
      title: 'Оформление',
      children: [
        SettingsSection(
          title: 'Тема',
          child: SettingsGroup(
            children: [
              for (final appearance in AppAppearance.values)
                SettingsRow(
                  title: appearanceLabel(appearance, onDevice: true),
                  trailing: appearance == settings.appearance
                      ? SettingsTrailing.check
                      : SettingsTrailing.none,
                  onTap: () => saveSettings(
                    context,
                    ref,
                    (s) => s.copyWith(appearance: appearance),
                  ),
                ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Размер текста',
          child: SettingsGroup(
            children: [
              for (final scale in AppSettings.textScaleChoices)
                SettingsRow(
                  title: textScaleLabel(scale),
                  trailing: scale == settings.textScale
                      ? SettingsTrailing.check
                      : SettingsTrailing.none,
                  onTap: () => saveSettings(
                    context,
                    ref,
                    (s) => s.copyWith(textScale: scale),
                  ),
                ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Пример',
          footnote: 'Действует только на этом устройстве.',
          child: SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Нурофен, 200 мг',
                  style: AppTypography.bodyLarge.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Дом · ящик в ванной · 8 таблеток',
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Срок истекает 25 ноября',
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
