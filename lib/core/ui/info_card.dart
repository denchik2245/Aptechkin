import 'package:aptechka/core/design/design.dart';
import 'package:flutter/material.dart';

/// Figma «how to use» card of the package (875:12569): Body/Large title,
/// Body/Small text, a caption and an optional link. The same card shows
/// «Заметка» (876:14171).
class InfoCard extends StatelessWidget {
  const InfoCard({
    required this.title,
    required this.text,
    this.caption,
    this.linkLabel,
    this.onLink,
    super.key,
  });

  final String title;
  final String text;
  final String? caption;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.bodyLarge.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppTypography.bodySmall.copyWith(color: palette.textPrimary),
          ),
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(
              caption!,
              style: AppTypography.caption.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
          if (linkLabel != null) ...[
            const SizedBox(height: 8),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onLink,
                child: Text(
                  linkLabel!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.brandPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Figma «specs» (875:12574): Body/Large header and «spec row»s
/// (caption + Body/Medium value) separated by full-width dividers.
class SpecsCard extends StatelessWidget {
  const SpecsCard({required this.title, required this.rows, super.key});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final divider = Container(height: 1, color: palette.divider);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
          for (final (label, value) in rows) ...[
            const SizedBox(height: 12),
            divider,
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                  Text(
                    value,
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
