import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';

import 'medication_reminder.dart';
import 'treatment_course.dart';
import 'treatment_schedule.dart';

/// Logic of «Лечение / Сегодня» (1186:21990).

/// «Все» in the person picker: no filter.
const everyone = 'Все';

/// Whose intake it is: the course person, «Я» without a course.
String intakePerson(TreatmentIntake intake) => intake.course?.person ?? 'Я';

/// «Выбор человека» (1074:22722): «Все», «Я», then course people in order.
List<String> treatmentPeople(AppState state) => {
  everyone,
  'Я',
  for (final course in state.courses)
    if (course.person.trim().isNotEmpty) course.person,
}.toList();

/// «1 таблетка · после еды»
String intakeDetails(TreatmentIntake intake) => [
  intake.reminder.dose,
  if (intake.reminder.condition.isNotEmpty) intake.reminder.condition,
].join(' · ');

String _time(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

/// The third line of «intake row».
enum IntakeTone { taken, missed, skipped, deferred }

class IntakeStatusLine {
  const IntakeStatusLine(this.text, this.tone);
  final String text;
  final IntakeTone tone;
}

/// «Принято в 08:04», «Не отмечено», «Пропущено», «Отложено до 13:30»;
/// `null` for an intake that is still ahead.
IntakeStatusLine? intakeStatus(TreatmentIntake intake, DateTime now) {
  final record = intake.record;
  if (record == null) {
    return intake.plannedAt.isAfter(now)
        ? null
        : const IntakeStatusLine('Не отмечено', IntakeTone.missed);
  }
  return switch (record.status) {
    IntakeStatus.taken => IntakeStatusLine(
      'Принято в ${_time(record.occurredAt)}',
      IntakeTone.taken,
    ),
    IntakeStatus.skipped => IntakeStatusLine(
      'Пропущено · ${record.reason.isEmpty ? 'причина не указана' : record.reason[0].toLowerCase() + record.reason.substring(1)}',
      IntakeTone.skipped,
    ),
    IntakeStatus.deferred => IntakeStatusLine(
      'Отложено до ${_time(record.deferredUntil!)}',
      IntakeTone.deferred,
    ),
  };
}

/// «Принято 4 из 7», or «Нет приёмов».
String takenSummary(List<TreatmentIntake> slots) {
  if (slots.isEmpty) return 'Нет приёмов';
  final taken = slots
      .where((s) => s.record?.status == IntakeStatus.taken)
      .length;
  return 'Принято $taken из ${slots.length}';
}

/// «Сегодня, 29 октября», «Вчера, …», «Завтра, …» or «29 октября».
String scheduleDateLabel(DateTime day, DateTime today) {
  final d = treatmentDay(day);
  final t = treatmentDay(today);
  final prefix = d == t
      ? 'Сегодня, '
      : d == DateTime(t.year, t.month, t.day - 1)
      ? 'Вчера, '
      : d == DateTime(t.year, t.month, t.day + 1)
      ? 'Завтра, '
      : '';
  return '$prefix${shortDate(d)}';
}

/// The dot of «day cell» (722:3327).
enum DayMark { none, done, partial }

/// Green when every intake of a past or current day is taken, orange when
/// something was skipped or is still unmarked, nothing when the day had no
/// marks yet.
DayMark dayMark(List<TreatmentIntake> slots) {
  if (slots.isEmpty || !slots.any((s) => s.marked)) return DayMark.none;
  final allTaken = slots.every((s) => s.record?.status == IntakeStatus.taken);
  return allTaken ? DayMark.done : DayMark.partial;
}

/// Утро, День, Вечер of the day schedule.
enum DayPart {
  morning('Утро'),
  day('День'),
  evening('Вечер');

  const DayPart(this.label);
  final String label;

  static DayPart of(int hour) => hour < 12
      ? morning
      : hour < 18
      ? day
      : evening;
}

/// The «intake now» card: the latest unmarked intake that is already due,
/// only on today's schedule.
TreatmentIntake? currentIntake(
  List<TreatmentIntake> slots,
  DateTime day,
  DateTime now,
) {
  if (treatmentDay(day) != treatmentDay(now)) return null;
  return slots.where((s) => !s.marked && !s.dueAt.isAfter(now)).lastOrNull;
}

/// The first intakes after [day]: their time and drug names.
class NextIntake {
  const NextIntake(this.at, this.names);
  final DateTime at;
  final List<String> names;
}

/// Looks up to [searchDays] days ahead for the next scheduled intakes.
NextIntake? nextIntakeAfter(
  AppState state,
  DateTime day, {
  String? person,
  int searchDays = 60,
}) {
  final start = treatmentDay(day);
  for (var i = 1; i <= searchDays; i++) {
    final date = DateTime(start.year, start.month, start.day + i);
    final slots = TreatmentSchedule.forDay(state, date, person: person);
    if (slots.isEmpty) continue;
    final first = slots.first.plannedAt;
    final names = <String>[];
    for (final slot in slots.where((s) => s.plannedAt == first)) {
      final name = readableDrugName(slot.medicine.name);
      if (!names.contains(name)) names.add(name);
    }
    return NextIntake(first, names);
  }
  return null;
}

/// «Следующий — завтра в 08:00: Ибупрофен и Витамин D3»
String nextIntakeLabel(NextIntake? next, DateTime today) {
  if (next == null) return 'Других запланированных приёмов нет';
  final t = treatmentDay(today);
  final d = treatmentDay(next.at);
  final when = d == DateTime(t.year, t.month, t.day + 1)
      ? 'завтра'
      : shortDate(d);
  final names = next.names.length == 1
      ? next.names.single
      : '${next.names.take(next.names.length - 1).join(', ')} и '
            '${next.names.last}';
  return 'Следующий — $when в ${_time(next.at)}: $names';
}
