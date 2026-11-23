import 'dart:math' as math;

import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/core/ui/settings_list.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/settings/data/backup_files.dart';
import 'package:aptechka/features/settings/domain/backup_codec.dart';
import 'package:aptechka/features/settings/domain/settings_summary.dart';
import 'package:aptechka/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What «Копия сохранена» (1159:24653) shows.
class BackupSaved {
  const BackupSaved({
    required this.fileName,
    required this.savedAt,
    required this.summary,
  });
  final String fileName;
  final DateTime savedAt;
  final BackupSummary summary;
}

/// A picked backup file: read successfully, or not.
class RestorePick {
  const RestorePick.file(BackupFile this.file);
  const RestorePick.failed() : file = null;

  /// `null` when the file could not be read.
  final BackupFile? file;
}

/// Saves the current data as a `.json` file. `null` when the person closed
/// the share sheet or saving failed (a toast says so).
Future<BackupSaved?> saveBackupFile(BuildContext context, WidgetRef ref) async {
  final state = ref.read(appControllerProvider).requireValue;
  final now = DateTime.now();
  final fileName = BackupCodec.fileName(now);
  final bool saved;
  try {
    saved = await ref
        .read(backupFilesProvider)
        .save(BackupCodec.encode(state, createdAt: now), fileName);
  } catch (_) {
    if (context.mounted) {
      showAppToast(context, 'Не удалось сохранить копию. Попробуйте ещё раз.');
    }
    return null;
  }
  if (!saved) return null;
  await BackupStore.markSaved(now);
  return BackupSaved(
    fileName: fileName,
    savedAt: now,
    summary: BackupSummary.of(state),
  );
}

/// Opens the file picker; `null` when nothing was picked.
Future<RestorePick?> pickBackupFile(WidgetRef ref) async {
  final String? source;
  try {
    source = await ref.read(backupFilesProvider).pick();
  } catch (_) {
    return const RestorePick.failed();
  }
  if (source == null) return null;
  try {
    return RestorePick.file(BackupCodec.decodeFile(source));
  } on FormatException {
    return const RestorePick.failed();
  }
}

/// «Настройки / Сохранность данных — без входа» (1159:24527). The «В облаке»
/// card waits for a real cloud; the file copy works.
class DataSafetyScreen extends ConsumerWidget {
  const DataSafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return SettingsPage(
      title: 'Сохранность данных',
      children: [
        const StatusBanner(
          tone: StatusBannerTone.warning,
          title: 'Сейчас данные только на этом телефоне',
          text:
              'Если удалить приложение или потерять телефон, аптечки и '
              'история приёма пропадут.',
        ),
        SettingsSection(
          title: 'Как сохранить',
          child: SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SettingsIconTile(
                      'file',
                      color: palette.success,
                      size: 36,
                      radius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'В файл',
                        style: AppTypography.bodyLarge.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Без аккаунта. Сохраняете вручную и сами решаете, где '
                  'хранить файл.',
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                AppButton.secondary(
                  label: 'Создать копию',
                  onPressed: () async {
                    final saved = await saveBackupFile(context, ref);
                    if (saved != null && context.mounted) {
                      context.push(AppRoutes.settingsBackupSaved, extra: saved);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        SettingsSection(
          footnote:
              'В копии: аптечки, упаковки, курсы, история приёма и '
              'настройки. Файл не зашифрован.',
          child: SettingsGroup(
            children: [
              SettingsRow(
                icon: 'restore',
                iconColor: palette.iconTileNeutral,
                title: 'Восстановить из файла',
                subtitle: 'Заменит данные на этом телефоне',
                onTap: () async {
                  final pick = await pickBackupFile(ref);
                  if (pick != null && context.mounted) {
                    context.push(AppRoutes.settingsRestore, extra: pick);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// «Настройки / Копия сохранена» (1159:24653).
class BackupSavedScreen extends StatelessWidget {
  const BackupSavedScreen({required this.saved, super.key});
  final BackupSaved saved;

  @override
  Widget build(BuildContext context) {
    final summary = saved.summary;
    return SettingsPage(
      title: 'Резервная копия',
      children: [
        StatusBanner(
          tone: StatusBannerTone.ok,
          title: 'Копия сохранена',
          text: '${saved.fileName} · ${savedAtLabel(saved.savedAt)}',
        ),
        SettingsSection(
          title: 'Что в копии',
          footnote:
              'Храните файл в надёжном месте: в нём ваши данные о здоровье.',
          child: SettingsCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _ValueRow('Аптечки', '${summary.kits}'),
                _ValueRow('Упаковки', '${summary.packages}'),
                _ValueRow('Курсы', '${summary.courses}'),
                _ValueRow(
                  'История приёма',
                  summary.historyLabel(saved.savedAt),
                ),
                const _ValueRow('Настройки', 'да'),
              ],
            ),
          ),
        ),
        AppButton(
          label: 'Готово',
          onPressed: () => context.go(AppRoutes.settings),
        ),
      ],
    );
  }
}

/// A Body/Medium «label … value» row of «Что в копии», 8 pt vertical padding.
class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodyMedium.copyWith(
      color: context.palette.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text(value, textAlign: TextAlign.end, style: style),
        ],
      ),
    );
  }
}

/// «Настройки / Восстановление»: confirmation (1159:24764), unreadable file
/// (1159:24876) and done (1159:24962).
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({required this.pick, super.key});
  final RestorePick pick;

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  late RestorePick _pick = widget.pick;
  BackupSummary? _restored;
  bool _saveFirst = true;
  bool _busy = false;

  Future<void> _pickAgain() async {
    final pick = await pickBackupFile(ref);
    if (pick != null && mounted) setState(() => _pick = pick);
  }

  Future<void> _replace(BackupFile file) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_saveFirst) {
        final saved = await saveBackupFile(context, ref);
        // Without the promised copy the data stays as it is.
        if (saved == null) {
          if (mounted) {
            showAppToast(context, 'Копия не сохранена, данные не заменены');
          }
          return;
        }
      }
      await ref.read(appControllerProvider.notifier).restoreBackup(file.state);
      if (mounted) {
        setState(() => _restored = BackupSummary.of(file.state));
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, 'Не удалось восстановить данные');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restored = _restored;
    final file = _pick.file;
    return SettingsPage(
      title: 'Восстановление',
      children: restored != null
          ? _done(restored)
          : file == null
          ? _failed()
          : _confirm(file),
    );
  }

  List<Widget> _confirm(BackupFile file) {
    final palette = context.palette;
    final current = ref.watch(appControllerProvider).asData?.value;
    final now = current == null ? null : BackupSummary.of(current);
    final incoming = BackupSummary.of(file.state);
    final createdAt = file.createdAt;
    return [
      SettingsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Заменить данные на этом телефоне?',
              style: AppTypography.h3.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              createdAt == null
                  ? 'Всё, что сейчас в приложении, заменится содержимым файла.'
                  : 'Всё, что сейчас в приложении, заменится содержимым '
                        'файла от ${compactDate(createdAt)}.',
              style: AppTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
      SettingsSection(
        title: 'Что изменится',
        child: SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final column = math.min(92.0, (constraints.maxWidth - 16) / 3.5);
              return Column(
                children: [
                  _CompareRow.header(column: column),
                  _CompareRow(
                    'Аптечки',
                    now?.kits,
                    incoming.kits,
                    column: column,
                  ),
                  _CompareRow(
                    'Упаковки',
                    now?.packages,
                    incoming.packages,
                    column: column,
                  ),
                  _CompareRow(
                    'Курсы',
                    now?.courses,
                    incoming.courses,
                    column: column,
                  ),
                ],
              );
            },
          ),
        ),
      ),
      SettingsGroup(
        children: [
          SettingsRow(
            title: 'Сначала сохранить текущие',
            subtitle: 'Копия в файл — если передумаете',
            trailing: SettingsTrailing.toggle,
            toggled: _saveFirst,
            onChanged: (value) => setState(() => _saveFirst = value),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton.destructive(
            label: 'Заменить данные',
            onPressed: _busy ? null : () => _replace(file),
          ),
          const SizedBox(height: 12),
          AppButton.secondary(
            label: 'Отмена',
            onPressed: _busy ? null : () => context.pop(),
          ),
        ],
      ),
    ];
  }

  List<Widget> _failed() => [
    const StatusBanner(
      tone: StatusBannerTone.fail,
      title: 'Не удалось прочитать файл',
      text:
          'Файл повреждён или создан в более новой версии приложения. '
          'Ваши данные не изменились.',
    ),
    SettingsSection(
      footnote:
          'Подходят файлы .json, созданные в «Аптечкине». Если копию сделали в '
          'новой версии — обновите приложение.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(label: 'Выбрать другой файл', onPressed: _pickAgain),
          const SizedBox(height: 12),
          AppButton.secondary(label: 'Отмена', onPressed: () => context.pop()),
        ],
      ),
    ),
  ];

  List<Widget> _done(BackupSummary restored) {
    final palette = context.palette;
    return [
      StatusBanner(
        tone: StatusBannerTone.ok,
        title: 'Данные восстановлены',
        text: '${restored.contentsLabel}. Настройки из копии применены.',
      ),
      SettingsSection(
        title: 'Проверьте на этом телефоне',
        child: SettingsGroup(
          children: [
            SettingsRow(
              icon: 'bell',
              title: 'Уведомления',
              subtitle: 'Приём лекарств и сводка',
              value: 'Проверить',
              valueColor: palette.brandPrimary,
              onTap: () => context.push(AppRoutes.settingsNotifications),
            ),
          ],
        ),
      ),
      AppButton(
        label: 'Открыть аптечки',
        onPressed: () => context.go(AppRoutes.kits),
      ),
    ];
  }
}

/// A row of «Что изменится»: label, «Сейчас» and «Из файла» columns.
class _CompareRow extends StatelessWidget {
  const _CompareRow(this.label, this.now, this.incoming, {required this.column})
    : header = false;
  const _CompareRow.header({required this.column})
    : label = '',
      now = null,
      incoming = null,
      header = true;

  final String label;
  final int? now;
  final int? incoming;
  final double column;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppTypography.labelLarge.copyWith(
      color: palette.textSecondary,
    );
    final strong = AppTypography.bodyMedium.copyWith(
      color: palette.textPrimary,
    );
    Widget cell(String text, TextStyle style) => SizedBox(
      width: column,
      child: Text(text, textAlign: TextAlign.end, style: style),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: strong)),
          const SizedBox(width: 8),
          cell(
            header ? 'Сейчас' : '${now ?? '—'}',
            header
                ? caption
                : AppTypography.paragraph.copyWith(
                    color: palette.textSecondary,
                  ),
          ),
          const SizedBox(width: 8),
          cell(
            header ? 'Из файла' : '${incoming ?? '—'}',
            header ? caption : strong,
          ),
        ],
      ),
    );
  }
}
