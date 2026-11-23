import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/reminders/domain/course_list.dart';
import 'package:flutter/material.dart';

/// «course card» (722:3292): Body/Large title with an optional badge, dates,
/// a 6 pt progress bar with «День 5 из 10» / «До 25 ноября», drug lines and
/// the stock line.
class CourseCard extends StatelessWidget {
  const CourseCard({required this.info, required this.onTap, super.key});
  final CourseCardInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppTypography.labelMedium.copyWith(
      color: palette.textSecondary,
    );
    final badge = info.badge;
    final progress = info.progress;
    final stock = info.stock;
    return Material(
      color: palette.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      info.title,
                      style: AppTypography.bodyLarge.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badge.tone == CourseBadgeTone.brand
                            ? palette.brandPrimary.withValues(alpha: 0.1)
                            : palette.background,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Text(
                        badge.text,
                        style: AppTypography.labelMedium.copyWith(
                          color: badge.tone == CourseBadgeTone.brand
                              ? palette.brandPrimary
                              : palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                info.subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: palette.background),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0, 1).toDouble(),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: info.progressMuted
                                  ? palette.textSecondary
                                  : palette.brandPrimary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(info.progressDays ?? '', style: caption),
                    ),
                    if (info.progressEnd != null)
                      Text(info.progressEnd!, style: caption),
                  ],
                ),
              ],
              if (info.lines.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  info.lines.join('\n'),
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ],
              if (stock != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    DesignIcon(
                      stock.tone == CourseStockTone.warning
                          ? 'status-warning-18'
                          : 'status-unknown-16',
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stock.text,
                        style: AppTypography.labelMedium.copyWith(
                          color: stock.tone == CourseStockTone.warning
                              ? palette.textPrimary
                              : palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «image 70» of «Добавьте первый курс» (1113:27539): 210 × 173 window on
/// the square picture.
class FirstCourseImage extends StatelessWidget {
  const FirstCourseImage({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    height: 173,
    child: ClipRect(
      child: OverflowBox(
        maxHeight: 210,
        minHeight: 210,
        child: Image.asset(
          'assets/illustrations/treatment/first-course.png',
          width: 210,
          height: 210,
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}
