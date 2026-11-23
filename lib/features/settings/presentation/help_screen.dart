import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_sheet.dart';
import 'package:aptechka/core/ui/settings_list.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One «Частые вопросы» answer: text and the button that opens the section.
class _Answer {
  const _Answer(this.question, this.text, this.action, this.open);
  final String question;
  final String text;
  final String action;
  final void Function(BuildContext context) open;
}

/// «Настройки / Помощь» (1161:25365). The answers are not drawn in Figma;
/// each opens in a sheet with a button to the right section.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days =
        ref
            .watch(appControllerProvider)
            .asData
            ?.value
            .settings
            .expiryWarningDays ??
        30;
    final answers = [
      _Answer(
        'Как перенести аптечку на новый телефон',
        'Сохраните резервную копию в файл и перенесите его на новый телефон — '
            'например, через мессенджер или облачный диск. На новом телефоне '
            'откройте «Настройки» → «Резервная копия» → «Восстановить из файла».',
        'Создать копию',
        (context) => context.push(AppRoutes.settingsBackup),
      ),
      _Answer(
        'Почему не приходят напоминания',
        'Напоминания о приёме показываются в разделе «Лечение»: системные '
            'уведомления на телефоне пока не подключены. Проверьте, что '
            '«Приём лекарств» включён, а в курсе указано время приёма.',
        'Открыть уведомления',
        (context) => context.push(AppRoutes.settingsNotifications),
      ),
      _Answer(
        'Как работает общая аптечка',
        'Общий доступ к аптечке пока готовится. Сейчас аптечки хранятся только '
            'на этом телефоне. Чтобы передать их другому человеку, сохраните '
            'копию в файл — её можно восстановить на его телефоне.',
        'Открыть аптечки',
        (context) => context.go(AppRoutes.kits),
      ),
      _Answer(
        'Когда лекарство «Скоро истекает»',
        'Когда до конца срока годности остаётся меньше выбранного порога — '
            'сейчас за ${russianCount(days, 'день', 'дня', 'дней')}. Если '
            'указан срок после вскрытия, учитываем и его.',
        'Изменить порог',
        (context) => context.push(AppRoutes.settingsThresholds),
      ),
      _Answer(
        'Штрихкод не распознаётся',
        'Наведите камеру на штрихкод или квадратный код DataMatrix на '
            'упаковке и держите телефон ровно, при хорошем свете. Если код '
            'всё равно не читается, найдите лекарство по названию.',
        'Найти по названию',
        (context) => context.push(AppRoutes.medicineSelect),
      ),
    ];
    return SettingsPage(
      title: 'Помощь',
      children: [
        SettingsSection(
          title: 'Частые вопросы',
          footnote:
              'В каждом ответе есть кнопка, которая открывает нужный раздел '
              'приложения.',
          child: SettingsGroup(
            children: [
              for (final answer in answers)
                SettingsRow(
                  title: answer.question,
                  onTap: () => _show(context, answer),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _show(BuildContext context, _Answer answer) => showAppSheet<void>(
    context: context,
    title: answer.question,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          answer.text,
          style: AppTypography.paragraph.copyWith(
            color: sheetContext.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: answer.action,
          onPressed: () {
            Navigator.of(sheetContext).pop();
            answer.open(context);
          },
        ),
      ],
    ),
  );
}
