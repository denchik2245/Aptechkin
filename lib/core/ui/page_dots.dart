import 'package:aptechka/core/design/design.dart';
import 'package:flutter/material.dart';

/// Figma component «pagination» (684:929): active pill 24×8, dots 8×8.
class PageDots extends StatelessWidget {
  const PageDots({required this.count, required this.index, super.key});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: 'Шаг ${index + 1} из $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? palette.brandPrimary : palette.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
