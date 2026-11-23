import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_variant.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/package_form.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/scanner/domain/scanned_code.dart';

/// Rules of the Figma «Добавление / 3 · Несколько упаковок подряд»
/// (890:15548): a scanned package is added from a quick card under the
/// camera, and the batch ends with a summary.

/// Stock of a new package from the catalog, the same as the package form
/// gives by default: the whole package in pieces, a full bottle, or no
/// count for devices.
class QuickStock {
  const QuickStock({
    required this.quantity,
    required this.unit,
    required this.tracksStock,
    this.stockLevel,
  });

  final int quantity;
  final String unit;
  final bool tracksStock;
  final StockLevel? stockLevel;
}

QuickStock quickStockFor(DrugCatalogEntry entry) {
  final form = entry.form;
  final catalogUnit = entry.unit.trim();
  final mode = stockModeFor(form, unit: catalogUnit);
  final lower = catalogUnit.toLowerCase();
  final countable =
      lower.isNotEmpty &&
      lower != 'мл' &&
      !lower.startsWith('флакон') &&
      !lower.startsWith('тюбик');
  final package = describeDrugPackage(entry);
  final size =
      package.quantity != null &&
          (lower == package.quantityUnit || lower == 'шт.')
      ? package.quantity
      : null;
  return switch (mode) {
    StockMode.level => QuickStock(
      quantity: 1,
      unit: containerFor(form),
      tracksStock: true,
      stockLevel: StockLevel.full,
    ),
    StockMode.off => const QuickStock(
      quantity: 1,
      unit: 'шт.',
      tracksStock: false,
    ),
    StockMode.count => QuickStock(
      quantity: size ?? 1,
      unit: countable ? catalogUnit : countUnitFor(form),
      tracksStock: true,
    ),
  };
}

/// The source line of the quick card: «Срок до мая 2027 — из кода» when the
/// code carries the date, otherwise how the package was found.
String quickSourceLine(ScannedCode code) {
  final expiry = code.expiry;
  if (expiry != null) {
    final month = shortDate(expiry).split(' ').last;
    return 'Срок до $month ${expiry.year} — из кода';
  }
  return code.kind == ScanKind.dataMatrix
      ? 'Найдено по DataMatrix-коду'
      : 'Найдено по штрихкоду';
}

/// The place chip picked first: the one used last in this batch, else the
/// first place of the kit.
String? quickDefaultPlace(List<String> places, String? lastUsed) {
  if (lastUsed != null && places.contains(lastUsed)) return lastUsed;
  return places.firstOrNull;
}

/// «Несколько / Итог» (892:17128).
class BatchSummary {
  const BatchSummary({
    required this.packages,
    required this.title,
    required this.text,
  });

  /// Added packages that are still there, in the order they were added.
  final List<Medicine> packages;

  /// «5 упаковок добавлено в «Дом»».
  final String title;

  /// «У одной не указан срок — её отметили, чтобы вернуться позже».
  final String? text;
}

BatchSummary batchSummary(AppState state, List<String> ids) {
  final byId = {for (final item in state.medicines) item.id: item};
  final packages = [for (final id in ids) ?byId[id]];
  final kits = {for (final item in packages) item.pharmacyId};
  final kit = kits.length == 1 ? state.kitById(kits.single)?.name : null;
  final count = russianCount(
    packages.length,
    'упаковка',
    'упаковки',
    'упаковок',
  );
  final added = packages.length == 1 ? 'добавлена' : 'добавлено';
  final missing = packages
      .where((item) => item.expiryDate == null && !item.noExpiry)
      .length;
  return BatchSummary(
    packages: packages,
    title: kit == null ? '$count $added' : '$count $added в «$kit»',
    text: switch (missing) {
      0 => null,
      1 => 'У одной не указан срок — её отметили, чтобы вернуться позже',
      _ => 'У $missing не указан срок — их отметили, чтобы вернуться позже',
    },
  );
}
