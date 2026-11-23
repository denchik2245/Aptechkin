import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Figma component «Expiration date» (671:2093):
/// «Все в норме», «Скоро истекут», «Просрочены», «Просрочено + Скоро».
class ExpirySummary extends StatelessWidget {
  const ExpirySummary({
    required this.expired,
    required this.soon,
    this.okLabel = 'В норме',
    this.longSoonLabel = false,
    this.expiredText,
    this.soonText,
    super.key,
  });

  /// Overrides for illustrative copy, e.g. «2 просрочены» in onboarding.
  final String? expiredText;
  final String? soonText;

  final int expired;
  final int soon;
  final String okLabel;

  /// «3 скоро истекут» when only soon items exist (as on the swipe frame).
  final bool longSoonLabel;

  static String expiredLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return '$count истёк';
    return '$count истекли';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = AppTypography.bodyMedium.copyWith(color: palette.textPrimary);
    Widget item(String icon, String text, double gap) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignIcon(icon, size: 18),
        SizedBox(width: gap),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: value,
          ),
        ),
      ],
    );
    final both = expired > 0 && soon > 0;
    final List<Widget> items = [
      if (expired > 0) item('status-fail-18', expiredText ?? expiredLabel(expired), 6),
      if (soon > 0)
        item(
          'status-soon-18',
          soonText ??
              (!both && longSoonLabel ? '$soon скоро истекут' : '$soon скоро'),
          both ? 5 : 6,
        ),
      if (expired == 0 && soon == 0) item('status-ok-18', okLabel, 6),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сроки годности',
          style: AppTypography.caption.copyWith(color: palette.textMuted),
        ),
        SizedBox(height: both ? 4 : 3),
        Wrap(spacing: 16, runSpacing: 4, children: items),
      ],
    );
  }
}
