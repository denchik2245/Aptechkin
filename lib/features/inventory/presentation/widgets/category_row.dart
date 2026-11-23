import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/chevron_arrow.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/domain/kit_state.dart';
import 'package:flutter/material.dart';

/// Figma «category row» (863:12156): 44 pt icon plate, category name and a
/// level pill («Нет», «Мало», «Достаточно»), a one-line summary, arrow.
class CategoryRow extends StatelessWidget {
  const CategoryRow({required this.row, required this.onTap, super.key});

  final KitCategoryState row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (String pillIcon, String pillLabel) = switch (row.level) {
      CategoryLevel.none => ('status-empty-16', 'Нет'),
      CategoryLevel.low => ('status-soon-16', 'Мало'),
      CategoryLevel.enough => ('status-ok-16', 'Достаточно'),
    };
    return Semantics(
      button: true,
      label: '${row.category.label}, $pillLabel. ${row.summary}',
      excludeSemantics: true,
      child: Material(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.surfacePlate,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DesignIcon(row.category.icon, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.category.label,
                              style: AppTypography.bodyMedium.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Pill(icon: pillIcon, label: pillLabel),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: palette.surfacePlate,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignIcon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
