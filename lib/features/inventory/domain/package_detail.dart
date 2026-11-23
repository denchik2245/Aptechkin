import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_variant.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/package_form.dart';
import 'package:aptechka/features/inventory/domain/package_status.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';

/// Rules of the Figma «Карточка лекарства» (875:12466 «Статусы срока»,
/// 875:12467 «Формы лекарств», 875:12468 «Вскрытие», 875:12469 «Упаковки,
/// курс и справка»).

enum PackageAlertTone { warning, fail, info }

enum PackageAlertAction {
  /// «Убрать из аптечки».
  remove,

  /// «Указать срок».
  setExpiry,

  /// «Дополнить».
  complete,

  /// «Указать срок» после вскрытия.
  setAfterOpening,

  /// «Открыть курс».
  openCourse,

  /// «Состояние аптечки» (863:12157) on «Осталось …» / «Почти закончилось».
  kitState,
}

/// The «status banner» above the package hero.
class PackageAlert {
  const PackageAlert(
    this.tone,
    this.title,
    this.text, [
    this.action,
    this.courseId,
  ]);
  final PackageAlertTone tone;
  final String title;
  final String text;
  final PackageAlertAction? action;

  /// The course «Открыть курс» leads to.
  final String? courseId;
}

/// Counted in pieces (`count`), approximately (`level`) or not at all
/// (`off`, devices) — the three «stock control» types.
enum StockKind { count, level, off }

StockKind stockKindOf(Medicine package) {
  if (!package.tracksStock) return StockKind.off;
  if (package.stockLevel != null) return StockKind.level;
  return StockKind.count;
}

bool isUsedUp(Medicine package) =>
    stockKindOf(package) == StockKind.count && package.quantity <= 0;

/// «Мало данных»: neither place nor expiry date.
bool isSparse(Medicine package) =>
    package.location.trim().isEmpty &&
    package.expiryDate == null &&
    !package.noExpiry;

/// Kept in the fridge (2–8 °C).
bool needsFridge(Medicine package) {
  final storage = package.storage?.toLowerCase() ?? '';
  return storage.contains('холодильник') ||
      RegExp(r'\b2\s*[–—-]\s*8\b').hasMatch(storage);
}

/// Opened, but the term after opening is unknown (875:12468).
bool needsAfterOpeningTerm(Medicine package) =>
    package.openedAt != null && package.afterOpeningDays == null;

/// The term after opening ends before the printed one.
bool openingShortensTerm(Medicine package) {
  final afterOpening = package.afterOpeningExpiry;
  final printed = package.expiryDate;
  return afterOpening != null &&
      printed != null &&
      afterOpening.isBefore(printed);
}

/// The term after opening is over while the printed one still runs.
bool expiredAfterOpening(Medicine package, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final afterOpening = package.afterOpeningExpiry;
  final printed = package.expiryDate;
  return afterOpening != null &&
      afterOpening.isBefore(today) &&
      printed != null &&
      !printed.isBefore(today);
}

/// One banner at most, the most important first: expired, used up,
/// sparse card, unknown expiry, expiring soon, low stock, fridge.
PackageAlert? packageAlert(
  Medicine package,
  DateTime now, {
  int warningDays = 30,
  int lowStockThreshold = 2,
  PackageCourse? course,
}) {
  final status = package.statusAt(now, warningDays: warningDays);
  if (expiredAfterOpening(package, now)) {
    return PackageAlert(
      PackageAlertTone.fail,
      'Срок после вскрытия истёк',
      'Флакон открыт ${_dayMonth(package.openedAt!, now)}, его хранят '
          '${afterOpeningLabel(package.afterOpeningDays!)}. Срок на упаковке ещё идёт, '
          'но открытым флаконом пользоваться не стоит',
      PackageAlertAction.remove,
    );
  }
  if (status == MedicineStatus.expired) {
    return const PackageAlert(
      PackageAlertTone.fail,
      'Срок истёк — не используйте',
      'Сдайте в аптеку с пунктом приёма лекарств или выбросьте',
      PackageAlertAction.remove,
    );
  }
  if (isUsedUp(package)) {
    return const PackageAlert(
      PackageAlertTone.info,
      'Закончилось',
      'Упаковка осталась в аптечке, чтобы было видно, чего не хватает',
      PackageAlertAction.remove,
    );
  }
  if (isSparse(package)) {
    return const PackageAlert(
      PackageAlertTone.info,
      'Дополните карточку',
      'Фото, место и срок помогут быстрее найти упаковку и вовремя '
          'заметить просрочку',
      PackageAlertAction.complete,
    );
  }
  if (status == MedicineStatus.unknown && needsAfterOpeningTerm(package)) {
    return const PackageAlert(
      PackageAlertTone.info,
      'Нужен срок после вскрытия',
      'Укажите его из инструкции — без него не поймём, можно ли '
          'пользоваться открытым флаконом',
      PackageAlertAction.setAfterOpening,
    );
  }
  if (status == MedicineStatus.unknown) {
    return const PackageAlert(
      PackageAlertTone.info,
      'Срок не указан',
      'Найдите на упаковке «Годен до» или «EXP» — иначе не сможем '
          'предупредить о просрочке',
      PackageAlertAction.setExpiry,
    );
  }
  if (status == MedicineStatus.expiringSoon) {
    final days = package.daysUntilExpiry(now) ?? 0;
    if (openingShortensTerm(package)) {
      return PackageAlert(
        PackageAlertTone.warning,
        days <= 0
            ? 'Срок после вскрытия истекает сегодня'
            : 'После вскрытия осталось ${_days(days)}',
        'Открытый флакон хранится меньше, чем указано на упаковке',
      );
    }
    return PackageAlert(
      PackageAlertTone.warning,
      days <= 0
          ? 'Срок истекает сегодня'
          : 'Срок истекает через ${_days(days)}',
      'Используйте эту упаковку первой',
    );
  }
  if (course != null) {
    final days = course.daysLeft;
    return PackageAlert(
      days == null ? PackageAlertTone.info : PackageAlertTone.warning,
      days == null
          ? 'В курсе «${course.course.name}»'
          : days <= 0
          ? 'В курсе «${course.course.name}» · не хватит на сегодня'
          : 'В курсе «${course.course.name}» · хватит на ${_days(days)}',
      [
        if (course.dose.isNotEmpty) '${course.dose}.',
        if (course.deducts)
          'Остаток уменьшается, когда вы отмечаете «Принял»',
      ].join(' '),
      PackageAlertAction.openCourse,
      course.course.id,
    );
  }
  final kind = stockKindOf(package);
  if (kind == StockKind.count &&
      package.quantity <= lowStockThreshold) {
    return PackageAlert(
      PackageAlertTone.warning,
      'Осталось ${quantityLabel(package.quantity, package.unit)}',
      'Проверьте, хватит ли до конца лечения',
      PackageAlertAction.kitState,
    );
  }
  if (kind == StockKind.level &&
      package.stockLevel == StockLevel.almostEmpty) {
    return const PackageAlert(
      PackageAlertTone.warning,
      'Почти закончилось',
      'Проверьте, хватит ли до конца лечения',
      PackageAlertAction.kitState,
    );
  }
  if (needsFridge(package)) {
    return const PackageAlert(
      PackageAlertTone.info,
      'Хранить в холодильнике',
      'При 2–8 °C, не замораживать',
    );
  }
  return null;
}

enum ExpiryTone { ok, warning, fail, muted }

/// The «expiry» block of the «pack hero».
class PackageExpiry {
  const PackageExpiry({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.note,
  });

  /// «Срок до», «Срок истёк», «Использовать до», «Срок».
  final String label;
  final String value;

  /// File name in `assets/icons/figma/`.
  final String icon;
  final ExpiryTone tone;

  /// «На упаковке — до мая 2027» when opening shortened the term.
  final String? note;
}

PackageExpiry packageExpiry(
  Medicine package,
  DateTime now, {
  int warningDays = 30,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final status = package.statusAt(now, warningDays: warningDays);
  final expiry = package.effectiveExpiryDate;
  final printed = package.expiryDate;
  String? printedNote() => printed == null
      ? null
      : 'На упаковке — до ${monthGenitive(printed)} ${printed.year}';
  if (status == MedicineStatus.expired) {
    final ago = timeAgo(expiry!, today);
    if (expiredAfterOpening(package, now)) {
      return PackageExpiry(
        label: 'Срок после вскрытия истёк',
        value: ago,
        icon: 'status-fail-16',
        tone: ExpiryTone.fail,
        note: printedNote(),
      );
    }
    return PackageExpiry(
      label: 'Срок истёк',
      value: ago,
      icon: 'status-fail-16',
      tone: ExpiryTone.fail,
    );
  }
  if (status == MedicineStatus.unknown &&
      needsAfterOpeningTerm(package) &&
      (printed != null || package.noExpiry)) {
    return PackageExpiry(
      label: 'Использовать до',
      value: 'Неизвестно',
      icon: 'status-unknown-16',
      tone: ExpiryTone.ok,
      note: printedNote(),
    );
  }
  if (status == MedicineStatus.unknown) {
    return const PackageExpiry(
      label: 'Срок',
      value: 'Не указан',
      icon: 'status-unknown-16',
      tone: ExpiryTone.ok,
    );
  }
  if (expiry == null) {
    return const PackageExpiry(
      label: 'Срок',
      value: 'Без срока годности',
      icon: 'status-ok-16',
      tone: ExpiryTone.ok,
    );
  }
  final opened =
      package.afterOpeningExpiry != null &&
      package.afterOpeningExpiry == expiry;
  final note = opened && printed != null && printed != expiry
      ? printedNote()
      : null;
  final label = opened ? 'Использовать до' : 'Срок до';
  if (isUsedUp(package)) {
    return PackageExpiry(
      label: label,
      value: monthYear(expiry),
      icon: 'status-empty-16',
      tone: ExpiryTone.muted,
      note: note,
    );
  }
  if (status == MedicineStatus.expiringSoon) {
    return PackageExpiry(
      label: label,
      value: compactDate(expiry),
      icon: 'status-warning-18',
      tone: ExpiryTone.warning,
      note: note,
    );
  }
  return PackageExpiry(
    label: label,
    value: opened ? compactDate(expiry) : monthYear(expiry),
    icon: 'status-ok-16',
    tone: ExpiryTone.ok,
    note: note,
  );
}

enum OpenedTone { ok, warning, fail, unknown }

/// The «opened block» (874:12607): «После вскрытия».
class OpenedSummary {
  const OpenedSummary({
    required this.openedAt,
    required this.term,
    required this.tone,
    this.progress,
    this.text,
  });

  /// «15 октября 2026».
  final String openedAt;

  /// «30 дней» or «Не указан».
  final String term;
  final OpenedTone tone;

  /// Share of the term already used, 0…1; null when the term is unknown.
  final double? progress;

  /// «Осталось 16 из 30 дней», «Срок после вскрытия истёк 2 месяца назад».
  final String? text;
}

OpenedSummary? openedSummary(
  Medicine package,
  DateTime now, {
  int warningDays = 30,
}) {
  final openedAt = package.openedAt;
  if (openedAt == null) return null;
  final opened = compactDate(openedAt);
  final total = package.afterOpeningDays;
  final end = package.afterOpeningExpiry;
  if (total == null || end == null) {
    return OpenedSummary(
      openedAt: opened,
      term: 'Не указан',
      tone: OpenedTone.unknown,
    );
  }
  final today = DateTime(now.year, now.month, now.day);
  final left = end.difference(today).inDays;
  if (left < 0) {
    return OpenedSummary(
      openedAt: opened,
      term: afterOpeningLabel(total),
      tone: OpenedTone.fail,
      progress: 1,
      text: 'Срок после вскрытия истёк ${timeAgo(end, today).toLowerCase()}',
    );
  }
  final used = (total - left).clamp(0, total);
  final ofDays = total % 10 == 1 && total % 100 != 11 ? 'дня' : 'дней';
  return OpenedSummary(
    openedAt: opened,
    term: afterOpeningLabel(total),
    tone: left <= warningDays ? OpenedTone.warning : OpenedTone.ok,
    progress: total == 0 ? 1 : used / total,
    text: left == 0
        ? 'Срок после вскрытия истекает сегодня'
        : 'Осталось $left из $total $ofDays',
  );
}

/// «Сегодня», «10 дней назад», «2 месяца назад», «1 год назад».
String timeAgo(DateTime date, DateTime today) {
  final days = DateTime(today.year, today.month, today.day)
      .difference(DateTime(date.year, date.month, date.day))
      .inDays;
  if (days <= 0) return 'Сегодня';
  if (days <= 30) return '${_days(days)} назад';
  var months = (today.year - date.year) * 12 + today.month - date.month;
  if (today.day < date.day) months--;
  if (months < 1) months = 1;
  if (months < 12) {
    return '${russianCount(months, 'месяц', 'месяца', 'месяцев')} назад';
  }
  final years = months ~/ 12;
  return '${russianCount(years, 'год', 'года', 'лет')} назад';
}

/// The dose and the package count the same thing, so «Принял» in a course
/// takes it from the remainder. Drops cannot be subtracted from a bottle.
bool intakeDeductsStock(MedicationReminder reminder, Medicine package) {
  if (reminder.courseId == null) return false;
  final a = reminder.unit.toLowerCase();
  final b = package.unit.toLowerCase();
  return a == b ||
      (a.startsWith('таблет') && b.startsWith('таблет')) ||
      (a.startsWith('капсул') && b.startsWith('капсул')) ||
      (a.startsWith('флакон') && b.startsWith('флакон'));
}

/// The package in a running treatment course (879:14534).
class PackageCourse {
  const PackageCourse({
    required this.course,
    required this.dose,
    required this.deducts,
    this.daysLeft,
  });

  final TreatmentCourse course;

  /// «По 1 таблетке 3 раза в день».
  final String dose;

  /// Intakes take from this package's remainder.
  final bool deducts;

  /// Days the remainder lasts when it runs out before the course ends;
  /// null when it lasts to the end or is not counted.
  final int? daysLeft;
}

PackageCourse? packageCourse(AppState state, Medicine package, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  for (final course in state.courses) {
    if (course.status != CourseStatus.active || course.isCompletedAt(today)) {
      continue;
    }
    final reminders = [
      for (final r in state.reminders)
        if (r.enabled && r.courseId == course.id && r.medicineId == package.id)
          r,
    ];
    if (reminders.isEmpty) continue;
    final deducts =
        stockKindOf(package) == StockKind.count &&
        reminders.every((r) => intakeDeductsStock(r, package));
    return PackageCourse(
      course: course,
      dose: courseDose(reminders),
      deducts: deducts,
      daysLeft: deducts
          ? _supplyDays(state, course, reminders, package.quantity, today)
          : null,
    );
  }
  return null;
}

/// Counts the days the remainder covers, from today to the course end
/// (a year for an open course). Intakes already marked today are taken
/// from the remainder already. Null when it lasts.
int? _supplyDays(
  AppState state,
  TreatmentCourse course,
  List<MedicationReminder> reminders,
  int quantity,
  DateTime today,
) {
  final start = treatmentDay(course.startsAt);
  final end = course.endsAt ?? today.add(const Duration(days: 365));
  var remaining = quantity;
  var days = 0;
  for (
    var day = start.isAfter(today) ? start : today;
    !day.isAfter(end);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    var demand = 0;
    for (final r in reminders) {
      if (!r.occursOn(day, course.startsAt)) continue;
      final marked =
          day == today &&
          state.intakeRecords.any(
            (record) => record.reminderId == r.id && record.day == today,
          );
      if (!marked) demand += r.amount;
    }
    if (demand == 0) continue;
    if (remaining <= 0) return days;
    days++;
    remaining -= demand;
    if (remaining < 0) return days;
  }
  return null;
}

/// «По 1 таблетке 3 раза в день».
String courseDose(List<MedicationReminder> reminders) {
  if (reminders.isEmpty) return '';
  final first = reminders.first;
  final same = reminders.every(
    (r) => r.amount == first.amount && r.unit == first.unit,
  );
  final times = russianCount(reminders.length, 'раз', 'раза', 'раз');
  final schedule = switch (first.frequency) {
    _ when reminders.any((r) => r.frequency != first.frequency) =>
      'по схеме курса',
    IntakeFrequency.daily => '$times в день',
    IntakeFrequency.alternate => '$times в день через день',
    IntakeFrequency.weekdays => '$times в день по дням недели',
    IntakeFrequency.cycles => '$times в день циклами',
  };
  if (!same || first.amount <= 0) {
    return '${schedule[0].toUpperCase()}${schedule.substring(1)}';
  }
  return 'По ${_doseAmount(first.amount, first.unit)} $schedule';
}

/// «1 таблетке», «2 таблетки», «5 капель» — after «по».
String _doseAmount(int amount, String unit) {
  const forms = <String, (String, String, String)>{
    'таблет': ('таблетке', 'таблетки', 'таблеток'),
    'капсул': ('капсуле', 'капсулы', 'капсул'),
    'капл': ('капле', 'капли', 'капель'),
    'пакетик': ('пакетику', 'пакетика', 'пакетиков'),
    'доз': ('дозе', 'дозы', 'доз'),
    'флакон': ('флакону', 'флакона', 'флаконов'),
  };
  final lower = unit.trim().toLowerCase();
  for (final MapEntry(key: stem, value: (one, few, many)) in forms.entries) {
    if (lower.startsWith(stem)) return russianCount(amount, one, few, many);
  }
  return lower.isEmpty ? '$amount' : '$amount ${unit.trim()}';
}

/// «Дом · Сумка в прихожей»: another package always names its kit.
String otherPackageTitle(AppState state, Medicine package) {
  final kit = state.kitById(package.pharmacyId)?.name ?? '';
  final place = package.location.trim();
  if (kit.isEmpty) return place.isEmpty ? 'Не указано' : place;
  return place.isEmpty ? kit : '$kit · $place';
}

/// «Всего у вас 28 таблеток в 2 аптечках» under «Другие упаковки»: only
/// when every package is counted in the same pieces.
String? packagesTotal(Medicine package, List<Medicine> others) {
  final all = [package, ...others];
  if (all.any((m) => stockKindOf(m) != StockKind.count)) return null;
  String unitOf(Medicine m) =>
      quantityLabel(5, m.unit).replaceFirst('5', '').trim();
  final unit = unitOf(package);
  if (unit.isEmpty || all.any((m) => unitOf(m) != unit)) return null;
  final total = all.fold<int>(0, (sum, m) => sum + m.quantity);
  final kits = all.map((m) => m.pharmacyId).toSet().length;
  final amount = quantityLabel(total, package.unit);
  if (kits < 2) return 'Всего у вас $amount';
  final word = kits % 10 == 1 && kits % 100 != 11 ? 'аптечке' : 'аптечках';
  return 'Всего у вас $amount в $kits $word';
}

/// «Ибупрофен, 200 мг».
String packageTitle(Medicine package) {
  final name = readableDrugName(package.name);
  final dose = package.dosage.trim();
  return dose.isEmpty ? name : '$name, $dose';
}

/// «Где лежит»: the place, prefixed by the kit when it is not the open one
/// («Дача · ящик в прихожей»).
String placeLabel(AppState state, Medicine package) {
  final place = package.location.trim();
  final kit = state.kitById(package.pharmacyId);
  final otherKit = kit != null && kit.id != state.selectedPharmacyId;
  if (place.isEmpty) return otherKit ? kit.name : 'Не указано';
  return otherKit ? '${kit.name} · $place' : place;
}

/// The same medicine (name, form, dose) in other packages of any kit.
List<Medicine> otherPackages(AppState state, Medicine package) => [
  for (final item in state.medicines)
    if (item.id != package.id && item.groupKey == package.groupKey) item,
];

/// «4 таблетки · срок до 22 сентября 2026».
String otherPackageSubtitle(Medicine package, DateTime now) {
  final status = package.statusAt(now);
  final expiry = package.effectiveExpiryDate;
  final term = switch (status) {
    MedicineStatus.expired => 'срок истёк',
    MedicineStatus.unknown => 'срок не указан',
    _ when expiry == null => 'без срока годности',
    MedicineStatus.expiringSoon => 'срок до ${compactDate(expiry)}',
    _ => 'срок до ${monthGenitive(expiry)} ${expiry.year}',
  };
  return '${amountLabel(package)} · $term';
}

/// «Характеристики»: only the values the package has.
List<(String, String)> packageSpecs(Medicine package) {
  String? clean(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
  final form = clean(package.form);
  final dose = clean(package.dosage);
  final ingredient = clean(package.activeIngredient);
  final contents = clean(package.packageDescription);
  final storage = clean(package.storage);
  final gtin = clean(package.gtin);
  return [
    if (form != null) ('Форма выпуска', readableDrugText(form)),
    if (dose != null) ('Дозировка', dose),
    if (ingredient != null) ('Действующее вещество', readableDrugText(ingredient)),
    if (contents != null) ('В упаковке', readableDrugText(contents)),
    if (storage != null) ('Условия хранения', storage),
    if (gtin != null) ('Штрихкод', formatBarcode(gtin)),
  ];
}

/// EAN-13 grouped as on the package: «4 601234 567890». GTIN-14 with a
/// leading zero is shown as EAN-13.
String formatBarcode(String gtin) {
  var digits = gtin.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 14 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length != 13) return gtin.trim();
  return '${digits[0]} ${digits.substring(1, 7)} ${digits.substring(7)}';
}

/// «обновлено 20 октября» under the remainder.
String stockCaption(Medicine package, DateTime now) {
  final date = package.stockUpdatedAt ?? package.updatedAt ?? package.addedAt;
  return date == null ? '' : 'обновлено ${_dayMonth(date, now)}';
}

/// «Добавлено 12 октября 2026 · изменено 20 октября».
String? packageMetaLine(Medicine package, DateTime now) {
  final added = package.addedAt;
  final changed = package.updatedAt;
  final parts = [
    if (added != null) 'Добавлено ${compactDate(added)}',
    if (changed != null && (added == null || !_sameDay(added, changed)))
      '${added == null ? 'Изменено' : 'изменено'} ${_dayMonth(changed, now)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

const _nominative = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

/// «Сентябрь 2028».
String monthYear(DateTime date) =>
    '${_nominative[date.month - 1]} ${date.year}';

/// «мая» — the month in «до мая 2027».
String monthGenitive(DateTime date) => shortDate(date).split(' ').last;

String _dayMonth(DateTime date, DateTime now) =>
    date.year == now.year ? shortDate(date) : compactDate(date);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _days(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'день'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'дня'
      : 'дней';
  return '$n $word';
}

/// Pieces in a whole package by the catalog description («2 x БЛИСТЕР по
/// 10 шт» → 20) when they are counted in the same units as the remainder;
/// «в упаковке было 20» (880:14866).
int? packagePieces(Medicine package) {
  final description = package.packageDescription?.trim() ?? '';
  if (description.isEmpty || stockKindOf(package) != StockKind.count) {
    return null;
  }
  final label = describeDrugPackage(
    DrugCatalogEntry(
      id: '',
      name: package.name,
      activeIngredient: '',
      form: package.form,
      dosage: package.dosage,
      unit: package.unit,
      packageDescription: description,
    ),
  );
  final pieces = label.quantity;
  final unit = label.quantityUnit;
  if (pieces == null || unit == null) return null;
  final stem = unit.substring(0, unit.length < 5 ? unit.length : 5);
  return package.unit.trim().toLowerCase().startsWith(stem) ? pieces : null;
}

/// «Почему убираете?» (880:15272).
enum RemovalReason {
  expired('Срок истёк, выбросили'),
  finished('Закончилось'),
  lost('Отдали или потеряли'),
  mistake('Добавлено по ошибке');

  const RemovalReason(this.label);
  final String label;
}

/// The answer that fits the package: expired or used up; otherwise none is
/// picked in advance.
RemovalReason? suggestedRemovalReason(
  Medicine package,
  DateTime now, {
  int warningDays = 30,
}) {
  if (package.statusAt(now, warningDays: warningDays) ==
      MedicineStatus.expired) {
    return RemovalReason.expired;
  }
  if (isUsedUp(package)) return RemovalReason.finished;
  return null;
}
