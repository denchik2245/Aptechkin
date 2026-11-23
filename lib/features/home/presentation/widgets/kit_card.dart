import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/expiry_summary.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/core/ui/chevron_arrow.dart';
import 'package:aptechka/features/home/presentation/widgets/kit_icon_view.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:flutter/material.dart';

/// Figma «kit card» (823:4970): head with icon, name and access line,
/// divider, foot with the expiry summary, «Проверено …» and the count.
class KitCard extends StatelessWidget {
  const KitCard({
    required this.kit,
    required this.summary,
    required this.now,
    required this.onTap,
    super.key,
  });

  final Pharmacy kit;
  final KitSummary summary;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final access = kit.accessLabel;
    return Material(
      color: palette.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: [
                  KitIconView(kit.icon, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.h2.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        if (access != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            access,
                            style: AppTypography.bodySmall.copyWith(
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
            Container(height: 1, color: palette.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _Foot(kit: kit, summary: summary, now: now),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card foot. Side by side as in Figma; stacked when large text would not
/// fit the 358 pt card.
class _Foot extends StatelessWidget {
  const _Foot({required this.kit, required this.summary, required this.now});
  final Pharmacy kit;
  final KitSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final checkedLabel = checkedAgoLabel(kit.checkedAt, now);
    final expiry = ExpirySummary(
      expired: summary.expired,
      soon: summary.soon,
      okLabel: summary.total == 0 ? 'Нет лекарств' : 'В норме',
    );
    Widget count(CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: [
        Text(
          checkedLabel,
          textAlign: align == CrossAxisAlignment.end
              ? TextAlign.end
              : TextAlign.start,
          style: AppTypography.labelMedium.copyWith(
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          russianCount(summary.total, 'лекарство', 'лекарства', 'лекарств'),
          style: AppTypography.bodyMedium.copyWith(color: palette.textPrimary),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // The right column keeps its natural width (as in Figma); stack the
        // foot when it would leave the expiry summary less than 140 pt.
        final painter = TextPainter(
          text: TextSpan(text: checkedLabel, style: AppTypography.labelMedium),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final rightWidth = painter.width;
        painter.dispose();
        if (constraints.maxWidth - rightWidth - 12 < 140) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              expiry,
              const SizedBox(height: 12),
              count(CrossAxisAlignment.start),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: expiry),
            const SizedBox(width: 12),
            count(CrossAxisAlignment.end),
          ],
        );
      },
    );
  }
}

