import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Hero area of the Figma onboarding frames: a 390×446 design box whose
/// children are placed by their centre offset from the box centre, exactly
/// like the `left: calc(50% + dx); top: calc(50% + dy)` reference layout.
/// The box scales down on short screens and never scales up.
class OnboardingHero extends StatelessWidget {
  const OnboardingHero({required this.children, this.height = 446, super.key});

  final List<HeroItem> children;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 390,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              for (final item in children)
                Transform.translate(offset: item.offset, child: item.child),
            ],
          ),
        ),
      ),
    ),
  );
}

class HeroItem {
  const HeroItem(this.dx, this.dy, this.child);
  final double dx;
  final double dy;
  final Widget child;
  Offset get offset => Offset(dx, dy);
}

/// Illustration from `assets/illustrations/onboarding/`.
class HeroImage extends StatelessWidget {
  const HeroImage(this.name, {required this.size, super.key});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/illustrations/onboarding/$name.png',
    width: size,
    height: size,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
  );
}

const _floatingShadow = [
  BoxShadow(color: Color(0x141C1A33), blurRadius: 12, offset: Offset(0, 8)),
];
const _cardShadow = [
  BoxShadow(color: Color(0x141C1A33), blurRadius: 24, offset: Offset(0, 8)),
];

/// Figma «kit chip» (684:940): kit icon, name and number of medicines.
class KitChip extends StatelessWidget {
  const KitChip({
    required this.icon,
    required this.name,
    required this.count,
    super.key,
  });

  final String icon;
  final String name;
  final String count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: _floatingShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignIcon(icon, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              Text(
                count,
                style: AppTypography.labelMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Floating card with a round tinted badge and up to three text lines
/// («opened card» 695:1059 and «scan result» 685:1061).
class BadgeCard extends StatelessWidget {
  const BadgeCard({
    required this.badgeIcon,
    required this.badgeColor,
    required this.lines,
    super.key,
  });

  final String badgeIcon;
  final Color badgeColor;
  final List<Text> lines;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 24, 14),
    decoration: BoxDecoration(
      color: context.palette.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: _cardShadow,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: DesignIcon(badgeIcon, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 2),
              lines[i],
            ],
          ],
        ),
      ],
    ),
  );
}

/// Plain floating card («expiration card» 685:1014).
class FloatingCard extends StatelessWidget {
  const FloatingCard({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.palette.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: _cardShadow,
    ),
    child: child,
  );
}

/// Figma «push» (684:930): an app notification preview.
class PushPreview extends StatelessWidget {
  const PushPreview({
    required this.title,
    required this.body,
    this.width = 310,
    super.key,
  });
  final String title;
  final String body;

  /// 310 in onboarding; `null` stretches it («Так выглядит сводка»).
  final double? width;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final meta = AppTypography.labelMedium.copyWith(
      color: palette.textSecondary,
    );
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: _floatingShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AppBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Аптечкин', style: meta),
                    Text('сейчас', style: meta),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «app icon» inside the push: brand square with a white cross.
class _AppBadge extends StatelessWidget {
  const _AppBadge();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget bar(double left, double top, double width, double height) =>
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.textOnAccent,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        );
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.brandPrimary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Stack(children: [bar(11, 17, 18, 6), bar(17, 11, 6, 18)]),
    );
  }
}

/// Headline and paragraph of the «Bottom» block, centred.
class OnboardingText extends StatelessWidget {
  const OnboardingText({required this.title, required this.text, super.key});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.h1Tight.copyWith(color: palette.textPrimary),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.paragraph.copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }
}
