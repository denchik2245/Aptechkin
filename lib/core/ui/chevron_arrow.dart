import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/widgets.dart';

/// Figma «Arrow» (189:2357): 20 pt box with the 7×12 vector at (7, 4).
class ChevronArrow extends StatelessWidget {
  const ChevronArrow({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 20,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(7, 4, 6, 4),
      child: DesignIcon(
        'arrow-20',
        width: 7,
        height: 12,
        color: context.palette.textPrimary,
      ),
    ),
  );
}
