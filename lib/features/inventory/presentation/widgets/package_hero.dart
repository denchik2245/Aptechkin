import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/chevron_arrow.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/domain/package_detail.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_card.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';

/// Figma «pack hero» (874:12533): photo 131×192, description and the
/// expiry block. A used-up package shows its photo at half opacity.
class PackageHero extends StatelessWidget {
  const PackageHero({
    required this.package,
    required this.expiry,
    this.dimmed = false,
    super.key,
  });

  final Medicine package;
  final PackageExpiry expiry;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final valueColor = switch (expiry.tone) {
      ExpiryTone.ok => palette.textPrimary,
      ExpiryTone.warning => palette.warning,
      ExpiryTone.fail => palette.fail,
      ExpiryTone.muted => palette.textSecondary,
    };
    final caption = AppTypography.caption.copyWith(
      color: palette.textSecondary,
    );
    final description = package.description?.trim();
    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: dimmed ? 0.5 : 1,
              child: PackagePhoto(
                package: package,
                width: 131,
                height: 192,
                expandable: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      description == null || description.isEmpty
                          ? 'Описание не добавлено'
                          : description,
                      style: AppTypography.bodySmall.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      container: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(expiry.label, style: caption),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              DesignIcon(expiry.icon, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  expiry.value,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: valueColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (expiry.note != null) ...[
                            const SizedBox(height: 3),
                            Text(expiry.note!, style: caption),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of «pack facts» (884:15286).
class PackageFact {
  const PackageFact({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  /// File name in `assets/icons/figma/` (24 pt).
  final String icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
}

/// Figma «pack facts» (884:15286): «Где лежит» and «Для чего» in one card,
/// divider inset by 52. Values wrap freely; a row opens its editor.
class PackageFacts extends StatelessWidget {
  const PackageFacts({required this.facts, super.key});
  final List<PackageFact> facts;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Container(height: 1, color: palette.divider),
              ),
            _FactRow(fact: facts[i]),
          ],
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});
  final PackageFact fact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: fact.onTap != null,
      child: InkWell(
        onTap: fact.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              DesignIcon(fact.icon, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fact.label,
                      style: AppTypography.caption.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fact.value,
                      style: AppTypography.bodyMedium.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (fact.onTap != null) ...[
                const SizedBox(width: 12),
                const ChevronArrow(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma «opened block» (874:12607): «После вскрытия» — when it was opened,
/// the term after opening and how much of it is used. `unknown` shows no
/// progress, only «Указать срок из инструкции».
class OpenedBlock extends StatelessWidget {
  const OpenedBlock({required this.summary, this.onSetTerm, super.key});

  final OpenedSummary summary;

  /// «Указать срок из инструкции»; hidden without edit rights.
  final VoidCallback? onSetTerm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final divider = Container(height: 1, color: palette.divider);
    final unknown = summary.tone == OpenedTone.unknown;
    final (Color fill, Color text) = switch (summary.tone) {
      OpenedTone.warning => (palette.warning, palette.warning),
      OpenedTone.fail => (palette.fail, palette.fail),
      OpenedTone.ok || OpenedTone.unknown => (
        palette.brandPrimary,
        palette.textSecondary,
      ),
    };
    Widget row(String label, String value, {bool muted = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: muted ? palette.textSecondary : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              header: true,
              child: Text(
                'После вскрытия',
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          divider,
          const SizedBox(height: 12),
          row('Вскрыто', summary.openedAt),
          const SizedBox(height: 12),
          divider,
          const SizedBox(height: 12),
          row('Срок после вскрытия', summary.term, muted: unknown),
          if (summary.progress != null || (unknown && onSetTerm != null)) ...[
            const SizedBox(height: 12),
            divider,
            const SizedBox(height: 12),
          ],
          if (summary.progress != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 6,
                      color: palette.buttonSecondary,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: summary.progress!.clamp(0, 1),
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (summary.text != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      summary.text!,
                      style: AppTypography.bodySmall.copyWith(color: text),
                    ),
                  ],
                ],
              ),
            ),
          if (unknown && onSetTerm != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Semantics(
                  button: true,
                  child: InkWell(
                    onTap: onSetTerm,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        'Указать срок из инструкции',
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.brandPrimary,
                        ),
                      ),
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
