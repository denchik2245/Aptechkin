import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:aptechka/features/reminders/domain/treatment_today.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Thursday, 29 October 2026, 13:05.
  final now = DateTime(2026, 10, 29, 13, 5);
  final today = DateTime(2026, 10, 29);

  Medicine drug(String id, String name, String dosage) => Medicine(
    id: id,
    name: name,
    form: 'Таблетки',
    dosage: dosage,
    quantity: 20,
    unit: 'таблетка',
    location: 'Полка',
  );

  MedicationReminder reminder(
    String id,
    String medicineId,
    int hour, {
    String? courseId,
    String condition = '',
  }) => MedicationReminder(
    id: id,
    medicineId: medicineId,
    hour: hour,
    minute: 0,
    dose: '1 таблетка',
    enabled: true,
    courseId: courseId,
    condition: condition,
  );

  IntakeRecord record(
    String reminderId,
    IntakeStatus status, {
    DateTime? at,
    DateTime? day,
    DateTime? deferredUntil,
  }) => IntakeRecord(
    reminderId: reminderId,
    occurredAt: at ?? now,
    scheduledDate: day ?? today,
    status: status,
    deferredUntil: deferredUntil,
  );

  AppState state({
    List<IntakeRecord> records = const [],
    List<TreatmentCourse> courses = const [],
  }) => AppState(
    pharmacies: const [
      Pharmacy(
        id: 'home',
        name: 'Дом',
        ownerLabel: 'Вы',
        isShared: false,
        canEdit: true,
      ),
    ],
    selectedPharmacyId: 'home',
    medicines: [
      drug('ibu', 'Ибупрофен', '200 мг'),
      drug('vit', 'Витамин D3', ''),
      drug('los', 'Лозартан', '50 мг'),
    ],
    reminders: [
      reminder('ibu-8', 'ibu', 8, condition: 'после еды'),
      reminder('vit-8', 'vit', 8),
      reminder('ibu-13', 'ibu', 13),
      reminder('ibu-21', 'ibu', 21),
      reminder('los-9', 'los', 9, courseId: 'mom'),
    ],
    intakeRecords: records,
    courses: courses,
  );

  final mom = TreatmentCourse(
    id: 'mom',
    name: 'Давление',
    person: 'Мама',
    startsAt: DateTime(2026, 10, 1),
    durationDays: 90,
  );

  test('people, details and the summary line', () {
    final s = state(
      courses: [mom],
      records: [
        record('ibu-8', IntakeStatus.taken, at: DateTime(2026, 10, 29, 8, 4)),
        record('vit-8', IntakeStatus.skipped),
      ],
    );
    expect(treatmentPeople(s), ['Все', 'Я', 'Мама']);
    final slots = TreatmentSchedule.forDay(s, today);
    expect(slots, hasLength(5));
    expect(takenSummary(slots), 'Принято 1 из 5');
    expect(takenSummary(const []), 'Нет приёмов');
    expect(intakeDetails(slots.first), '1 таблетка · после еды');
    expect(intakePerson(slots.first), 'Я');
    expect(intakePerson(slots.firstWhere((x) => x.course != null)), 'Мама');
    expect(
      TreatmentSchedule.forDay(s, today, person: 'Мама').single.medicine.id,
      'los',
    );
  });

  test('status line of an intake row', () {
    final s = state(
      courses: [mom],
      records: [
        record('ibu-8', IntakeStatus.taken, at: DateTime(2026, 10, 29, 8, 4)),
        record('vit-8', IntakeStatus.skipped),
        record(
          'ibu-13',
          IntakeStatus.deferred,
          deferredUntil: DateTime(2026, 10, 29, 13, 30),
        ),
      ],
    );
    final slots = {
      for (final x in TreatmentSchedule.forDay(s, today)) x.reminder.id: x,
    };
    expect(intakeStatus(slots['ibu-8']!, now)!.text, 'Принято в 08:04');
    expect(intakeStatus(slots['ibu-8']!, now)!.tone, IntakeTone.taken);
    expect(intakeStatus(slots['vit-8']!, now)!.tone, IntakeTone.skipped);
    expect(intakeStatus(slots['ibu-13']!, now)!.text, 'Отложено до 13:30');
    expect(intakeStatus(slots['los-9']!, now)!.text, 'Не отмечено');
    expect(intakeStatus(slots['ibu-21']!, now), isNull);
  });

  test('the current intake is the last due unmarked one, only today', () {
    final s = state(
      courses: [mom],
      records: [
        record('ibu-8', IntakeStatus.taken),
        record('vit-8', IntakeStatus.taken),
      ],
    );
    final slots = TreatmentSchedule.forDay(s, today);
    expect(currentIntake(slots, today, now)!.reminder.id, 'ibu-13');
    expect(
      currentIntake(slots, today, DateTime(2026, 10, 29, 7))?.reminder.id,
      isNull,
    );
    final yesterday = DateTime(2026, 10, 28);
    expect(
      currentIntake(TreatmentSchedule.forDay(s, yesterday), yesterday, now),
      isNull,
    );
  });

  test('day marks, day parts and date labels', () {
    final s = state(
      records: [
        record('ibu-8', IntakeStatus.taken),
        record('vit-8', IntakeStatus.taken),
        record('ibu-13', IntakeStatus.taken),
        record('ibu-21', IntakeStatus.taken),
      ],
    );
    expect(dayMark(TreatmentSchedule.forDay(s, today)), DayMark.done);
    final partial = state(records: [record('ibu-8', IntakeStatus.skipped)]);
    expect(dayMark(TreatmentSchedule.forDay(partial, today)), DayMark.partial);
    expect(dayMark(TreatmentSchedule.forDay(state(), today)), DayMark.none);
    expect(DayPart.of(8), DayPart.morning);
    expect(DayPart.of(13), DayPart.day);
    expect(DayPart.of(18).label, 'Вечер');
    expect(scheduleDateLabel(today, now), 'Сегодня, 29 октября');
    expect(scheduleDateLabel(DateTime(2026, 10, 28), now), 'Вчера, 28 октября');
    expect(
      scheduleDateLabel(DateTime(2026, 10, 30), now),
      'Завтра, 30 октября',
    );
    expect(scheduleDateLabel(DateTime(2026, 10, 26), now), '26 октября');
  });

  test('next intake after the day', () {
    final s = state();
    final next = nextIntakeAfter(s, today);
    expect(next!.at, DateTime(2026, 10, 30, 8));
    expect(next.names, ['Ибупрофен', 'Витамин D3']);
    expect(
      nextIntakeLabel(next, now),
      'Следующий — завтра в 08:00: Ибупрофен и Витамин D3',
    );
    expect(
      nextIntakeLabel(NextIntake(DateTime(2026, 11, 2, 9), ['Лозартан']), now),
      'Следующий — 2 ноября в 09:00: Лозартан',
    );
    expect(nextIntakeAfter(s, today, person: 'Миша'), isNull);
    expect(nextIntakeLabel(null, now), 'Других запланированных приёмов нет');
  });
}
