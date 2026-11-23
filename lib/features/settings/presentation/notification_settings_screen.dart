import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_segmented.dart';
import 'package:aptechka/core/ui/settings_list.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/onboarding/presentation/onboarding_widgets.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:aptechka/features/settings/domain/settings_summary.dart';
import 'package:aptechka/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// «Настройки / Уведомления» (1157:24014): intake reminders and the kit
/// digest. The «запрещены в iPhone» variant (1157:24166) needs the system
/// permission state, which the app does not read yet.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appControllerProvider).asData?.value.settings;
    if (settings == null) {
      return const SettingsPage(title: 'Уведомления', children: []);
    }
    return SettingsPage(
      title: 'Уведомления',
      children: [
        SettingsSection(
          footnote:
              'О каждом приёме по расписанию курса. Время и дозу меняют '
              'в курсе, в разделе «Лечение».',
          child: SettingsGroup(
            children: [
              SettingsRow(
                icon: 'pill',
                title: 'Приём лекарств',
                trailing: SettingsTrailing.toggle,
                toggled: settings.intakeSchedule,
                onChanged: (value) => saveSettings(
                  context,
                  ref,
                  (s) => s.copyWith(intakeSchedule: value),
                ),
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Проверка аптечек',
          footnote:
              'Одно уведомление, только если что-то истекает или '
              'заканчивается. Личное лечение в сводку не попадает.',
          child: SettingsGroup(
            children: [
              SettingsRow(
                icon: 'calendar',
                title: 'Сводка по аптечкам',
                trailing: SettingsTrailing.toggle,
                toggled: settings.digestEnabled,
                onChanged: (value) => saveSettings(
                  context,
                  ref,
                  (s) => s.copyWith(digestEnabled: value),
                ),
              ),
              SettingsRow(
                title: 'Когда присылать',
                value: digestWhenLabel(settings),
                onTap: () => context.push(AppRoutes.settingsDigest),
              ),
              SettingsRow(
                title: 'Что считать проблемой',
                subtitle: thresholdsLabel(settings),
                onTap: () => context.push(AppRoutes.settingsThresholds),
              ),
            ],
          ),
        ),
        const SettingsSection(
          title: 'Так выглядит сводка',
          child: PushPreview(
            width: null,
            title: 'Проверьте аптечки',
            body: '2 лекарства скоро истекут, 1 заканчивается',
          ),
        ),
      ],
    );
  }
}

/// «Настройки / Когда присылать сводку» (1157:24312).
class DigestScheduleScreen extends ConsumerWidget {
  const DigestScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appControllerProvider).asData?.value.settings;
    if (settings == null) {
      return const SettingsPage(title: 'Когда присылать', children: []);
    }
    void save(AppSettings Function(AppSettings) update) =>
        saveSettings(context, ref, update);
    return SettingsPage(
      title: 'Когда присылать',
      children: [
        SettingsSection(
          title: 'Как часто',
          child: AppSegmented(
            small: true,
            labels: const ['Каждый день', 'Раз в неделю', 'Раз в месяц'],
            selected: settings.digestFrequency.index,
            onChanged: (index) => save(
              (s) => s.copyWith(digestFrequency: DigestFrequency.values[index]),
            ),
          ),
        ),
        if (settings.digestFrequency == DigestFrequency.weekly)
          SettingsSection(
            title: 'День недели',
            child: Row(
              children: [
                for (final (i, day) in weekdayShort.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _DayButton(
                      label: day,
                      selected: settings.digestWeekday == i + 1,
                      onTap: () =>
                          save((s) => s.copyWith(digestWeekday: i + 1)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        SettingsSection(
          title: 'Время',
          child: SettingsGroup(
            children: [
              SettingsRow(
                title: 'Время',
                value: timeLabel(settings.digestMinutes),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: settings.digestMinutes ~/ 60,
                      minute: settings.digestMinutes % 60,
                    ),
                  );
                  if (picked != null && context.mounted) {
                    save(
                      (s) => s.copyWith(
                        digestMinutes: picked.hour * 60 + picked.minute,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        StatusBanner(
          tone: StatusBannerTone.info,
          title: nextDigestLabel(nextDigest(settings, DateTime.now())),
          text: 'Придёт, только если в аптечках есть что проверить.',
        ),
      ],
    );
  }
}

/// A day of «День недели» (1157:24392): 44 pt tall, radius 12, white or
/// `surface/choice` when selected.
class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.surfaceChoice : palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              style: AppTypography.labelLarge.copyWith(
                color: selected ? palette.textOnAccent : palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
