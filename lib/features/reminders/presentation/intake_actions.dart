import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_chip.dart';
import 'package:aptechka/core/ui/app_select.dart';
import 'package:aptechka/core/ui/app_sheet.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/core/ui/radio_card.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/reminders/domain/intake_marks.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The intake sheets of «Лечение / 2 · Отметки приёма» (1186:21991). Each
/// returns what changed, so «Сегодня» can show its message.

String _time(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

/// Runs [change] and describes it; a toast tells when saving failed.
Future<IntakeOutcome?> _apply(
  BuildContext context,
  WidgetRef ref,
  TreatmentIntake intake,
  IntakeOutcomeKind kind,
  Future<void> Function(AppController controller) change,
) async {
  final before = ref.read(appControllerProvider).requireValue;
  try {
    await change(ref.read(appControllerProvider.notifier));
  } catch (_) {
    if (context.mounted) showAppToast(context, 'Не удалось сохранить отметку');
    return null;
  }
  final after = ref.read(appControllerProvider).requireValue;
  return outcomeOf(before, after, intake, kind, now: DateTime.now());
}

/// «Принял» on the «intake now» card and «Уже принял».
Future<IntakeOutcome?> markTaken(
  BuildContext context,
  WidgetRef ref,
  TreatmentIntake intake, {
  DateTime? at,
}) => _apply(
  context,
  ref,
  intake,
  IntakeOutcomeKind.taken,
  (c) => c.recordIntake(
    intake.reminder.id,
    IntakeStatus.taken,
    scheduledDate: intake.date,
    occurredAt: at,
  ),
);

/// «Отменить» in a message and «Отменить факт приёма».
Future<IntakeOutcome?> undoMark(
  BuildContext context,
  WidgetRef ref,
  TreatmentIntake intake,
) => _apply(
  context,
  ref,
  intake,
  IntakeOutcomeKind.undone,
  (c) => c.undoIntake(intake.reminder.id, intake.date),
);

/// A row tap: «Исправить отметку» for a taken intake, otherwise «Когда
/// приняли?». [mode] `defer` and `skip` open those sheets directly.
Future<IntakeOutcome?> showIntakeAction(
  BuildContext context,
  WidgetRef ref,
  TreatmentIntake intake, {
  String mode = 'edit',
}) => switch (mode) {
  'defer' => showDeferSheet(context, ref, intake),
  'skip' => showSkipSheet(context, ref, intake),
  _ =>
    intake.record?.status == IntakeStatus.taken
        ? showEditMarkSheet(context, ref, intake)
        : showMarkSheet(context, ref, intake),
};

/// «Я · Ибупрофен, 200 мг» and Body/Small lines under it.
class _Heading extends StatelessWidget {
  const _Heading(this.title, this.lines);
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lines.join('\n'),
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A Body/Small `text/secondary` note.
Widget _note(BuildContext context, String text) => Text(
  text,
  style: AppTypography.bodySmall.copyWith(color: context.palette.textSecondary),
);

/// Children of a sheet body 12 pt apart.
Widget _column(List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (i, child) in children.indexed) ...[
      if (i > 0) const SizedBox(height: 12),
      child,
    ],
  ],
);

sealed class _DeferResult {}

class _DeferPicked extends _DeferResult {
  _DeferPicked(this.until);
  final DateTime until;
}

/// «Отложить приём» (1037:19149) and, when the new time reaches the next
/// dose, «Проверьте время» (1037:20378).
Future<IntakeOutcome?> showDeferSheet(
  BuildContext context,
  WidgetRef ref,
  TreatmentIntake intake,
) async {
  final state = ref.read(appControllerProvider).requireValue;
  final next = nextSameDrug(state, intake);
  int? chip = deferChoices.first;
  var until = deferUntil(DateTime.now(), chip);
  while (context.mounted) {
    final picked = await showAppSheet<_DeferResult>(
      context: context,
      title: 'Отложить приём',
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) => _column([
          _Heading(intakeHeading(intake), [plannedLine(intake)]),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in deferChoices)
                AppChip(
                  label: deferChoiceLabel(minutes),
                  selected: chip == minutes,
                  onTap: () => setState(() {
                    chip = minutes;
                    until = deferUntil(DateTime.now(), minutes);
                  }),
                ),
            ],
          ),
          AppSelect(
            small: true,
            label: 'Напомнить в',
            value: _time(until),
            onTap: () async {
              final time = await showTimePicker(
                context: sheetContext,
                initialTime: TimeOfDay.fromDateTime(until),
              );
              if (time != null) {
                setState(() {
                  chip = null;
                  until = deferAt(DateTime.now(), time.hour, time.minute);
                });
              }
            },
          ),
          _note(sheetContext, deferNote(next, DateTime.now())),
          AppButton(
            label: 'Напомнить в ${_time(until)}',
            onPressed: () => Navigator.pop(sheetContext, _DeferPicked(until)),
          ),
        ]),
      ),
    );
    if (picked is! _DeferPicked || !context.mounted) return null;
    if (!deferOverlaps(picked.until, next)) {
      return _apply(
        context,
        ref,
        intake,
        IntakeOutcomeKind.deferred,
        (c) => c.recordIntake(
          intake.reminder.id,
          IntakeStatus.deferred,
          scheduledDate: intake.date,
          deferredUntil: picked.until,
        ),
      );
    }
    final check = await showAppSheet<String>(
      context: context,
      title: 'Проверьте время',
      builder: (sheetContext) => _column([
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                intakeHeading(intake),
                style: AppTypography.bodyMedium.copyWith(
                  color: sheetContext.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              AppSelect(
                small: true,
                label: 'Напомнить в',
                value: _time(picked.until),
                onTap: () => Navigator.pop(sheetContext, 'again'),
              ),
            ],
          ),
        ),
        StatusBanner(
          tone: StatusBannerTone.warning,
          title: 'Позже следующего приёма',
          text:
              'Следующая доза по плану в ${_time(next!)}. Приложение не будет '
              'объединять дозы или менять схему.',
        ),
        AppButton(
          label: 'Выбрать другое время',
          onPressed: () => Navigator.pop(sheetContext, 'again'),
        ),
        AppLinkButton(
          label: 'Уточнить факт приёма',
          small: true,
          onPressed: () => Navigator.pop(sheetContext, 'mark'),
        ),
      ]),
    );
    if (!context.mounted) return null;
    if (check == 'mark') return showMarkSheet(context, ref, intake);
    if (check != 'again') return null;
  }
  return null;
}

/// «Пропустить приём?» (1037:19267).
Future<IntakeOutcome?> showSkipSheet(
  BuildContext context,
  WidgetRef ref,
  TreatmentIntake intake,
) async {
  final skip = await showAppSheet<bool>(
    context: context,
    title: 'Пропустить приём?',
    builder: (sheetContext) => _column([
      _Heading(intakeHeading(intake), [
        skipLine(intake, DateTime.now()),
        'Сохранится пропуск. Остаток не изменится.',
      ]),
      AppButton(
        label: 'Пропустить',
        onPressed: () => Navigator.pop(sheetContext, true),
      ),
      Text(
        'Причину можно добавить позже',
        style: AppTypography.labelLarge.copyWith(
          color: sheetContext.palette.brandPrimary,
        ),
      ),
      AppButton.secondary(
        label: 'Вернуться к приёму',
        onPressed: () => Navigator.pop(sheetContext, false),
      ),
    ]),
  );
  if (skip != true || !context.mounted) return null;
  return _apply(
    context,
    ref,
    intake,
    IntakeOutcomeKind.skipped,
    (c) => c.recordIntake(
      intake.reminder.id,
      IntakeStatus.skipped,
      scheduledDate: intake.date,
    ),
  );
}

/// «Причина пропуска» (1037:19826): optional, nothing chosen in advance.
Future<void> showReasonSheet(
  BuildContext context,
  WidgetRef ref,
  TreatmentIntake intake,
) async {
  String? reason;
  final action = await showAppSheet<String>(
    context: context,
    title: 'Причина пропуска',
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => _column([
        _note(
          sheetContext,
          '${intakeHeading(intake)} · ${_time(intake.plannedAt)}',
        ),
        _note(
          sheetContext,
          'Необязательно. Ни один вариант не выбран заранее.',
        ),
        for (final value in skipReasons)
          RadioCard(
            title: value,
            selected: reason == value,
            onTap: () => setState(() => reason = value),
          ),
        AppButton(
          label: 'Сохранить причину',
          onPressed: reason == null
              ? null
              : () => Navigator.pop(sheetContext, 'save'),
        ),
        AppLinkButton(
          label: 'Оставить без причины',
          small: true,
          onPressed: () => Navigator.pop(sheetContext),
        ),
        if (intake.course != null)
          AppLinkButton(
            label: 'Изменилось назначение — изменить курс',
            small: true,
            onPressed: () => Navigator.pop(sheetContext, 'course'),
          ),
      ]),
    ),
  );
  if (!context.mounted) return;
  if (action == 'course') {
    context.push(AppRoutes.treatmentEdit(intake.course!.id));
  } else if (action == 'save' && reason != null) {
    await _apply(
      context,
      ref,
      intake,
      IntakeOutcomeKind.skipped,
      (c) => c.recordIntake(
        intake.reminder.id,
        IntakeStatus.skipped,
        scheduledDate: intake.date,
        reason: reason!,
      ),
    );
  }
}

enum _Mark { plan, other, none }

/// Picks a time on the intake's day; the date never changes.
Future<DateTime?> _pickTime(
  BuildContext context,
  DateTime day,
  DateTime current,
) async {
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// «Когда приняли?» (1037:19360) for an unmarked, deferred or skipped
/// intake.
Future<IntakeOutcome?> showMarkSheet(
  BuildContext context,
  WidgetRef ref,
  TreatmentIntake intake,
) async {
  var mark = _Mark.plan;
  final now = DateTime.now();
  var at = treatmentDayEnd(intake.date, now);
  final save = await showAppSheet<bool>(
    context: context,
    title: 'Когда приняли?',
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => _column([
        _Heading(intakeHeading(intake), [plannedDayLine(intake, now)]),
        RadioCard(
          title: 'Принял по плану в ${_time(intake.plannedAt)}',
          selected: mark == _Mark.plan,
          onTap: () => setState(() => mark = _Mark.plan),
        ),
        RadioCard(
          title: 'Принял в другое время',
          selected: mark == _Mark.other,
          onTap: () => setState(() => mark = _Mark.other),
          extra: ChoiceRow(
            label: 'Фактически',
            value: actualTimeLabel(at, now),
            onTap: () async {
              final picked = await _pickTime(sheetContext, intake.date, at);
              if (picked != null) setState(() => at = picked);
            },
          ),
        ),
        RadioCard(
          title: 'Не принимал',
          selected: mark == _Mark.none,
          onTap: () => setState(() => mark = _Mark.none),
        ),
        _note(sheetContext, markNote(intake)),
        AppButton(
          label: 'Сохранить приём',
          onPressed: () => Navigator.pop(sheetContext, true),
        ),
      ]),
    ),
  );
  if (save != true || !context.mounted) return null;
  if (mark == _Mark.none) {
    return _apply(
      context,
      ref,
      intake,
      IntakeOutcomeKind.skipped,
      (c) => c.recordIntake(
        intake.reminder.id,
        IntakeStatus.skipped,
        scheduledDate: intake.date,
      ),
    );
  }
  final taken = mark == _Mark.plan ? intake.plannedAt : at;
  if (taken.isAfter(DateTime.now())) {
    showAppToast(context, 'Время приёма ещё не наступило');
    return null;
  }
  return markTaken(context, ref, intake, at: taken);
}

/// The «Фактически» time to start from: now on today's intake, the planned
/// time on an earlier day.
DateTime treatmentDayEnd(DateTime day, DateTime now) =>
    DateTime(day.year, day.month, day.day) ==
        DateTime(now.year, now.month, now.day)
    ? now
    : DateTime(day.year, day.month, day.day, 12);

/// «Исправить отметку» (1037:19486) for a taken intake.
Future<IntakeOutcome?> showEditMarkSheet(
  BuildContext context,
  WidgetRef ref,
  TreatmentIntake intake,
) async {
  var at = intake.record?.occurredAt ?? intake.plannedAt;
  final now = DateTime.now();
  final repeat = noRepeatDeductionText(intake);
  final action = await showAppSheet<String>(
    context: context,
    title: 'Исправить отметку',
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => _column([
        _Heading(intakeHeading(intake), [markedLine(intake)]),
        AppSelect(
          small: true,
          label: 'Фактически',
          value: actualTimeLabel(at, now),
          onTap: () async {
            final picked = await _pickTime(sheetContext, intake.date, at);
            if (picked != null) setState(() => at = picked);
          },
        ),
        if (repeat != null)
          StatusBanner(
            tone: StatusBannerTone.info,
            title: 'Повторного списания не будет',
            text: repeat,
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Сохранить время',
              onPressed: () => Navigator.pop(sheetContext, 'save'),
            ),
            const SizedBox(height: 8),
            AppButton.secondary(
              label: 'Отменить факт приёма',
              onPressed: () => Navigator.pop(sheetContext, 'undo'),
            ),
          ],
        ),
      ]),
    ),
  );
  if (!context.mounted) return null;
  if (action == 'undo') return undoMark(context, ref, intake);
  if (action != 'save') return null;
  if (at.isAfter(DateTime.now())) {
    showAppToast(context, 'Время приёма ещё не наступило');
    return null;
  }
  return markTaken(context, ref, intake, at: at);
}
