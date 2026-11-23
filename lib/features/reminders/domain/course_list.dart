import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/package_detail.dart';

import 'medication_reminder.dart';
import 'treatment_course.dart';
import 'treatment_today.dart';

/// Logic of «Лечение / 3 · Список курсов» (1186:21992).

/// Where a course sits in the list.
enum CourseStage { active, planned, paused, completed }

CourseStage courseStage(TreatmentCourse course, DateTime now) {
  if (course.isCompletedAt(now)) return CourseStage.completed;
  if (course.status == CourseStatus.paused) return CourseStage.paused;
  if (treatmentDay(course.startsAt).isAfter(treatmentDay(now))) {
    return CourseStage.planned;
  }
  return CourseStage.active;
}

/// A titled group of course cards; an empty [title] has no header.
class CourseGroup {
  const CourseGroup(this.title, this.courses);
  final String title;
  final List<TreatmentCourse> courses;
}

/// The «Текущие» or «Завершённые» list of [person] («Все» for everyone).
class CourseList {
  const CourseList({
    required this.current,
    required this.completed,
    required this.groups,
  });

  /// Counts for «Текущие · 3» and «Завершённые · 2 ›».
  final int current;
  final int completed;
  final List<CourseGroup> groups;
  bool get isEmpty => groups.every((g) => g.courses.isEmpty);
}

/// «Я · 2 курса»
String personGroupTitle(String person, int count) =>
    '$person · ${russianCount(count, 'курс', 'курса', 'курсов')}';

CourseList courseList(
  AppState state,
  DateTime now, {
  required String person,
  required bool completed,
}) {
  final mine = [
    for (final c in state.courses)
      if (person == everyone || c.person == person) c,
  ];
  final stages = {for (final c in mine) c.id: courseStage(c, now)};
  final done = [
    for (final c in mine)
      if (stages[c.id] == CourseStage.completed) c,
  ];
  final current = [
    for (final c in mine)
      if (stages[c.id] != CourseStage.completed) c,
  ];
  final groups = <CourseGroup>[];
  void byPerson(List<TreatmentCourse> courses) {
    if (person != everyone) {
      if (courses.isNotEmpty) groups.add(CourseGroup('', courses));
      return;
    }
    final people = [
      for (final p in treatmentPeople(state))
        if (p != everyone) p,
    ];
    for (final p in people) {
      final own = [
        for (final c in courses)
          if (c.person == p) c,
      ];
      if (own.isNotEmpty) {
        groups.add(CourseGroup(personGroupTitle(p, own.length), own));
      }
    }
  }

  if (completed) {
    byPerson(done);
  } else {
    byPerson([
      for (final c in current)
        if (stages[c.id] == CourseStage.active) c,
    ]);
    for (final (stage, title) in [
      (CourseStage.planned, 'Запланированные'),
      (CourseStage.paused, 'На паузе'),
    ]) {
      final list = [
        for (final c in current)
          if (stages[c.id] == stage) c,
      ];
      if (list.isNotEmpty) {
        groups.add(CourseGroup('$title · ${list.length}', list));
      }
    }
  }
  return CourseList(
    current: current.length,
    completed: done.length,
    groups: groups,
  );
}

/// «2 месяца», «3 недели», «10 дней».
String periodLabel(int days) {
  if (days >= 28) {
    final months = (days / 30.4).round();
    return russianCount(months, 'месяц', 'месяца', 'месяцев');
  }
  if (days % 7 == 0) {
    return russianCount(days ~/ 7, 'неделя', 'недели', 'недель');
  }
  return russianCount(days, 'день', 'дня', 'дней');
}

/// «25 октября — 3 ноября», «1 — 14 октября».
String dateRange(DateTime from, DateTime to) {
  if (from.year == to.year && from.month == to.month) {
    return '${from.day} — ${shortDate(to)}';
  }
  return '${shortDate(from)} — ${shortDate(to)}';
}

List<MedicationReminder> _reminders(AppState state, TreatmentCourse course) => [
  for (final r in state.reminders)
    if (r.courseId == course.id && r.enabled) r,
];

/// The cycle of a «приём · перерыв» course, from its first cyclic reminder.
class CoursePhase {
  const CoursePhase({
    required this.intake,
    required this.day,
    required this.length,
    required this.endsAt,
    required this.cycleDays,
    required this.breakDays,
  });

  /// `true` — «Приём», `false` — «Перерыв».
  final bool intake;

  /// «День 34 из 61»
  final int day;
  final int length;

  /// The last day of the phase («До 25 ноября»).
  final DateTime endsAt;
  final int cycleDays;
  final int breakDays;
}

CoursePhase? coursePhase(AppState state, TreatmentCourse course, DateTime now) {
  final cyclic = _reminders(
    state,
    course,
  ).where((r) => r.frequency == IntakeFrequency.cycles).firstOrNull;
  if (cyclic == null) return null;
  final offset = treatmentDaysBetween(course.startsAt, now);
  if (offset < 0) return null;
  final period = cyclic.cycleDays + cyclic.breakDays;
  final position = offset % period;
  final intake = position < cyclic.cycleDays;
  final day = intake ? position + 1 : position - cyclic.cycleDays + 1;
  final length = intake ? cyclic.cycleDays : cyclic.breakDays;
  final today = treatmentDay(now);
  return CoursePhase(
    intake: intake,
    day: day,
    length: length,
    endsAt: DateTime(today.year, today.month, today.day + length - day),
    cycleDays: cyclic.cycleDays,
    breakDays: cyclic.breakDays,
  );
}

/// The small badge right of the title.
enum CourseBadgeTone { brand, neutral }

class CourseBadge {
  const CourseBadge(this.text, this.tone);
  final String text;
  final CourseBadgeTone tone;
}

/// The stock line at the bottom of a card.
enum CourseStockTone { warning, unknown }

class CourseStockLine {
  const CourseStockLine(this.text, this.tone);
  final String text;
  final CourseStockTone tone;
}

/// Everything a «course card» (722:3292) shows.
class CourseCardInfo {
  const CourseCardInfo({
    required this.title,
    required this.subtitle,
    this.badge,
    this.progress,
    this.progressDays,
    this.progressEnd,
    this.progressMuted = false,
    this.lines = const [],
    this.stock,
  });

  final String title;
  final String subtitle;
  final CourseBadge? badge;

  /// 0…1, `null` without a progress bar.
  final double? progress;
  final String? progressDays;
  final String? progressEnd;

  /// The grey bar of a break.
  final bool progressMuted;
  final List<String> lines;
  final CourseStockLine? stock;
}

String _time(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String _partOfDay(int hour) => hour < 12
    ? 'утром'
    : hour < 18
    ? 'днём'
    : 'вечером';

const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

/// «Ибупрофен · 3 раза в день», «Витамин D3 · 1 капсула утром»,
/// «Витамин D3 · пн, ср, пт».
List<String> drugLines(AppState state, TreatmentCourse course) {
  final reminders = _reminders(state, course);
  final lines = <String>[];
  for (final id in reminders.map((r) => r.medicineId).toSet()) {
    final medicine = state.medicines.where((m) => m.id == id).firstOrNull;
    if (medicine == null) continue;
    final own = [
      for (final r in reminders)
        if (r.medicineId == id) r,
    ];
    final name = readableDrugName(medicine.name);
    final first = own.first;
    final String schedule;
    if (first.frequency == IntakeFrequency.weekdays &&
        first.weekdays.length < 7) {
      schedule = [
        for (final d in [...first.weekdays]..sort()) _weekdays[d - 1],
      ].join(', ');
    } else if (own.length == 1) {
      schedule = [
        if (first.dose.isNotEmpty) first.dose,
        _partOfDay(first.hour),
      ].join(' ');
    } else {
      schedule = '${russianCount(own.length, 'раз', 'раза', 'раз')} в день';
    }
    lines.add('$name · $schedule');
  }
  return lines;
}

/// «Ибупрофен» → «Ибупрофена» for «Ибупрофена хватит на 2 дня». Only the
/// first word changes; unknown endings stay as they are.
String drugGenitive(String name) {
  final words = name.split(' ');
  final word = words.first;
  if (!RegExp(r'^[А-Яа-яЁё-]+$').hasMatch(word) || word.length < 3) {
    return name;
  }
  final last = word[word.length - 1].toLowerCase();
  final before = word[word.length - 2].toLowerCase();
  final String changed;
  if ('бвгджзклмнпрстфхцчшщ'.contains(last)) {
    changed = '$wordа';
  } else if (last == 'а') {
    changed =
        '${word.substring(0, word.length - 1)}'
        '${'гкхжшщч'.contains(before) ? 'и' : 'ы'}';
  } else if (last == 'я') {
    changed = '${word.substring(0, word.length - 1)}и';
  } else if (last == 'й') {
    changed = '${word.substring(0, word.length - 1)}я';
  } else {
    return name;
  }
  return [changed, ...words.skip(1)].join(' ');
}

/// How many days the stock lasts per drug, the lowest first: «Ибупрофена
/// хватит на 2 дня», «… нет в аптечке» or «Запас не рассчитан».
CourseStockLine? courseStock(
  AppState state,
  TreatmentCourse course,
  DateTime now,
) {
  if (!course.stockAlert) return null;
  final reminders = _reminders(state, course);
  if (reminders.isEmpty) return null;
  final today = treatmentDay(now);
  final remaining = course.endsAt == null
      ? null
      : treatmentDaysBetween(today, course.endsAt!) + 1;
  final threshold = remaining ?? 7;
  var unknown = false;
  (String, int)? lowest;
  for (final id in reminders.map((r) => r.medicineId).toSet()) {
    final medicine = state.medicines.where((m) => m.id == id).firstOrNull;
    final own = [
      for (final r in reminders)
        if (r.medicineId == id) r,
    ];
    if (medicine == null) continue;
    final name = readableDrugName(medicine.name).split(',').first.trim();
    if (medicine.quantity <= 0) {
      return CourseStockLine(
        '${drugGenitive(name)} нет в аптечке',
        CourseStockTone.warning,
      );
    }
    if (!own.every((r) => intakeDeductsStock(r, medicine))) {
      unknown = true;
      continue;
    }
    var perDay = 0.0;
    for (final r in own) {
      perDay +=
          r.amount *
          switch (r.frequency) {
            IntakeFrequency.daily => 1.0,
            IntakeFrequency.alternate => 0.5,
            IntakeFrequency.weekdays => r.weekdays.length / 7,
            IntakeFrequency.cycles => r.cycleDays / (r.cycleDays + r.breakDays),
          };
    }
    if (perDay <= 0) continue;
    final days = (medicine.quantity / perDay).floor();
    if (days < threshold && (lowest == null || days < lowest.$2)) {
      lowest = (name, days);
    }
  }
  if (lowest != null) {
    return CourseStockLine(
      '${drugGenitive(lowest.$1)} хватит на '
      '${russianCount(lowest.$2, 'день', 'дня', 'дней')}',
      CourseStockTone.warning,
    );
  }
  return unknown
      ? const CourseStockLine('Запас не рассчитан', CourseStockTone.unknown)
      : null;
}

CourseCardInfo courseCardInfo(
  AppState state,
  TreatmentCourse course,
  DateTime now,
) {
  final stage = courseStage(course, now);
  final reminders = _reminders(state, course);
  final drugs = drugLines(state, course);
  final start = treatmentDay(course.startsAt);
  final end = course.endsAt;
  final dates = end == null
      ? (reminders.isNotEmpty &&
                reminders.first.frequency == IntakeFrequency.weekdays
            ? 'По дням недели · с ${shortDate(start)}'
            : 'Постоянно · с ${shortDate(start)}')
      : dateRange(start, end);
  switch (stage) {
    case CourseStage.completed:
      final last = course.completedAt == null
          ? end ?? start
          : treatmentDay(course.completedAt!);
      final count = reminders.map((r) => r.medicineId).toSet().length;
      return CourseCardInfo(
        title: course.name,
        subtitle: '${dateRange(start, last)} · завершён',
        lines: [
          count == 1 && drugs.isNotEmpty
              ? '${drugs.first.split(' · ').first} · 1 препарат'
              : russianCount(count, 'препарат', 'препарата', 'препаратов'),
        ],
      );
    case CourseStage.planned:
      final first = [...reminders]
        ..sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
      return CourseCardInfo(
        title: course.name,
        subtitle: dates,
        badge: CourseBadge('С ${shortDate(start)}', CourseBadgeTone.brand),
        lines: [
          ...drugs.take(2),
          if (first.isNotEmpty)
            'Первый приём — ${shortDate(start)}, '
                '${_time(first.first.hour, first.first.minute)}',
        ],
      );
    case CourseStage.paused:
      return CourseCardInfo(
        title: course.name,
        subtitle: dates,
        badge: const CourseBadge('На паузе', CourseBadgeTone.neutral),
        lines: const ['Напоминания выключены', 'Даты курса остаются прежними'],
      );
    case CourseStage.active:
      final phase = coursePhase(state, course, now);
      if (phase != null) {
        final resumes = DateTime(
          phase.endsAt.year,
          phase.endsAt.month,
          phase.endsAt.day + 1,
        );
        return CourseCardInfo(
          title: course.name,
          subtitle:
              '${periodLabel(phase.cycleDays)} приём · '
              '${periodLabel(phase.breakDays)} перерыв',
          badge: phase.intake
              ? const CourseBadge('Приём', CourseBadgeTone.brand)
              : const CourseBadge('Перерыв', CourseBadgeTone.neutral),
          progress: phase.day / phase.length,
          progressDays: 'День ${phase.day} из ${phase.length}',
          progressEnd: 'До ${shortDate(phase.endsAt)}',
          progressMuted: !phase.intake,
          lines: phase.intake
              ? _limit(drugs)
              : ['Приём возобновится ${shortDate(resumes)}'],
          stock: phase.intake ? courseStock(state, course, now) : null,
        );
      }
      final total = course.durationDays;
      final day = course.dayNumber(now);
      return CourseCardInfo(
        title: course.name,
        subtitle: dates,
        progress: total == null ? null : day / total,
        progressDays: total == null ? null : 'День $day из $total',
        lines: _limit(drugs),
        stock: courseStock(state, course, now),
      );
  }
}

/// Two drug lines, then «Ещё 2 препарата».
List<String> _limit(List<String> lines) => lines.length <= 3
    ? lines
    : [
        ...lines.take(2),
        'Ещё ${russianCount(lines.length - 2, 'препарат', 'препарата', 'препаратов')}',
      ];

/// «Миша» → «Миши», «Мама» → «мамы» for «У Миши пока нет курсов».
String personGenitive(String person) {
  const kin = {
    'Мама': 'мамы',
    'Папа': 'папы',
    'Бабушка': 'бабушки',
    'Дедушка': 'дедушки',
  };
  if (kin.containsKey(person)) return kin[person]!;
  return drugGenitive(person);
}

/// Texts of the empty states of the list.
class CourseEmptyText {
  const CourseEmptyText(this.title, this.text);
  final String title;
  final String text;
}

/// «У Миши пока нет курсов» (1113:27401).
CourseEmptyText personEmpty(String person) => person == 'Я'
    ? const CourseEmptyText(
        'У вас пока нет курсов',
        'Добавьте свой курс или посмотрите лечение других членов семьи.',
      )
    : CourseEmptyText(
        'У ${personGenitive(person)} пока нет курсов',
        'Добавьте курс для ${personGenitive(person)} или посмотрите лечение '
            'других членов семьи.',
      );

/// «Завершённых пока нет» (1113:28140).
CourseEmptyText completedEmpty(String person) => CourseEmptyText(
  'Завершённых пока нет',
  person == everyone
      ? 'Здесь появятся курсы после завершения. История приёмов сохранится '
            'в курсе.'
      : person == 'Я'
      ? 'Здесь появятся ваши курсы после завершения. История приёмов '
            'сохранится в курсе.'
      : 'Здесь появятся курсы ${personGenitive(person)} после завершения. '
            'История приёмов сохранится в курсе.',
);
