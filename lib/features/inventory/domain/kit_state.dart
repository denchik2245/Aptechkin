import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_search.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';

/// Categories of «Состояние аптечки» (863:12157), built from the «Для чего»
/// marks. The enum name is used in the route.
enum KitCategory {
  fever(
    'Температура и боль',
    'purpose/fever',
    [MedicinePurpose.fever, MedicinePurpose.headache],
    'Нет лекарств от температуры и боли',
  ),
  ear(
    'Боль в ухе',
    'purpose/ear',
    [MedicinePurpose.ear],
    'Нет лекарств от боли в ухе',
  ),
  allergy(
    'Аллергия',
    'purpose/allergy',
    [MedicinePurpose.allergy],
    'Нет лекарств от аллергии',
  ),
  wounds(
    'Ушибы и раны',
    'purpose/wounds',
    [MedicinePurpose.wounds],
    'Нет средств от ушибов и ран',
  ),
  runnyNose(
    'Насморк',
    'purpose/runny_nose',
    [MedicinePurpose.runnyNose],
    'Нет лекарств от насморка',
  ),
  cough(
    'Кашель',
    'purpose/cough',
    [MedicinePurpose.cough],
    'Нет лекарств от кашля',
  ),
  throat(
    'Горло',
    'symptom/throat',
    [MedicinePurpose.throat],
    'Нет лекарств для горла',
  ),
  stomach(
    'Живот',
    'purpose/stomach',
    [MedicinePurpose.stomach],
    'Нет лекарств для живота',
  );

  const KitCategory(this.label, this.icon, this.purposes, this.emptyTitle);
  final String label;

  /// Icon in `assets/icons/figma/`; «Горло» has no «icons / Purpose» one.
  final String icon;
  final List<MedicinePurpose> purposes;

  /// Title of «Пустая категория» (863:12448).
  final String emptyTitle;

  /// «Ни в одной аптечке нет лекарств с отметкой «Аллергия». …».
  String get emptyText {
    final marks = [for (final purpose in purposes) '«${purpose.label}»'];
    final mark = marks.length == 1
        ? 'отметкой ${marks.single}'
        : 'отметками ${marks.join(' или ')}';
    return 'Ни в одной аптечке нет лекарств с $mark. Если такое лекарство '
        'уже есть, добавьте отметку в его карточке.';
  }

  static KitCategory? parse(String? value) =>
      values.where((item) => item.name == value).firstOrNull;
}

/// «category row» levels: none — no usable package, low — one usable or
/// all expiring soon, enough — two or more usable.
enum CategoryLevel { none, low, enough }

/// One category of one kit.
class KitCategoryState {
  const KitCategoryState({
    required this.category,
    required this.level,
    required this.here,
    required this.usable,
    required this.elsewhere,
    required this.allSoon,
  });

  final KitCategory category;
  final CategoryLevel level;

  /// Every package of the category in the kit, soonest date first.
  final List<Medicine> here;

  /// Not expired and not used up, in this kit.
  final List<Medicine> usable;

  /// Usable packages of the category in the other kits.
  final List<Medicine> elsewhere;

  /// Every usable package expires soon.
  final bool allSoon;

  int get expired => here.length - usable.length - usedUp;

  int get usedUp => here.where((package) => package.quantity <= 0).length;

  /// Nothing of the category anywhere: «Пустая категория».
  bool get isEmpty => here.isEmpty && elsewhere.isEmpty;

  /// Second line of the row; no names, so it is never cut.
  String get summary {
    switch (level) {
      case CategoryLevel.enough:
        return _packages(usable.length);
      case CategoryLevel.low:
        if (!allSoon) return _packages(usable.length);
        final verb = usable.length == 1 ? 'скоро истечёт' : 'скоро истекут';
        return '${_packages(usable.length)} · $verb';
      case CategoryLevel.none:
        if (expired > 0) return 'Годных нет · $expired с истёкшим сроком';
        if (elsewhere.isNotEmpty) return 'Есть только в другой аптечке';
        if (here.isNotEmpty) return 'Годных нет · закончились';
        return 'Лекарств нет';
    }
  }
}

String _packages(int count) =>
    russianCount(count, 'упаковка', 'упаковки', 'упаковок');

bool _usable(Medicine package, DateTime now, int warningDays) =>
    package.quantity > 0 &&
    package.statusAt(now, warningDays: warningDays) != MedicineStatus.expired;

/// Rows of «Состояние аптечки» for [kitId]: «Нет или мало» first (none
/// before low), then «Достаточно», each in the category order.
List<KitCategoryState> kitCategories(
  AppState state,
  String kitId,
  DateTime now, {
  int warningDays = 30,
}) {
  final rows = [
    for (final category in KitCategory.values)
      kitCategory(state, kitId, category, now, warningDays: warningDays),
  ];
  return [
    for (final level in CategoryLevel.values)
      ...rows.where((row) => row.level == level),
  ];
}

KitCategoryState kitCategory(
  AppState state,
  String kitId,
  KitCategory category,
  DateTime now, {
  int warningDays = 30,
}) {
  bool inCategory(Medicine package) => category.purposes.any(package.isFor);
  final here = [
    for (final package in state.medicinesIn(kitId))
      if (inCategory(package)) package,
  ]..sort(compareByExpiry);
  final usable = [
    for (final package in here)
      if (_usable(package, now, warningDays)) package,
  ];
  final elsewhere = [
    for (final kit in state.pharmacies)
      if (kit.id != kitId)
        for (final package in state.medicinesIn(kit.id))
          if (inCategory(package) && _usable(package, now, warningDays))
            package,
  ]..sort(compareByExpiry);
  final allSoon =
      usable.isNotEmpty &&
      usable.every(
        (package) =>
            package.statusAt(now, warningDays: warningDays) ==
            MedicineStatus.expiringSoon,
      );
  final level = usable.isEmpty
      ? CategoryLevel.none
      : usable.length == 1 || allSoon
      ? CategoryLevel.low
      : CategoryLevel.enough;
  return KitCategoryState(
    category: category,
    level: level,
    here: here,
    usable: usable,
    elsewhere: elsewhere,
    allSoon: allSoon,
  );
}

/// Subtitle of «Состояние аптечки» in the kit menu (827:6006):
/// «В 5 категориях лекарств нет или мало».
String kitStateSummary(List<KitCategoryState> rows) {
  final count = rows.where((row) => row.level != CategoryLevel.enough).length;
  if (count == 0) return 'Во всех категориях достаточно';
  return 'В ${russianCount(count, 'категории', 'категориях', 'категориях')} '
      'лекарств нет или мало';
}

enum CategoryBannerTone { warning, fail, info }

/// The «status banner» of «Состояние аптечки / Категория» (863:12343).
class CategoryBanner {
  const CategoryBanner(this.tone, this.title, this.text);
  final CategoryBannerTone tone;
  final String title;
  final String text;
}

/// «Осталось мало» / «Годных нет» / «В «Доме» нет»; `null` when there is
/// enough or nothing at all.
CategoryBanner? categoryBanner(
  AppState state,
  String kitId,
  KitCategoryState row,
  DateTime now,
) {
  final other = row.elsewhere.isEmpty
      ? 'В других аптечках нет'
      : foundInKitsText(state, row.elsewhere, verb: 'Ещё есть');
  switch (row.level) {
    case CategoryLevel.enough:
      return null;
    case CategoryLevel.low:
      final String first;
      if (row.usable.length == 1) {
        final package = row.usable.single;
        final today = DateTime(now.year, now.month, now.day);
        final opened = package.openedAt != null &&
            package.afterOpeningExpiry != null &&
            package.afterOpeningExpiry == package.effectiveExpiryDate;
        final left = package.effectiveExpiryDate?.difference(today).inDays;
        final when = left == null || left <= 0 ? null : _days(left);
        first = opened
            ? when == null
                  ? 'Одна упаковка, и та вскрыта — использовать сегодня'
                  : 'Одна упаковка, и та вскрыта — использовать ещё $when'
            : row.allSoon
            ? when == null
                  ? 'Одна упаковка, и её срок истекает сегодня'
                  : 'Одна упаковка, и её срок истекает через $when'
            : 'Одна упаковка';
      } else {
        first = '${_packages(row.usable.length)}, у всех скоро истекает срок';
      }
      return CategoryBanner(
        CategoryBannerTone.warning,
        'Осталось мало',
        '$first. $other',
      );
    case CategoryLevel.none:
      if (row.expired > 0) {
        return CategoryBanner(
          CategoryBannerTone.fail,
          'Годных нет',
          '${_packages(row.expired)} с истёкшим сроком — их лучше убрать. '
              '$other',
        );
      }
      if (row.here.isNotEmpty) {
        return CategoryBanner(
          CategoryBannerTone.warning,
          'Закончилось',
          '${row.here.length == 1 ? 'Упаковка закончилась' : 'Все упаковки закончились'}. '
              '$other',
        );
      }
      if (row.elsewhere.isEmpty) return null;
      final kit = state.pharmacies.where((item) => item.id == kitId);
      return CategoryBanner(
        CategoryBannerTone.info,
        '${kitLocative(kit.isEmpty ? '' : kit.first.name)} нет',
        foundInKitsText(state, row.elsewhere),
      );
  }
}

String _days(int n) => russianCount(n, 'день', 'дня', 'дней');
