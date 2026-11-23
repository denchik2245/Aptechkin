import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/package_detail.dart';
import 'package:aptechka/features/inventory/domain/package_status.dart';

import 'medication_reminder.dart';
import 'treatment_course.dart';
import 'treatment_schedule.dart';
import 'treatment_today.dart';

/// Logic of «Лечение / 2 · Отметки приёма» (1186:21991).

String _time(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

/// «Ибупрофен, 200 мг»
String intakeDrugTitle(TreatmentIntake intake) {
  final m = intake.medicine;
  final name = readableDrugName(m.name);
  return m.dosage.isEmpty ? name : '$name, ${m.dosage}';
}

/// «Я · Ибупрофен, 200 мг» — the heading of the intake sheets.
String intakeHeading(TreatmentIntake intake) =>
    '${intakePerson(intake)} · ${intakeDrugTitle(intake)}';

/// «сегодня», «вчера» or «28 октября».
String _dayWord(DateTime day, DateTime today) {
  final d = treatmentDay(day);
  final t = treatmentDay(today);
  if (d == t) return 'сегодня';
  if (d == DateTime(t.year, t.month, t.day - 1)) return 'вчера';
  return shortDate(d);
}

/// «По плану в 13:00 · 1 таблетка» («Отложить приём», 1037:19149).
String plannedLine(TreatmentIntake intake) =>
    'По плану в ${_time(intake.plannedAt)} · ${intake.reminder.dose}';

/// «По плану сегодня в 08:00 · 1 таблетка» («Когда приняли?», 1037:19360).
String plannedDayLine(TreatmentIntake intake, DateTime today) =>
    'По плану ${_dayWord(intake.date, today)} в ${_time(intake.plannedAt)}'
    ' · ${intake.reminder.dose}';

/// «Сегодня в 13:00 · 1 таблетка» («Пропустить приём?», 1037:19267).
String skipLine(TreatmentIntake intake, DateTime today) {
  final day = _dayWord(intake.date, today);
  return '${day[0].toUpperCase()}${day.substring(1)} в '
      '${_time(intake.plannedAt)} · ${intake.reminder.dose}';
}

/// «По плану в 08:00 · отмечено в 08:04» («Исправить отметку», 1037:19486).
String markedLine(TreatmentIntake intake) =>
    'По плану в ${_time(intake.plannedAt)} · отмечено в '
    '${_time(intake.record?.occurredAt ?? intake.plannedAt)}';

/// «Сегодня, 09:30» / «28 октября, 09:30» — the «Фактически» value.
String actualTimeLabel(DateTime at, DateTime today) {
  final day = _dayWord(at, today);
  return '${day[0].toUpperCase()}${day.substring(1)}, ${_time(at)}';
}

/// «Отложить приём»: the chips, in minutes.
const deferChoices = [15, 30, 60];

/// «15 минут», «1 час».
String deferChoiceLabel(int minutes) =>
    minutes % 60 == 0 ? '${minutes ~/ 60} час' : '$minutes минут';

/// «на 15 минут», «на 1 час».
String _deferLength(Duration length) {
  final minutes = length.inMinutes;
  if (minutes >= 60 && minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return 'на $hours ${_plural(hours, 'час', 'часа', 'часов')}';
  }
  return 'на $minutes ${_plural(minutes, 'минуту', 'минуты', 'минут')}';
}

String _plural(int n, String one, String few, String many) {
  final lastTwo = n % 100;
  final last = n % 10;
  if (lastTwo >= 11 && lastTwo <= 14) return many;
  if (last == 1) return one;
  if (last >= 2 && last <= 4) return few;
  return many;
}

/// The next planned intake of the same drug for the same person after
/// [intake] — «Следующий приём по схеме — в 21:00».
DateTime? nextSameDrug(AppState state, TreatmentIntake intake) {
  final person = intakePerson(intake);
  for (var i = 0; i <= 7; i++) {
    final day = DateTime(
      intake.date.year,
      intake.date.month,
      intake.date.day + i,
    );
    for (final slot in TreatmentSchedule.forDay(state, day, person: person)) {
      if (slot.medicine.id == intake.medicine.id &&
          slot.plannedAt.isAfter(intake.plannedAt)) {
        return slot.plannedAt;
      }
    }
  }
  return null;
}

/// «Следующий приём по схеме — в 21:00. Остаток пока не изменится.»
String deferNote(DateTime? next, DateTime today) {
  if (next == null) return 'Остаток пока не изменится.';
  final when = treatmentDay(next) == treatmentDay(today)
      ? 'в ${_time(next)}'
      : '${_dayWord(next, today)} в ${_time(next)}';
  return 'Следующий приём по схеме — $when. Остаток пока не изменится.';
}

/// A deferral may not reach the next planned dose of the same drug
/// («Проверьте время», 1037:20378).
bool deferOverlaps(DateTime until, DateTime? next) =>
    next != null && !until.isBefore(next);

/// The «Напомнить в» time for a chip: [minutes] after [now].
DateTime deferUntil(DateTime now, int minutes) =>
    now.add(Duration(minutes: minutes));

/// The «Напомнить в» time for a picked clock time: today, or tomorrow when
/// that time has passed.
DateTime deferAt(DateTime now, int hour, int minute) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, hour, minute);
}

/// Removes the mark of [reminderId] on [day] and puts the deducted units
/// back into the package («Отменить факт приёма»).
AppState withoutIntake(AppState state, String reminderId, DateTime day) {
  final d = treatmentDay(day);
  final record = state.intakeRecords
      .where((r) => r.reminderId == reminderId && r.day == d)
      .firstOrNull;
  if (record == null) return state;
  final reminder = state.reminders.where((r) => r.id == reminderId).firstOrNull;
  return state.copyWith(
    medicines: [
      for (final m in state.medicines)
        if (record.stockDelta > 0 && m.id == reminder?.medicineId)
          m.copyWith(quantity: m.quantity + record.stockDelta)
        else
          m,
    ],
    intakeRecords: [
      for (final r in state.intakeRecords)
        if (!(r.reminderId == reminderId && r.day == d)) r,
    ],
  );
}

/// An action on the «Сегодня» screen and the message it leaves
/// (1037:20245, 1037:19694, 1037:19575, 1037:19920).
enum IntakeOutcomeKind { taken, deferred, skipped, undone }

class IntakeOutcome {
  const IntakeOutcome(
    this.kind,
    this.reminderId,
    this.day, {
    this.at,
    this.units = 0,
    this.left,
    this.unit = '',
    this.deferredFor,
  });

  final IntakeOutcomeKind kind;
  final String reminderId;
  final DateTime day;

  /// When the intake was taken, or until when it is deferred.
  final DateTime? at;

  /// Units taken from (or returned to) the package.
  final int units;

  /// Units left in the package after the action.
  final int? left;
  final String unit;
  final Duration? deferredFor;
}

/// The outcome of a change from [before] to [after] for one intake.
IntakeOutcome outcomeOf(
  AppState before,
  AppState after,
  TreatmentIntake intake,
  IntakeOutcomeKind kind, {
  DateTime? now,
}) {
  final day = treatmentDay(intake.date);
  IntakeRecord? recordIn(AppState s) => s.intakeRecords
      .where((r) => r.reminderId == intake.reminder.id && r.day == day)
      .firstOrNull;
  final medicine = after.medicines
      .where((m) => m.id == intake.medicine.id)
      .firstOrNull;
  final record = recordIn(after);
  final previous = recordIn(before);
  return switch (kind) {
    IntakeOutcomeKind.taken => IntakeOutcome(
      kind,
      intake.reminder.id,
      day,
      at: record?.occurredAt,
      units: record?.stockDelta ?? 0,
      left: medicine?.quantity,
      unit: medicine?.unit ?? '',
    ),
    IntakeOutcomeKind.deferred => IntakeOutcome(
      kind,
      intake.reminder.id,
      day,
      at: record?.deferredUntil,
      deferredFor: record?.deferredUntil == null || now == null
          ? null
          : record!.deferredUntil!.difference(now),
    ),
    IntakeOutcomeKind.skipped => IntakeOutcome(kind, intake.reminder.id, day),
    IntakeOutcomeKind.undone => IntakeOutcome(
      kind,
      intake.reminder.id,
      day,
      units: previous?.stockDelta ?? 0,
      left: medicine?.quantity,
      unit: medicine?.unit ?? '',
    ),
  };
}

/// Title and text of the message for [outcome].
(String, String) outcomeMessage(IntakeOutcome outcome, TreatmentIntake intake) {
  final heading = intakeHeading(intake);
  switch (outcome.kind) {
    case IntakeOutcomeKind.taken:
      final at = outcome.at ?? DateTime.now();
      final stock = outcome.units > 0
          ? 'Из упаковки списана ${quantityLabel(outcome.units, outcome.unit)}'
                '${outcome.left == null ? '' : ', осталось ${outcome.left}'}.'
          : 'Остаток не изменился.';
      return ('Приём отмечен в ${_time(at)}', '$heading. $stock');
    case IntakeOutcomeKind.deferred:
      final until = outcome.at ?? DateTime.now();
      final length = outcome.deferredFor;
      final lengthText = length == null || length.inMinutes <= 0
          ? 'Приём отложен.'
          : 'Приём отложен ${_deferLength(Duration(minutes: ((length.inSeconds + 30) ~/ 60)))}.';
      return (
        'Напомним в ${_time(until)}',
        '$lengthText Остаток не изменился.',
      );
    case IntakeOutcomeKind.skipped:
      return (
        'Пропуск сохранён',
        '$heading, ${_time(intake.plannedAt)}. Остаток не изменился.',
      );
    case IntakeOutcomeKind.undone:
      final back = outcome.units == 1
          ? 'Ранее списанная ${quantityLabel(1, outcome.unit).substring(2)} '
                'возвращена.'
          : 'Ранее списанные ${quantityLabel(outcome.units, outcome.unit)} '
                'возвращены.';
      final left = outcome.left == null
          ? ''
          : ' В упаковке снова ${quantityLabel(outcome.left!, outcome.unit)}.';
      final text = outcome.units > 0 ? '$back$left' : 'Остаток не изменился.';
      return ('Отметка отменена', text);
  }
}

/// «Отметки ещё нет. После сохранения из выбранной упаковки спишется
/// 1 таблетка.»
String markNote(TreatmentIntake intake) {
  final deducts = intakeDeductsStock(intake.reminder, intake.medicine);
  return deducts
      ? 'Отметки ещё нет. После сохранения из выбранной упаковки спишется '
            '${quantityLabel(intake.reminder.amount, intake.medicine.unit)}.'
      : 'Отметки ещё нет. Остаток в аптечке не изменится.';
}

/// «Повторного списания не будет» banner text, or `null` without a
/// deduction.
String? noRepeatDeductionText(TreatmentIntake intake) {
  final units = intake.record?.stockDelta ?? 0;
  if (units <= 0) return null;
  return '${quantityLabel(units, intake.medicine.unit)} уже '
      '${units == 1 ? 'учтена' : 'учтены'}. Изменится только фактическое время.';
}

/// «Не было лекарства под рукой», «Плохое самочувствие», «Другая причина».
const skipReasons = [
  'Не было лекарства под рукой',
  'Плохое самочувствие',
  'Другая причина',
];
