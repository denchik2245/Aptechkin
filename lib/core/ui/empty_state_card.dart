import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:flutter/material.dart';

/// White 358 pt card with an illustration overlapping its top edge
/// («Аптечки / Пусто» 671:1432, «Список лекарств / Пусто» 671:1336). The
/// empty filters (833:7630) have only the title.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    required this.image,
    required this.title,
    this.text = '',
    this.buttonLabel,
    this.onPressed,
    this.imageZoom = 1,
    super.key,
  });

  /// Asset path of the illustration, drawn in a 200 pt box at y −66.
  final String image;
  final String title;
  final String text;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  /// Some Figma fills crop the picture (e.g. 111.46 % for image 58).
  final double imageZoom;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 358),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 134, 24, 24),
            decoration: BoxDecoration(
              color: palette.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.h2.copyWith(color: palette.textPrimary),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
                if (buttonLabel case final label?) ...[
                  const SizedBox(height: 24),
                  AppButton(label: label, onPressed: onPressed),
                ],
              ],
            ),
          ),
          Positioned(
            top: -66,
            child: SizedBox.square(
              dimension: 200,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: 200 * imageZoom,
                  maxHeight: 200 * imageZoom,
                  child: Image.asset(
                    image,
                    width: 200 * imageZoom,
                    height: 200 * imageZoom,
                    excludeFromSemantics: true,
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
