import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Figma component «radio card» (843:10363). Selected: 2 pt brand border;
/// otherwise a 1 pt divider border. Optional [extra] is shown under the
/// text only while selected (e.g. the «Куда» chooser).
class RadioCard extends StatelessWidget {
  const RadioCard({
    required this.title,
    required this.selected,
    this.subtitle,
    required this.onTap,
    this.extra,
    this.badge,
    this.footer,
    super.key,
  });

  final String title;

  /// Without it the card is a single line, e.g. «Полный» (880:14960).
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? extra;

  /// Shown next to the title, e.g. «Сейчас здесь».
  final Widget? badge;

  /// Shown under the subtitle, e.g. the expiry status line.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: palette.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected
              ? BorderSide(color: palette.brandPrimary, width: 2)
              : BorderSide(color: palette.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // Figma padding 16 sits inside the 2 / 1 pt border.
            padding: EdgeInsets.all(selected ? 18 : 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    selected
                        ? const DesignIcon('radio-on-22', size: 22)
                        : Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.divider,
                                width: 2,
                              ),
                            ),
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                title,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                              ?badge,
                            ],
                          ),
                          if (subtitle case final subtitle?
                              when subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: AppTypography.bodySmall.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                          if (footer != null) ...[
                            const SizedBox(height: 2),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (selected && extra != null) ...[
                  const SizedBox(height: 12),
                  extra!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «choice» row inside a radio card: label, value and chevron.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              DesignIcon('chevron-16', size: 16, color: palette.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
