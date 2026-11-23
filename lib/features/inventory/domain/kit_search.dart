import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';

/// «Что есть от…» chips of «Поиск по всем аптечкам» (835:8835), in the
/// Figma order, with the chip label («Горло», not «Боль в горле»).
const searchSymptoms = <(MedicinePurpose, String)>[
  (MedicinePurpose.fever, 'Температура'),
  (MedicinePurpose.headache, 'Головная боль'),
  (MedicinePurpose.runnyNose, 'Насморк'),
  (MedicinePurpose.cough, 'Кашель'),
  (MedicinePurpose.throat, 'Горло'),
  (MedicinePurpose.stomach, 'Живот'),
];

/// Lower case, «ё» as «е», single spaces.
String normalizeSearchText(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'\s+'), ' ');

/// The purpose whose label is the whole query («Температура»), so a tapped
/// chip and a typed symptom search the «Для чего» marks.
MedicinePurpose? symptomQuery(String query) {
  final normalized = normalizeSearchText(query);
  if (normalized.isEmpty) return null;
  for (final (purpose, label) in searchSymptoms) {
    if (normalizeSearchText(label) == normalized) return purpose;
  }
  return MedicinePurpose.values
      .where((purpose) => normalizeSearchText(purpose.label) == normalized)
      .firstOrNull;
}

/// One found package. [ingredient] is set when only the active ingredient
/// matched: the card adds it to the status line («Закончилось · ибупрофен»).
class KitSearchHit {
  const KitSearchHit(this.package, {this.ingredient});
  final Medicine package;
  final String? ingredient;
}

/// A titled list of cards: a kit («Дом · 3 упаковки») or a symptom group
/// («Можно использовать по сроку»).
class KitSearchGroup {
  const KitSearchGroup(this.title, this.hits);
  final String title;
  final List<KitSearchHit> hits;
}

sealed class KitSearchResult {
  const KitSearchResult();
}

/// Empty query: «Недавние» and «Что есть от…».
class KitSearchIdle extends KitSearchResult {
  const KitSearchIdle();
}

/// Search by name or active ingredient, grouped by kit — the selected kit
/// first (835:8961). [missing] is set when the selected kit has nothing
/// but other kits do (835:9077).
class KitSearchByName extends KitSearchResult {
  const KitSearchByName(this.groups, {this.missing});
  final List<KitSearchGroup> groups;
  final KitSearchMissing? missing;
}

/// «В «Доме» нет» banner.
class KitSearchMissing {
  const KitSearchMissing(this.title, this.text);
  final String title;
  final String text;
}

/// Search by a «Для чего» mark (835:9238): usable by date, without a date,
/// expired. Packages that ran out are left out.
class KitSearchBySymptom extends KitSearchResult {
  const KitSearchBySymptom(this.purpose, this.groups);
  final MedicinePurpose purpose;
  final List<KitSearchGroup> groups;
}

/// «Ни в одной аптечке нет» (835:9170).
class KitSearchNothing extends KitSearchResult {
  const KitSearchNothing(this.text, {this.purpose});
  final String text;

  /// Set when a symptom was searched: there is nothing to look up in the
  /// catalog then.
  final MedicinePurpose? purpose;
}

KitSearchResult searchKits(
  AppState state,
  String query,
  DateTime now, {
  int warningDays = 30,
}) {
  final normalized = normalizeSearchText(query);
  if (normalized.isEmpty) return const KitSearchIdle();
  final kits = _kitsInOrder(state);
  final kitCount = russianCount(
    kits.length,
    'аптечке',
    'аптечках',
    'аптечках',
  );
  final purpose = symptomQuery(query);
  if (purpose != null) {
    return _bySymptom(state, kits, purpose, now, warningDays, kitCount);
  }

  final groups = <KitSearchGroup>[];
  for (final kit in kits) {
    final hits = [
      for (final package in state.medicinesIn(kit.id))
        ?_match(package, normalized),
    ]..sort((a, b) => compareByExpiry(a.package, b.package));
    if (hits.isEmpty) continue;
    groups.add(KitSearchGroup(_kitTitle(kit, hits.length), hits));
  }
  if (groups.isEmpty) {
    return KitSearchNothing(
      'Искали «${query.trim()}» в $kitCount по названию '
      'и действующему веществу.',
    );
  }
  final selected = state.selectedPharmacyOrNull;
  final selectedHasHits =
      selected == null ||
      groups.any((group) => group.hits.first.package.pharmacyId == selected.id);
  return KitSearchByName(
    groups,
    missing: selectedHasHits ? null : _missing(state, selected, groups),
  );
}

KitSearchResult _bySymptom(
  AppState state,
  List<Pharmacy> kits,
  MedicinePurpose purpose,
  DateTime now,
  int warningDays,
  String kitCount,
) {
  final usable = <KitSearchHit>[];
  final undated = <KitSearchHit>[];
  final expired = <KitSearchHit>[];
  for (final kit in kits) {
    for (final package in state.medicinesIn(kit.id)) {
      if (!package.isFor(purpose) || package.quantity <= 0) continue;
      final hit = KitSearchHit(package);
      switch (package.statusAt(now, warningDays: warningDays)) {
        case MedicineStatus.okay || MedicineStatus.expiringSoon:
          usable.add(hit);
        case MedicineStatus.unknown:
          undated.add(hit);
        case MedicineStatus.expired:
          expired.add(hit);
      }
    }
  }
  int byDate(KitSearchHit a, KitSearchHit b) =>
      compareByExpiry(a.package, b.package);
  final groups = [
    if (usable.isNotEmpty)
      KitSearchGroup('Можно использовать по сроку', usable..sort(byDate)),
    if (undated.isNotEmpty) KitSearchGroup('Срок не указан', undated),
    if (expired.isNotEmpty)
      KitSearchGroup('Не используйте', expired..sort(byDate)),
  ];
  if (groups.isEmpty) {
    return KitSearchNothing(
      'Искали «${purpose.label}» в $kitCount по отметкам «Для чего».',
      purpose: purpose,
    );
  }
  return KitSearchBySymptom(purpose, groups);
}

KitSearchHit? _match(Medicine package, String query) {
  if (normalizeSearchText(package.name).contains(query)) {
    return KitSearchHit(package);
  }
  final ingredient = package.activeIngredient?.trim() ?? '';
  if (ingredient.isNotEmpty &&
      normalizeSearchText(ingredient).contains(query)) {
    return KitSearchHit(package, ingredient: ingredient.toLowerCase());
  }
  return null;
}

/// Selected kit first, the rest in the user's order.
List<Pharmacy> _kitsInOrder(AppState state) {
  final selected = state.selectedPharmacyOrNull;
  return [
    ?selected,
    for (final kit in state.pharmacies)
      if (kit.id != selected?.id) kit,
  ];
}

/// «Дом · 3 упаковки», «Аптечка мамы · общая», «Дача».
String _kitTitle(Pharmacy kit, int count) => [
  kit.name,
  if (kit.isShared || !kit.isOwn) 'общая',
  if (count > 1) russianCount(count, 'упаковка', 'упаковки', 'упаковок'),
].join(' · ');

/// Soonest date first, undated after dated, used up last.
int compareByExpiry(Medicine a, Medicine b) {
  int rank(Medicine item) {
    if (item.quantity <= 0) return 2;
    return item.effectiveExpiryDate == null ? 1 : 0;
  }

  final byRank = rank(a).compareTo(rank(b));
  if (byRank != 0) return byRank;
  final aDate = a.effectiveExpiryDate;
  final bDate = b.effectiveExpiryDate;
  if (aDate == null || bDate == null) return 0;
  return aDate.compareTo(bDate);
}

KitSearchMissing _missing(
  AppState state,
  Pharmacy selected,
  List<KitSearchGroup> groups,
) => KitSearchMissing(
  '${kitLocative(selected.name)} нет',
  foundInKitsText(state, [
    for (final group in groups)
      for (final hit in group.hits) hit.package,
  ], verb: 'Нашли'),
);

/// «Нашли в аптечке «Дача» — ящик в прихожей» (the place when all
/// [packages] lie in one), «Есть в аптечках «Дача» и «Машина»».
String foundInKitsText(
  AppState state,
  List<Medicine> packages, {
  String verb = 'Есть',
}) {
  final ids = <String>[];
  for (final package in packages) {
    if (!ids.contains(package.pharmacyId)) ids.add(package.pharmacyId);
  }
  final names = [
    for (final id in ids)
      state.pharmacies.where((kit) => kit.id == id).firstOrNull?.name ?? '',
  ];
  if (names.length == 1) {
    final places = {for (final package in packages) package.location.trim()};
    final place = places.length == 1 ? places.single : '';
    return place.isEmpty
        ? '$verb в аптечке «${names.single}»'
        : '$verb в аптечке «${names.single}» — ${_lowerFirst(place)}';
  }
  final quoted = [for (final name in names) '«$name»'];
  return '$verb в аптечках ${quoted.sublist(0, quoted.length - 1).join(', ')} '
      'и ${quoted.last}';
}

String _lowerFirst(String text) =>
    text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);

final _singleRussianWord = RegExp(r'^[А-ЯЁа-яё]+$');

/// «В «Доме»», «В «Даче»»; a name that cannot be safely declined keeps the
/// nominative: «В аптечке «Аптечка мамы»».
String kitLocative(String name) {
  final trimmed = name.trim();
  String quoted(String value) => 'В «$value»';
  if (!_singleRussianWord.hasMatch(trimmed) || trimmed.length < 3) {
    return 'В аптечке «$trimmed»';
  }
  final lower = trimmed.toLowerCase();
  final stem = trimmed.substring(0, trimmed.length - 1);
  if (lower.endsWith('ия')) return quoted('$stemи');
  if (lower.endsWith('а') || lower.endsWith('я')) return quoted('$stemе');
  const consonants = 'бвгджзклмнпрстфхцчшщ';
  if (consonants.contains(lower[lower.length - 1])) {
    return quoted('$trimmedе');
  }
  return 'В аптечке «$trimmed»';
}
