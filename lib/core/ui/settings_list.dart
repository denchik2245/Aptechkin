import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/chevron_arrow.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Figma «settings / icon / …» (1154:23704): a white 20 pt icon from
/// `assets/icons/figma/settings/` on a coloured tile. The «settings row»
/// tile is 30×30 with radius 8; the «Как сохранить» cards use 36×36 / 10.
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile(
    this.icon, {
    required this.color,
    this.size = 30,
    this.radius = 8,
    this.iconSize = 20,
    super.key,
  });

  /// File name in `assets/icons/figma/settings/` without `.svg`.
  final String icon;
  final Color color;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: DesignIcon(
      'settings/$icon',
      size: iconSize,
      color: context.palette.textOnAccent,
    ),
  );
}

/// Right side of a [SettingsRow]: value + chevron, switch, check or nothing.
enum SettingsTrailing { chevron, toggle, check, none }

/// Figma «settings row» (1154:23861): optional icon tile, Body/Medium title
/// with a Body/Small detail, and a trailing value + chevron, switch or check.
/// Min height 56, padding 16 × 12, gaps 12.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    this.icon,
    this.iconColor,
    this.trailing = SettingsTrailing.chevron,
    this.toggled = false,
    this.onChanged,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Body/Paragraph text before the chevron («Вкл.», «Вс, 10:00»).
  final String? value;

  /// `text/secondary` by default; brand blue for actions like «Проверить».
  final Color? valueColor;

  /// Icon name in `assets/icons/figma/settings/`; no tile when `null`.
  final String? icon;
  final Color? iconColor;
  final SettingsTrailing trailing;

  /// Switch position for [SettingsTrailing.toggle].
  final bool toggled;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isToggle = trailing == SettingsTrailing.toggle;
    final tap = isToggle && onChanged != null
        ? () => onChanged!(!toggled)
        : onTap;
    final row = InkWell(
      onTap: tap,
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _content(context, maxValueWidth: constraints.maxWidth / 2),
      ),
    );
    return Semantics(
      button: !isToggle && tap != null,
      toggled: isToggle ? toggled : null,
      selected: trailing == SettingsTrailing.check ? true : null,
      enabled: tap != null,
      child: MergeSemantics(child: row),
    );
  }

  Widget _content(BuildContext context, {required double maxValueWidth}) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              SettingsIconTile(icon!, color: iconColor ?? palette.brandPrimary),
              const SizedBox(width: 12),
            ],
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
            if (trailing == SettingsTrailing.chevron && value != null) ...[
              const SizedBox(width: 12),
              // At most half the row, so large text wraps instead of
              // overflowing on a 320 pt screen.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxValueWidth),
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  style: AppTypography.paragraph.copyWith(
                    color: valueColor ?? palette.textSecondary,
                  ),
                ),
              ),
            ],
            switch (trailing) {
              SettingsTrailing.chevron => const Padding(
                padding: EdgeInsets.only(left: 12),
                child: ChevronArrow(),
              ),
              SettingsTrailing.toggle => Padding(
                padding: const EdgeInsets.only(left: 12),
                child: ExcludeSemantics(
                  child: CupertinoSwitch(
                    value: toggled,
                    onChanged: onChanged,
                    activeTrackColor: palette.brandPrimary,
                    inactiveTrackColor: palette.buttonSecondary,
                  ),
                ),
              ),
              SettingsTrailing.check => Padding(
                padding: const EdgeInsets.only(left: 12),
                child: DesignIcon(
                  'check-mark-20',
                  size: 20,
                  color: palette.textPrimary,
                ),
              ),
              SettingsTrailing.none => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}

/// Figma «group» of settings rows: white card with radius 16 and
/// «settings divider» lines between rows — after the icon tile (58 pt,
/// [SettingsGroup.icons]) or from the text edge (16 pt).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key}) : inset = 16;

  /// Rows with icon tiles: «settings divider / inset=icon».
  const SettingsGroup.icons({required this.children, super.key}) : inset = 58;

  final List<Widget> children;
  final double inset;

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
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.only(left: inset),
                child: Container(height: 1, color: palette.divider),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A block of a settings screen: Body/Medium `text/secondary` header,
/// content and a Body/Small footnote, both inset by 16, with 8 pt gaps.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.child,
    this.title,
    this.footnote,
    super.key,
  });

  final String? title;
  final Widget child;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              header: true,
              child: Text(
                title!,
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        child,
        if (footnote != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              footnote!,
              style: AppTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// White card with radius 16 and 16 pt padding («card» on settings screens).
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.palette.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: child,
  );
}
