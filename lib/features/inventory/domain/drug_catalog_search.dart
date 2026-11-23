import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_variant.dart';
import 'package:aptechka/features/inventory/domain/drug_name_matching.dart';

/// Rules of the Figma «Добавление / 4 · Поиск по названию» (890:15549):
/// search by trade name and by active ingredient, typo suggestions, and the
/// texts of the «catalog item» rows.

/// A catalog name group with its normalized name and ingredients.
class IndexedDrugGroup {
  IndexedDrugGroup(this.group)
    : name = normalizeDrugQuery(group.name),
      ingredients = {
        for (final entry in group.entries)
          if (entry.activeIngredient.trim().isNotEmpty)
            normalizeDrugQuery(entry.activeIngredient),
      }.toList(growable: false);

  final DrugCatalogGroup group;
  final String name;
  final List<String> ingredients;
}

List<IndexedDrugGroup> indexDrugGroups(List<DrugCatalogEntry> entries) => [
  for (final group in groupDrugCatalogEntries(entries)) IndexedDrugGroup(group),
];

class DrugSearchResult {
  const DrugSearchResult({
    this.byName = const [],
    this.byIngredient = const [],
    this.ingredient,
    this.similar = const [],
  });

  /// «По названию»: the name starts with the query.
  final List<DrugCatalogGroup> byName;

  /// «Содержат ибупрофен»: other names with the ingredient.
  final List<DrugCatalogGroup> byIngredient;

  /// «ибупрофен» for the «Содержат …» label.
  final String? ingredient;

  /// «Похожие» when nothing matches as typed; the first is «Возможно, вы
  /// искали».
  final List<DrugCatalogGroup> similar;

  bool get isEmpty => byName.isEmpty && byIngredient.isEmpty && similar.isEmpty;
}

final _words = RegExp(r'[a-zа-я0-9]+');

bool _ingredientMatches(String ingredient, String query) =>
    ingredient.startsWith(query) ||
    _words.allMatches(ingredient).any((m) => m.group(0)!.startsWith(query));

DrugSearchResult searchDrugGroups(List<IndexedDrugGroup> groups, String text) {
  final query = normalizeDrugQuery(text);
  if (query.isEmpty) return const DrugSearchResult();
  final byName = <DrugCatalogGroup>[];
  final byIngredient = <IndexedDrugGroup>[];
  for (final item in groups) {
    if (item.name.startsWith(query)) {
      byName.add(item.group);
    } else if (query.length >= 3 &&
        item.ingredients.any((value) => _ingredientMatches(value, query))) {
      byIngredient.add(item);
    }
  }
  if (byName.isNotEmpty || byIngredient.isNotEmpty) {
    return DrugSearchResult(
      byName: byName,
      byIngredient: [for (final item in byIngredient) item.group],
      ingredient: byIngredient.isEmpty
          ? null
          : _ingredientLabel(byIngredient.first.group, query),
    );
  }
  final similar = <({DrugCatalogGroup group, int distance})>[];
  for (final item in groups) {
    final distance = drugNameTypoDistance(item.name, query);
    if (distance != null) similar.add((group: item.group, distance: distance));
  }
  similar.sort((a, b) {
    final distance = a.distance.compareTo(b.distance);
    return distance != 0
        ? distance
        : drugNameSortKey(a.group.name)
              .compareTo(drugNameSortKey(b.group.name));
  });
  return DrugSearchResult(similar: [for (final item in similar) item.group]);
}

/// The ingredient the query matched, as written in the catalog, in lower
/// case: «ибупрофен».
String? _ingredientLabel(DrugCatalogGroup group, String query) {
  for (final entry in group.entries) {
    for (final part in entry.activeIngredient.split(RegExp(r'\s*\+\s*'))) {
      if (_ingredientMatches(normalizeDrugQuery(part), query)) {
        return readableDrugText(part).toLowerCase();
      }
    }
  }
  return null;
}

/// «Парацетамол, 500 мг» when every package has the same dose, else the
/// name alone.
String drugGroupTitle(DrugCatalogGroup group) {
  final doses = {
    for (final entry in group.entries)
      if (entry.dosage.trim().isNotEmpty) entry.dosage.trim(),
  };
  return doses.length == 1 &&
          group.entries.every((e) => e.dosage.trim().isNotEmpty)
      ? '${group.name}, ${doses.single}'
      : group.name;
}

/// «Таблетки» from «Таблетки, покрытые пленочной оболочкой».
String shortDrugForm(String form) {
  final word = RegExp(r'[A-Za-zА-Яа-яЁё]+').firstMatch(readableDrugText(form));
  if (word == null) return 'Форма не указана';
  final text = word.group(0)!.toLowerCase();
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

/// «Таблетки, капсулы · 8 вариантов»; with [ingredient] a combination shows
/// its ingredients instead of the count: «Таблетки · ибупрофен + парацетамол».
String drugGroupDetails(DrugCatalogGroup group, {bool ingredient = false}) {
  final forms = <String>[];
  for (final entry in group.entries) {
    final form = shortDrugForm(entry.form).toLowerCase();
    if (!forms.contains(form)) forms.add(form);
  }
  // Three forms at most: some names come in a dozen.
  var formText = forms.length > 3
      ? '${forms.take(3).join(', ')}…'
      : forms.join(', ');
  if (formText.isNotEmpty) {
    formText = '${formText[0].toUpperCase()}${formText.substring(1)}';
  }
  final combination = group.entries.first.activeIngredient.contains('+');
  final tail = ingredient && combination
      ? readableDrugText(group.entries.first.activeIngredient).toLowerCase()
      : russianCount(group.variants.length, 'вариант', 'варианта', 'вариантов');
  return formText.isEmpty ? tail : '$formText · $tail';
}

/// «Нурофен, 200 мг» on a variant row.
String drugVariantTitle(DrugCatalogEntry entry) {
  final dose = entry.dosage.trim();
  return dose.isEmpty ? entry.displayName : '${entry.displayName}, $dose';
}

/// «Таблетки · 10 шт.», «Суспензия · 100 мл».
String drugVariantDetails(DrugCatalogVariant variant) {
  final entry = variant.entry;
  final pieces = variant.package.quantity;
  final description = readableDrugText(entry.packageDescription).trim();
  final String size;
  if (pieces != null) {
    size = '$pieces шт.';
  } else if (description.isEmpty) {
    size = '';
  } else {
    final index = description.toLowerCase().lastIndexOf(' по ');
    final text = index < 0 ? description : description.substring(index + 4);
    size = text.toLowerCase();
  }
  final form = shortDrugForm(entry.form);
  return size.isEmpty ? form : '$form · $size';
}

/// Form chips of «Поиск / Варианты препарата»: «Таблетки · 6».
List<(String, int)> drugVariantForms(List<DrugCatalogVariant> variants) {
  final counts = <String, int>{};
  for (final variant in variants) {
    final form = shortDrugForm(variant.entry.form);
    counts[form] = (counts[form] ?? 0) + 1;
  }
  return [for (final MapEntry(:key, :value) in counts.entries) (key, value)];
}
