import 'package:aptechka/features/medicines/domain/medicine.dart';

enum PackageTone { fail, warning, ok, muted }

/// The status line of the Figma «medicine card» (851:10817).
class PackageStatusLine {
  const PackageStatusLine(this.icon, this.text, this.tone);

  /// File name in `assets/icons/figma/`.
  final String icon;
  final String text;
  final PackageTone tone;
}

const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String _plural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

String _days(int n) => '$n ${_plural(n, 'день', 'дня', 'дней')}';

PackageStatusLine packageStatusLine(
  Medicine package,
  DateTime now, {
  int warningDays = 30,
}) {
  final today = DateTime(now.year, now.month, now.day);
  if (package.quantity <= 0) {
    return const PackageStatusLine('filter-out', 'Закончилось', PackageTone.muted);
  }
  final status = package.statusAt(now, warningDays: warningDays);
  final expiry = package.effectiveExpiryDate;
  final afterOpening = package.afterOpeningExpiry;
  switch (status) {
    case MedicineStatus.expired:
      final ago = today.difference(expiry!).inDays;
      final what = afterOpening != null && afterOpening == expiry
          ? 'Срок после вскрытия истёк'
          : 'Срок истёк';
      return PackageStatusLine(
        'status-fail-16',
        ago <= 0 ? '$what сегодня' : '$what ${_days(ago)} назад',
        PackageTone.fail,
      );
    case MedicineStatus.unknown:
      return const PackageStatusLine(
        'status-unknown-16',
        'Срок не указан',
        PackageTone.muted,
      );
    case MedicineStatus.expiringSoon || MedicineStatus.okay:
      final soon = status == MedicineStatus.expiringSoon;
      final icon = soon ? 'status-soon-16' : 'status-ok-16';
      final tone = soon ? PackageTone.warning : PackageTone.muted;
      if (afterOpening != null && package.openedAt != null) {
        final left = afterOpening.difference(today).inDays;
        return PackageStatusLine(icon, 'Вскрыт · ещё ${_days(left)}', tone);
      }
      if (expiry == null) {
        return const PackageStatusLine(
          'status-ok-16',
          'Без срока годности',
          PackageTone.muted,
        );
      }
      final date = expiry;
      return PackageStatusLine(
        icon,
        soon
            ? 'Срок до ${date.day} ${_months[date.month - 1]} ${date.year}'
            : 'Срок до ${_months[date.month - 1]} ${date.year}',
        tone,
      );
  }
}

/// «Требуют внимания»: expired, expiring soon or used up.
bool needsAttention(Medicine package, DateTime now, {int warningDays = 30}) {
  if (package.quantity <= 0) return true;
  final status = package.statusAt(now, warningDays: warningDays);
  return status == MedicineStatus.expired ||
      status == MedicineStatus.expiringSoon;
}

/// Russian forms of stock units, keyed by stem.
const _units = <String, (String, String, String)>{
  'таблет': ('таблетка', 'таблетки', 'таблеток'),
  'капсул': ('капсула', 'капсулы', 'капсул'),
  'флакон': ('флакон', 'флакона', 'флаконов'),
  'пакетик': ('пакетик', 'пакетика', 'пакетиков'),
  'саше': ('саше', 'саше', 'саше'),
  'свеч': ('свеча', 'свечи', 'свечей'),
  'ампул': ('ампула', 'ампулы', 'ампул'),
  'тюбик': ('тюбик', 'тюбика', 'тюбиков'),
  'упаков': ('упаковка', 'упаковки', 'упаковок'),
  'пластыр': ('пластырь', 'пластыря', 'пластырей'),
  'драже': ('драже', 'драже', 'драже'),
};

/// «4 таблетки», «1 флакон», «10 мл»; «Больше половины» for packages
/// tracked by level and «Без учёта» when the stock is not counted.
String amountLabel(Medicine package) {
  if (!package.tracksStock) return 'Без учёта';
  if (package.stockLevel case final level?) return level.label;
  return quantityLabel(package.quantity, package.unit);
}

/// «20 таблеток», «1 шт.», «10 мл».
String quantityLabel(int quantity, String unit) {
  final trimmed = unit.trim();
  final lower = trimmed.toLowerCase();
  for (final MapEntry(key: stem, value: forms) in _units.entries) {
    if (lower.startsWith(stem)) {
      final (one, few, many) = forms;
      return '$quantity ${_plural(quantity, one, few, many)}';
    }
  }
  return trimmed.isEmpty ? '$quantity' : '$quantity $trimmed';
}

/// Form icon from the Figma «icons / Types of medications» set.
String formIcon(String form, {String unit = ''}) {
  final text = '${form.toLowerCase()} ${unit.toLowerCase()}';
  bool has(List<String> stems) => stems.any(text.contains);
  if (has(['таблет', 'капсул', 'драже', 'пастил'])) return 'form/pills';
  if (has(['капл', 'сироп', 'суспенз', 'раствор', 'флакон', 'мл'])) {
    return 'form/drops';
  }
  if (has(['мазь', 'крем', 'гель', 'бальзам'])) return 'form/cream';
  if (has(['спрей', 'аэрозол', 'ингалят'])) return 'form/spray';
  if (has(['порош', 'гранул', 'пакет', 'саше'])) return 'form/powder';
  if (has(['пластыр', 'бинт', 'повяз', 'вата'])) return 'form/bandage';
  if (has(['инъек', 'ампул', 'шприц'])) return 'form/syringe';
  return 'form/other';
}
