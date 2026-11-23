import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Figma «radio row» (889:15588) for long lists such as «Форма выпуска»:
/// the radio of «radio card», a 20 pt icon and a Body/Medium label. Rows
/// sit in one white group, divided from x = 50.
class RadioRowGroup extends StatelessWidget {
  const RadioRowGroup({required this.children, super.key});
  final List<RadioRow> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, row) in children.indexed) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Divider(height: 1, thickness: 1, color: palette.divider),
              ),
            row,
          ],
        ],
      ),
    );
  }
}

class RadioRow extends StatelessWidget {
  const RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// File name in `assets/icons/figma/`, drawn at 20 pt.
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (selected)
                const DesignIcon('radio-on-22', size: 22)
              else
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.divider, width: 2),
                  ),
                ),
              const SizedBox(width: 12),
              if (icon != null) ...[
                DesignIcon(icon!, size: 20),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
