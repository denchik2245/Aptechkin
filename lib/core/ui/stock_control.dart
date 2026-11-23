import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Figma «stock control», type «count» (874:12534): minus, the amount in
/// the middle («Осталось», Body/Large value, caption) and a brand plus.
class StockCounter extends StatelessWidget {
  const StockCounter({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.caption = '',
    this.title = 'Осталось',
    this.onValueTap,
    super.key,
  });

  final String title;
  final String value;
  final String caption;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  /// A tap on the amount opens «Сколько осталось?» (880:14866).
  final VoidCallback? onValueTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final captionStyle = AppTypography.caption.copyWith(
      color: palette.textSecondary,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _RoundButton(
            tooltip: 'Меньше',
            icon: 'stock-minus-20',
            background: palette.buttonSecondary,
            iconColor: palette.textPrimary,
            onTap: onMinus,
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              button: onValueTap != null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onValueTap,
                child: Column(
                  children: [
                    Text(title, style: captionStyle),
                    Text(
                      value,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: captionStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _RoundButton(
            tooltip: 'Больше',
            icon: 'stock-plus-20',
            background: palette.brandPrimary,
            iconColor: palette.textOnAccent,
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  final String tooltip;
  final String icon;
  final Color background;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Center(child: DesignIcon(icon, size: 20, color: iconColor)),
          ),
        ),
      ),
    ),
  );
}

/// Figma «stock control», type «level» (875:13585): «Осталось примерно»,
/// the level name and four divisions. Tapping a division picks the level
/// (0 — almost empty … 3 — full).
class StockLevelBar extends StatelessWidget {
  const StockLevelBar({
    required this.labels,
    required this.level,
    required this.onChanged,
    this.caption = '',
    this.onValueTap,
    super.key,
  });

  /// Names of the four levels, from almost empty to full.
  final List<String> labels;
  final int level;
  final String caption;
  final ValueChanged<int> onChanged;

  /// A tap on the level name opens «Сколько осталось?» (880:14928).
  final VoidCallback? onValueTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final captionStyle = AppTypography.caption.copyWith(
      color: palette.textSecondary,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('Осталось примерно', style: captionStyle)),
              if (caption.isNotEmpty) ...[
                const SizedBox(width: 8),
                // Wraps under large text instead of overflowing at 320 pt.
                Flexible(
                  child: Text(
                    caption,
                    textAlign: TextAlign.end,
                    style: captionStyle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            button: onValueTap != null,
            child: GestureDetector(
              onTap: onValueTap,
              child: Text(
                labels[level],
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
          // 12 pt gap above the 8 pt divisions; their hit area is taller.
          const SizedBox(height: 2),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == level,
                    label: labels[i],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= level
                                ? palette.brandPrimary
                                : palette.buttonSecondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Figma «stock control», type «off» (874:12556): devices whose amount is
/// not tracked.
class StockOffCard extends StatelessWidget {
  const StockOffCard({super.key});

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
          Text(
            'Остаток не учитываем',
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Для термометров, тонометров и других приборов количество не '
            'важно',
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
