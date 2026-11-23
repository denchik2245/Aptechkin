import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Figma «chip» (715:2445): card with a divider border, or `surface/choice`
/// when selected. Label/Large text, optional 16 pt icon.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tintIcon = false,
    this.whiteWhenSelected = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? icon;

  /// Paints a one-colour [icon] like the label (e.g. «search-16»).
  final bool tintIcon;

  /// Keeps the icon's own colours, but paints it white when selected
  /// (the «Для чего» chips, 894:17683).
  final bool whiteWhenSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.surfaceChoice : palette.surfaceCard,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : BorderSide(color: palette.divider),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  DesignIcon(
                    icon!,
                    size: 16,
                    color: selected && (tintIcon || whiteWhenSelected)
                        ? palette.textOnAccent
                        : tintIcon
                        ? palette.textPrimary
                        : null,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(
                      color: selected
                          ? palette.textOnAccent
                          : palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
