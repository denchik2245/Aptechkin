import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/chevron_arrow.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_variant.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_card.dart';
import 'package:flutter/material.dart';

/// Figma «catalog item», type «form» (889:15558): the catalog entry at the
/// top of the package form — 56×72 photo, name with dosage, form with the
/// package size, the source, and «Изменить».
class CatalogItemCard extends StatelessWidget {
  const CatalogItemCard({
    required this.entry,
    required this.onChange,
    this.showPhoto = true,
    this.actionLabel = 'Изменить',
    this.actionSemantics = 'Изменить препарат',
    this.source,
    super.key,
  });

  final DrugCatalogEntry entry;
  final VoidCallback onChange;

  /// «Изменить» in the form, «Подробнее» on the scanner's quick card
  /// (890:15548).
  final String actionLabel;
  final String actionSemantics;

  /// Replaces «Из справочника · …», e.g. «Срок до мая 2027 — из кода».
  final String? source;

  /// `false` when the entry stands for several packages and the photo of
  /// one of them could mislead.
  final bool showPhoto;

  static String titleOf(DrugCatalogEntry entry) => entry.dosage.trim().isEmpty
      ? entry.displayName
      : '${entry.displayName}, ${entry.dosage.trim()}';

  /// «Таблетки · 20 шт. в упаковке», «Суспензия · флакон 100 мл».
  static String detailsOf(DrugCatalogEntry entry) {
    final package = describeDrugPackage(entry);
    final form = entry.displayForm;
    final String size;
    if (package.quantity != null) {
      size = '${package.quantity} шт. в упаковке';
    } else if (entry.packageDescription.trim().isEmpty) {
      return form;
    } else {
      final text = entry.displayPackage;
      size = text.isEmpty ? '' : text[0].toLowerCase() + text.substring(1);
    }
    return [form, size].where((part) => part.isNotEmpty).join(' · ');
  }

  static String sourceOf(DrugCatalogEntry entry) =>
      entry.manufacturer.trim().isEmpty
      ? 'Из справочника'
      : 'Из справочника · ${entry.displayManufacturer}';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: PackagePhoto.gtin(
              gtin: showPhoto ? entry.gtin : null,
              name: entry.name,
              width: 56,
              height: 72,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleOf(entry),
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detailsOf(entry),
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  source ?? sourceOf(entry),
                  style: AppTypography.caption.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: actionSemantics,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onChange,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  actionLabel,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.brandPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma «catalog item», type «list» (889:15566): a row in the search and
/// the variants — 56×72 photo, title, details, an optional source line and
/// a chevron.
class CatalogListItem extends StatelessWidget {
  const CatalogListItem({
    required this.title,
    required this.details,
    required this.onTap,
    this.gtin,
    this.photoName = '',
    this.source,
    super.key,
  });

  final String title;
  final String details;
  final String? source;

  /// The photo of this GTIN, when the catalog has one.
  final String? gtin;
  final String photoName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      child: Material(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: PackagePhoto.gtin(
                    gtin: gtin,
                    name: photoName,
                    width: 56,
                    height: 72,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        style: AppTypography.bodySmall.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      if (source case final source? when source.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          source,
                          style: AppTypography.caption.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const ChevronArrow(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
