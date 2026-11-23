import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/course_list.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 29 October 2026.
  final now = DateTime(2026, 10, 29, 12);

  Medicine drug(
    String id,
    String name,
    int quantity, {
    String unit = 'таблетка',
  }) => Medicine(
    id: id,
    name: name,
    form: 'Таблетки',
    dosage: '',
    quantity: quantity,
    unit: unit,
    location: 'Полка',
  );

  MedicationReminder reminder(
    String id,
    String medicineId,
    String courseId,
    int hour, {
    String dose = '1 таблетка',
    String unit = 'таблетка',
    IntakeFrequency frequency = IntakeFrequency.daily,
    List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
    int cycleDays = 60,
    int breakDays = 30,
  }) => MedicationReminder(
    id: id,
    medicineId: medicineId,
    courseId: courseId,
    hour: hour,
    minute: 0,
    dose: dose,
    unit: unit,
    enabled: true,
    frequency: frequency,
    weekdays: weekdays,
    cycleDays: cycleDays,
    breakDays: breakDays,
  );

  final cold = TreatmentCourse(
    id: 'cold',
    name: 'Простуда',
    person: 'Я',
    startsAt: DateTime(2026, 10, 25),
    durationDays: 10,
  );
  final vitamin = TreatmentCourse(
    id: 'vit',
    name: 'Витамин D',
    person: 'Я',
    startsAt: DateTime(2026, 9, 26),
    durationDays: null,
  );
  final pressure = TreatmentCourse(
    id: 'press',
    name: 'Давление',
    person: 'Мама',
    startsAt: DateTime(2026, 9, 1),
    durationDays: null,
  );
  final planned = TreatmentCourse(
    id: 'plan',
    name: 'Магний',
    person: 'Я',
    startsAt: DateTime(2026, 11, 9),
    durationDays: 30,
  );
  final paused = TreatmentCourse(
    id: 'pause',
    name: 'Пауза',
    person: 'Я',
    startsAt: DateTime(2026, 10, 25),
    durationDays: 30,
    status: CourseStatus.paused,
  );
  final done = TreatmentCourse(
    id: 'done',
    name: 'Магний',
    person: 'Мама',
    startsAt: DateTime(2026, 10, 1),
    durationDays: 14,
  );

  AppState state() => AppState(
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
      drug('ibu', 'Ибупрофен', 5),
      drug('naz', 'Називин', 1, unit: 'флакон'),
      drug('d3', 'Витамин D3', 60, unit: 'капсула'),
      drug('los', 'Лозартан', 5),
      drug('mg', 'Магний', 30),
    ],
    reminders: [
      reminder('ibu-8', 'ibu', 'cold', 8),
      reminder('ibu-14', 'ibu', 'cold', 14),
      reminder('ibu-20', 'ibu', 'cold', 20),
      reminder('naz-8', 'naz', 'cold', 8, dose: '2 капли', unit: 'капля'),
      reminder('naz-20', 'naz', 'cold', 20, dose: '2 капли', unit: 'капля'),
      reminder(
        'd3',
        'd3',
        'vit',
        9,
        dose: '1 капсула',
        unit: 'капсула',
        frequency: IntakeFrequency.cycles,
        cycleDays: 61,
        breakDays: 30,
      ),
      reminder('los', 'los', 'press', 8),
      reminder('mg-plan', 'mg', 'plan', 9),
      reminder('mg-pause', 'mg', 'pause', 21),
      reminder('mg-done', 'mg', 'done', 21),
    ],
    intakeRecords: const [],
    courses: [cold, vitamin, pressure, planned, paused, done],
  );

  test('stages and groups', () {
    expect(courseStage(cold, now), CourseStage.active);
    expect(courseStage(planned, now), CourseStage.planned);
    expect(courseStage(paused, now), CourseStage.paused);
    expect(courseStage(done, now), CourseStage.completed);

    final all = courseList(state(), now, person: 'Все', completed: false);
    expect(all.current, 5);
    expect(all.completed, 1);
    expect(all.groups.map((g) => g.title), [
      'Я · 2 курса',
      'Мама · 1 курс',
      'Запланированные · 1',
      'На паузе · 1',
    ]);
    final me = courseList(state(), now, person: 'Я', completed: false);
    expect(me.groups.first.title, '');
    expect(me.groups.first.courses.map((c) => c.id), ['cold', 'vit']);
    final finished = courseList(state(), now, person: 'Все', completed: true);
    expect(finished.groups.single.title, 'Мама · 1 курс');
    expect(
      courseList(state(), now, person: 'Миша', completed: false).isEmpty,
      isTrue,
    );
  });

  test('card of a finite course with stock', () {
    final info = courseCardInfo(state(), cold, now);
    expect(info.subtitle, '25 октября — 3 ноября');
    expect(info.progressDays, 'День 5 из 10');
    expect(info.progress, 0.5);
    expect(info.lines, [
      'Ибупрофен · 3 раза в день',
      'Називин · 2 раза в день',
    ]);
    // 5 tablets, 3 a day, 6 days left → «хватит на 1 день».
    expect(info.stock!.text, 'Ибупрофена хватит на 1 день');
  });

  test('cycle, indefinite, planned, paused and completed cards', () {
    final cycle = courseCardInfo(state(), vitamin, now);
    expect(cycle.subtitle, '2 месяца приём · 1 месяц перерыв');
    expect(cycle.badge!.text, 'Приём');
    expect(cycle.progressDays, 'День 34 из 61');
    expect(cycle.progressEnd, 'До 25 ноября');
    expect(cycle.lines, ['Витамин D3 · 1 капсула утром']);

    final pause = courseCardInfo(state(), vitamin, DateTime(2026, 12, 5));
    expect(pause.badge!.text, 'Перерыв');
    expect(pause.progressMuted, isTrue);
    expect(pause.progressDays, 'День 10 из 30');
    expect(pause.lines, ['Приём возобновится 26 декабря']);

    final constant = courseCardInfo(state(), pressure, now);
    expect(constant.subtitle, 'Постоянно · с 1 сентября');
    expect(constant.progress, isNull);
    expect(constant.lines, ['Лозартан · 1 таблетка утром']);
    expect(constant.stock!.text, 'Лозартана хватит на 5 дней');

    final plan = courseCardInfo(state(), planned, now);
    expect(plan.badge!.text, 'С 9 ноября');
    expect(plan.subtitle, '9 ноября — 8 декабря');
    expect(plan.lines.last, 'Первый приём — 9 ноября, 09:00');

    expect(courseCardInfo(state(), paused, now).lines, [
      'Напоминания выключены',
      'Даты курса остаются прежними',
    ]);
    final finished = courseCardInfo(state(), done, now);
    expect(finished.subtitle, '1 — 14 октября · завершён');
    expect(finished.lines, ['Магний · 1 препарат']);
  });

  test('declensions and empty texts', () {
    expect(drugGenitive('Ибупрофен'), 'Ибупрофена');
    expect(drugGenitive('Но-шпа'), 'Но-шпы');
    expect(drugGenitive('Витамин D3'), 'Витамина D3');
    expect(drugGenitive('Терафлю'), 'Терафлю');
    expect(personGenitive('Миша'), 'Миши');
    expect(personGenitive('Мама'), 'мамы');
    expect(personEmpty('Миша').title, 'У Миши пока нет курсов');
    expect(
      personEmpty('Миша').text,
      'Добавьте курс для Миши или посмотрите лечение других членов семьи.',
    );
    expect(periodLabel(61), '2 месяца');
    expect(periodLabel(14), '2 недели');
    expect(
      dateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 14)),
      '1 — 14 октября',
    );
  });
}
