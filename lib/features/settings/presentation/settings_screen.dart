import 'package:aptechka/app/app_info.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/settings_list.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/settings/data/backup_files.dart';
import 'package:aptechka/features/settings/domain/settings_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// «Настройки / Главная — без входа» (1155:23726). The cloud row and the
/// account variant (1155:23941) wait for a real cloud.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: AsyncValueView(
          value: ref.watch(appControllerProvider),
          data: (state) => ValueListenableBuilder<DateTime?>(
            valueListenable: BackupStore.lastSavedAt,
            builder: (context, lastSaved, _) {
              final settings = state.settings;
              final now = DateTime.now();
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.maxContentWidth,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 132),
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Настройки',
                          style: AppTypography.h1.copyWith(
                            color: palette.textHeading,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (lastSaved == null) ...[
                        StatusBanner(
                          tone: StatusBannerTone.warning,
                          title: 'Данные только на этом телефоне',
                          text:
                              'Если удалить приложение или сменить телефон, '
                              'аптечки и история приёма пропадут.',
                          actionLabel: 'Сохранить данные',
                          onAction: () =>
                              context.push(AppRoutes.settingsBackup),
                        ),
                        const SizedBox(height: 24),
                      ],
                      SettingsSection(
                        title: 'Напоминания и предупреждения',
                        child: SettingsGroup.icons(
                          children: [
                            SettingsRow(
                              icon: 'pill',
                              title: 'Приём лекарств',
                              value: switchLabel(settings.intakeSchedule),
                              onTap: () =>
                                  context.push(AppRoutes.settingsNotifications),
                            ),
                            SettingsRow(
                              icon: 'calendar',
                              title: 'Проверка аптечек',
                              value: digestScheduleLabel(settings),
                              onTap: () =>
                                  context.push(AppRoutes.settingsNotifications),
                            ),
                            SettingsRow(
                              icon: 'clock',
                              iconColor: palette.warning,
                              title: 'Когда предупреждать',
                              subtitle: thresholdsLabel(settings),
                              onTap: () =>
                                  context.push(AppRoutes.settingsThresholds),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SettingsSection(
                        title: 'Данные',
                        child: SettingsGroup.icons(
                          children: [
                            SettingsRow(
                              icon: 'file',
                              iconColor: palette.success,
                              title: 'Резервная копия',
                              value: lastBackupLabel(lastSaved, now),
                              onTap: () =>
                                  context.push(AppRoutes.settingsBackup),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SettingsGroup.icons(
                        children: [
                          SettingsRow(
                            icon: 'appearance',
                            iconColor: palette.surfaceChoice,
                            title: 'Оформление',
                            value: appearanceLabel(settings.appearance),
                            onTap: () =>
                                context.push(AppRoutes.settingsAppearance),
                          ),
                          SettingsRow(
                            icon: 'question',
                            iconColor: palette.iconTileNeutral,
                            title: 'Помощь',
                            onTap: () => context.push(AppRoutes.settingsHelp),
                          ),
                          SettingsRow(
                            icon: 'info',
                            iconColor: palette.iconTileNeutral,
                            title: 'О приложении',
                            value: AppInfo.version,
                            onTap: () => context.push(AppRoutes.settingsAbout),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
