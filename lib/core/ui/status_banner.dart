import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

enum StatusBannerTone { warning, fail, info, ok }

/// Figma «status banner» (697:1093).
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.tone,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final StatusBannerTone tone;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (Color color, String icon) = switch (tone) {
      StatusBannerTone.warning => (palette.warning, 'status-warning-18'),
      StatusBannerTone.fail => (palette.fail, 'status-fail-18'),
      StatusBannerTone.info => (palette.brandPrimary, 'status-info-18'),
      StatusBannerTone.ok => (palette.success, 'status-ok-20'),
    };
    return Material(
      color: color.withValues(
        alpha: switch (tone) {
          StatusBannerTone.ok => 0.1,
          StatusBannerTone.info => 0.08,
          _ => 0.12,
        },
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAction,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DesignIcon(icon, size: tone == StatusBannerTone.ok ? 20.25 : 18),
              const SizedBox(width: 12),
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
                    // A title-only banner, e.g. the batch summary when every
                    // package has its date (892:17128).
                    if (text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style: AppTypography.bodySmall.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                    if (actionLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        actionLabel!,
                        // Figma: the «fail» action is red, others blue.
                        style: AppTypography.bodyMedium.copyWith(
                          color: tone == StatusBannerTone.fail
                              ? palette.fail
                              : palette.brandPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
