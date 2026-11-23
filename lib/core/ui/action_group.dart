import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/chevron_arrow.dart';
import 'package:flutter/material.dart';

/// Figma «action row» (851:10840) grouped in a card with radius 20 and
/// dividers inset by 16 pt.
class ActionGroup extends StatelessWidget {
  const ActionGroup({required this.children, this.radius = 20, super.key});
  final List<Widget> children;

  /// 20 in menus and settings; 16 on the package card.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceCard,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Container(height: 1, color: palette.divider),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  const ActionRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Red title and no chevron («Удалить аптечку»).
  final bool destructive;

  /// Replaces the chevron (e.g. a drag handle).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: destructive ? palette.fail : palette.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.bodySmall.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!destructive) ...[
              const SizedBox(width: 12),
              trailing ?? const ChevronArrow(),
            ],
          ],
        ),
      ),
    );
  }
}
