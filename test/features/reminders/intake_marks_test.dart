import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/intake_marks.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 29, 13, 0);
  final today = DateTime(2026, 10, 29);

  AppState state({List<IntakeRecord> records = const [], int quantity = 8}) =>
      AppState(
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
          Medicine(
            id: 'ibu',
            name: 'Ибупрофен',
            form: 'Таблетки',
            dosage: '200 мг',
            quantity: quantity,
            unit: 'таблетка',
            location: 'Полка',
          ),
        ],
        reminders: const [
          MedicationReminder(
            id: 'ibu-13',
            medicineId: 'ibu',
            courseId: 'cold',
            hour: 13,
            minute: 0,
            dose: '1 таблетка',
            unit: 'таблетка',
            enabled: true,
          ),
          MedicationReminder(
            id: 'ibu-21',
            medicineId: 'ibu',
            courseId: 'cold',
            hour: 21,
            minute: 0,
            dose: '1 таблетка',
            unit: 'таблетка',
            enabled: true,
          ),
        ],
        intakeRecords: records,
        courses: [
          TreatmentCourse(
            id: 'cold',
            name: 'Простуда',
            person: 'Я',
            startsAt: DateTime(2026, 10, 25),
            durationDays: 10,
          ),
        ],
      );

  TreatmentIntake slot(AppState s, String id) =>
      TreatmentSchedule.forDay(s, today).firstWhere((x) => x.reminder.id == id);

  test('sheet lines', () {
    final x = slot(state(), 'ibu-13');
    expect(intakeHeading(x), 'Я · Ибупрофен, 200 мг');
    expect(plannedLine(x), 'По плану в 13:00 · 1 таблетка');
    expect(plannedDayLine(x, now), 'По плану сегодня в 13:00 · 1 таблетка');
    expect(skipLine(x, now), 'Сегодня в 13:00 · 1 таблетка');
    expect(
      actualTimeLabel(DateTime(2026, 10, 29, 9, 30), now),
      'Сегодня, 09:30',
    );
    expect(actualTimeLabel(DateTime(2026, 10, 28, 9, 30), now), 'Вчера, 09:30');
    expect(deferChoiceLabel(15), '15 минут');
    expect(deferChoiceLabel(60), '1 час');
    expect(
      markNote(x),
      'Отметки ещё нет. После сохранения из выбранной упаковки спишется '
      '1 таблетка.',
    );
  });

  test('defer: next dose, note and overlap', () {
    final s = state();
    final x = slot(s, 'ibu-13');
    final next = nextSameDrug(s, x);
    expect(next, DateTime(2026, 10, 29, 21));
    expect(
      deferNote(next, now),
      'Следующий приём по схеме — в 21:00. Остаток пока не изменится.',
    );
    expect(deferUntil(now, 15), DateTime(2026, 10, 29, 13, 15));
    expect(deferAt(now, 22, 0), DateTime(2026, 10, 29, 22));
    expect(deferAt(now, 9, 0), DateTime(2026, 10, 30, 9));
    expect(deferOverlaps(DateTime(2026, 10, 29, 22), next), isTrue);
    expect(deferOverlaps(DateTime(2026, 10, 29, 13, 15), next), isFalse);
    expect(nextSameDrug(s, slot(s, 'ibu-21')), DateTime(2026, 10, 30, 13));
  });

  test('undo returns the deducted tablet and the messages say so', () {
    final before = state(quantity: 7);
    final taken = before.copyWith(
      intakeRecords: [
        IntakeRecord(
          reminderId: 'ibu-13',
          occurredAt: DateTime(2026, 10, 29, 13, 2),
          scheduledDate: today,
          status: IntakeStatus.taken,
          stockDelta: 1,
        ),
      ],
    );
    final x = slot(taken, 'ibu-13');
    final undone = withoutIntake(taken, 'ibu-13', today);
    expect(undone.intakeRecords, isEmpty);
    expect(undone.medicines.single.quantity, 8);

    final takenOutcome = outcomeOf(
      state(quantity: 8),
      taken,
      x,
      IntakeOutcomeKind.taken,
    );
    expect(outcomeMessage(takenOutcome, x), (
      'Приём отмечен в 13:02',
      'Я · Ибупрофен, 200 мг. Из упаковки списана 1 таблетка, осталось 7.',
    ));
    final undoOutcome = outcomeOf(taken, undone, x, IntakeOutcomeKind.undone);
    expect(outcomeMessage(undoOutcome, x), (
      'Отметка отменена',
      'Ранее списанная таблетка возвращена. В упаковке снова 8 таблеток.',
    ));
    expect(
      outcomeMessage(
        IntakeOutcome(IntakeOutcomeKind.skipped, 'ibu-13', today),
        x,
      ).$2,
      'Я · Ибупрофен, 200 мг, 13:00. Остаток не изменился.',
    );
    expect(
      outcomeMessage(
        IntakeOutcome(
          IntakeOutcomeKind.deferred,
          'ibu-13',
          today,
          at: DateTime(2026, 10, 29, 13, 15),
          deferredFor: const Duration(minutes: 15),
        ),
        x,
      ),
      ('Напомним в 13:15', 'Приём отложен на 15 минут. Остаток не изменился.'),
    );
    expect(
      noRepeatDeductionText(x),
      '1 таблетка уже учтена. Изменится только фактическое время.',
    );
  });
}
