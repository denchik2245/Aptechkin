import 'package:aptechka/core/design/design.dart';
import 'package:flutter/material.dart';

/// Figma «segmented» (722:3328): two equal segments on `button/secondary`,
/// the active one is a card with a soft shadow. [small] is «segmented 3»
/// (1157:24382): Label/Large text and 9 pt vertical padding.
class AppSegmented extends StatelessWidget {
  const AppSegmented({
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.small = false,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.buttonSecondary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(vertical: small ? 9 : 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? palette.surfaceCard : null,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: i == selected
                          ? const [
                              BoxShadow(
                                color: Color(0x14000000),
                                offset: Offset(0, 2),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (small
                                  ? AppTypography.labelLarge
                                  : AppTypography.bodyMedium)
                              .copyWith(
                                color: i == selected
                                    ? palette.textPrimary
                                    : palette.textSecondary,
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
