import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/data/drug_photo_catalog.dart';
import 'package:aptechka/features/inventory/domain/package_status.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_photo_viewer.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Figma «medicine card» (851:10817): one physical package — photo 90×132,
/// name and dose, status line, place, «для чего» and amount tags.
class PackageCard extends StatelessWidget {
  const PackageCard({
    required this.package,
    required this.now,
    required this.warningDays,
    required this.onTap,
    this.place,
    this.statusNote,
    super.key,
  });

  final Medicine package;
  final DateTime now;
  final int warningDays;
  final VoidCallback onTap;

  /// Replaces the package place, e.g. «Дом · Ящик стола» in the search by
  /// symptom (835:9238).
  final String? place;

  /// Added to the status line: «Закончилось · ибупрофен» when the search
  /// matched the active ingredient (835:8961).
  final String? statusNote;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = packageStatusLine(package, now, warningDays: warningDays);
    final statusColor = switch (status.tone) {
      PackageTone.fail => palette.fail,
      PackageTone.warning => palette.warning,
      PackageTone.ok || PackageTone.muted => palette.textSecondary,
    };
    final secondary = AppTypography.bodySmall.copyWith(
      color: palette.textSecondary,
    );
    final place = this.place ?? package.location.trim();
    final statusText = statusNote == null
        ? status.text
        : '${status.text} · $statusNote';
    return Material(
      color: palette.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 140),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PackagePhoto(package: package),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Expanded(
                                    child: Text(
                                      readableDrugName(package.name),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyLarge.copyWith(
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (package.dosage.trim().isNotEmpty) ...[
                                    const SizedBox(width: 10),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 96,
                                      ),
                                      child: Text(
                                        package.dosage.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.labelMedium
                                            .copyWith(
                                              color: palette.textSecondary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              _Line(
                                icon: status.icon,
                                text: statusText,
                                style: AppTypography.bodySmall.copyWith(
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _Line(
                                icon: 'pin-16',
                                text: place.isEmpty ? 'Место не указано' : place,
                                style: secondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (package.purposes.firstOrNull
                                  case final purpose?)
                                _Tag(icon: purpose.tagIcon, label: purpose.label)
                              else if (package.customPurpose
                                  case final custom?)
                                _Tag(icon: customPurposeIcon, label: custom),
                              _Tag(
                                icon: formIcon(package.form, unit: package.unit),
                                label: amountLabel(package),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, required this.style});
  final String icon;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      DesignIcon(icon, size: 16),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surfacePlate,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignIcon(icon, size: 16),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma «Image» (671:1984): photo by exact GTIN on white, or the
/// «without» placeholder — plate background with a 24 pt icon.
class PackagePhoto extends ConsumerWidget {
  PackagePhoto({
    required Medicine package,
    this.width = 90,
    this.height = 132,
    this.expandable = false,
    super.key,
  }) : gtin = package.catalogEntryId?.startsWith('mdlp:') == true
           ? package.catalogEntryId!.substring(5)
           : package.gtin,
       name = package.name;

  /// Photo of a catalog entry before the package is saved.
  const PackagePhoto.gtin({
    required this.gtin,
    required this.name,
    this.width = 90,
    this.height = 132,
    super.key,
  }) : expandable = false;

  final String? gtin;

  /// A tap opens the photo full screen (879:14917).
  final bool expandable;
  final String name;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final photo = ref.watch(drugPhotoProvider(gtin)).asData?.value;
    final placeholder = ColoredBox(
      color: palette.background,
      child: const Center(child: DesignIcon('form-bandage-24', size: 24)),
    );
    final box = SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: photo == null
            ? placeholder
            : ColoredBox(
                color: Colors.white,
                child: Image.asset(
                  photo.asset,
                  fit: BoxFit.contain,
                  semanticLabel:
                      'Фото упаковки ${readableDrugName(name)}',
                  errorBuilder: (_, _, _) => placeholder,
                ),
              ),
      ),
    );
    if (!expandable || photo == null) return box;
    return Semantics(
      container: true,
      button: true,
      label: 'Открыть фото',
      child: GestureDetector(
        onTap: () => showPackagePhoto(context, photo: photo, name: name),
        child: box,
      ),
    );
  }
}
