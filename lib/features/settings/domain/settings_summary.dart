import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/package_detail.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';

/// Labels and counts of the «Настройки» screens (1194:16667 … 1194:16671).

const weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// «Как в системе» on the main screen, «Как на устройстве» on «Оформление».
String appearanceLabel(AppAppearance appearance, {bool onDevice = false}) =>
    switch (appearance) {
      AppAppearance.system => onDevice ? 'Как на устройстве' : 'Как в системе',
      AppAppearance.light => 'Светлая',
      AppAppearance.dark => 'Тёмная',
    };

String textScaleLabel(double scale) => scale >= 1.3
    ? 'Ещё крупнее'
    : scale > 1
    ? 'Крупнее'
    : 'Как на устройстве';

String switchLabel(bool on) => on ? 'Вкл.' : 'Выкл.';

/// «10:00».
String timeLabel(int minutes) =>
    '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

/// «Срок — за 30 дней · остаток — 2 ед.»
String thresholdsLabel(AppSettings settings) =>
    'Срок — за ${russianCount(settings.expiryWarningDays, 'день', 'дня', 'дней')}'
    ' · остаток — ${settings.lowStockThreshold} ед.';

/// «Вс, 10:00» — when the kit digest comes, or «Выкл.».
String digestScheduleLabel(AppSettings settings) =>
    settings.digestEnabled ? digestWhenLabel(settings) : switchLabel(false);

/// «Вс, 10:00», «Каждый день, 10:00» or «1-го числа, 10:00».
String digestWhenLabel(AppSettings settings) {
  final time = timeLabel(settings.digestMinutes);
  return switch (settings.digestFrequency) {
    DigestFrequency.daily => 'Каждый день, $time',
    DigestFrequency.weekly =>
      '${weekdayShort[settings.digestWeekday - 1]}, $time',
    DigestFrequency.monthly => '1-го числа, $time',
  };
}

/// The next digest strictly after [now]: every day, on the chosen weekday,
/// or on the 1st of the month, at the chosen time.
DateTime nextDigest(AppSettings settings, DateTime now) {
  final hour = settings.digestMinutes ~/ 60;
  final minute = settings.digestMinutes % 60;
  switch (settings.digestFrequency) {
    case DigestFrequency.daily:
      final today = DateTime(now.year, now.month, now.day, hour, minute);
      return today.isAfter(now)
          ? today
          : DateTime(now.year, now.month, now.day + 1, hour, minute);
    case DigestFrequency.weekly:
      for (var add = 0; add <= 7; add++) {
        final day = DateTime(now.year, now.month, now.day + add, hour, minute);
        if (day.weekday == settings.digestWeekday && day.isAfter(now)) {
          return day;
        }
      }
      throw StateError('unreachable');
    case DigestFrequency.monthly:
      final first = DateTime(now.year, now.month, 1, hour, minute);
      return first.isAfter(now)
          ? first
          : DateTime(now.year, now.month + 1, 1, hour, minute);
  }
}

/// «Следующая — вс, 8 ноября, 10:00»
String nextDigestLabel(DateTime at) =>
    'Следующая — ${weekdayShort[at.weekday - 1].toLowerCase()}, '
    '${shortDate(at)}, ${timeLabel(at.hour * 60 + at.minute)}';

/// Whether [package] counts as «Мало осталось» under [threshold]: a counted
/// package with 1…threshold units, or a level one that is almost empty.
/// Empty packages are marked separately («Пустые упаковки отмечаются всегда»).
bool isLowStock(Medicine package, int threshold) =>
    switch (stockKindOf(package)) {
      StockKind.count => package.quantity > 0 && package.quantity <= threshold,
      StockKind.level => package.stockLevel == StockLevel.almostEmpty,
      StockKind.off => false,
    };

/// «Сейчас под условия попадают» (1157:24590).
class ThresholdMatches {
  const ThresholdMatches({
    required this.total,
    required this.soon,
    required this.low,
  });

  /// Packages matching at least one condition.
  final int total;
  final int soon;
  final int low;

  /// «3 упаковки»
  String get title => russianCount(total, 'упаковка', 'упаковки', 'упаковок');

  /// «2 — срок истекает · 1 — мало осталось»
  String get details => [
    if (soon > 0) '$soon — срок истекает',
    if (low > 0) '$low — мало осталось',
  ].join(' · ');
}

ThresholdMatches thresholdMatches(AppState state, DateTime now) {
  final settings = state.settings;
  var total = 0, soon = 0, low = 0;
  for (final package in state.medicines) {
    final isSoon =
        package.statusAt(now, warningDays: settings.expiryWarningDays) ==
        MedicineStatus.expiringSoon;
    final isLow = isLowStock(package, settings.lowStockThreshold);
    if (isSoon) soon++;
    if (isLow) low++;
    if (isSoon || isLow) total++;
  }
  return ThresholdMatches(total: total, soon: soon, low: low);
}

/// «Что в копии» (1159:24755) and «Что изменится» (1159:24854).
class BackupSummary {
  const BackupSummary({
    required this.kits,
    required this.packages,
    required this.courses,
    required this.historySince,
  });

  factory BackupSummary.of(AppState state) {
    DateTime? since;
    for (final record in state.intakeRecords) {
      final at = record.scheduledDate ?? record.occurredAt;
      if (since == null || at.isBefore(since)) since = at;
    }
    return BackupSummary(
      kits: state.pharmacies.length,
      packages: state.medicines.length,
      courses: state.courses.length,
      historySince: since,
    );
  }

  final int kits;
  final int packages;
  final int courses;

  /// The earliest intake record, `null` without history.
  final DateTime? historySince;

  /// «с 1 сентября», or «нет».
  String historyLabel(DateTime now) {
    final since = historySince;
    if (since == null) return 'нет';
    return since.year == now.year
        ? 'с ${shortDate(since)}'
        : 'с ${compactDate(since)}';
  }

  /// «3 аптечки, 26 упаковок, 4 курса и история приёма»
  String get contentsLabel {
    final parts = [
      russianCount(kits, 'аптечка', 'аптечки', 'аптечек'),
      russianCount(packages, 'упаковка', 'упаковки', 'упаковок'),
      russianCount(courses, 'курс', 'курса', 'курсов'),
      if (historySince != null) 'история приёма',
    ];
    return '${parts.take(parts.length - 1).join(', ')} и ${parts.last}';
  }
}

/// «6 ноября, 10:30»
String savedAtLabel(DateTime at) =>
    '${shortDate(at)}, ${timeLabel(at.hour * 60 + at.minute)}';

/// Value of «Резервная копия» on the main screen: «Нет», «Сегодня» or
/// the date of the last saved copy.
String lastBackupLabel(DateTime? at, DateTime now) {
  if (at == null) return 'Нет';
  if (at.year == now.year && at.month == now.month && at.day == now.day) {
    return 'Сегодня';
  }
  return at.year == now.year ? shortDate(at) : compactDate(at);
}
