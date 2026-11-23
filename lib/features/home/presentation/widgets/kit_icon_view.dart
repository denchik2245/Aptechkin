import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/domain/kit_icon.dart';
import 'package:flutter/widgets.dart';

/// Kit icon from Figma. Cards and the name field use 28 pt artwork where
/// Figma has it (home, dacha, car); otherwise the 24 pt picker icon scales.
class KitIconView extends StatelessWidget {
  const KitIconView(this.icon, {this.size = 24, super.key});
  final KitIcon icon;
  final double size;

  static const _large = {
    KitIcon.home: 'kit-home',
    KitIcon.dacha: 'kit-dacha-28',
    KitIcon.car: 'kit-car-28',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    label: icon.label,
    excludeSemantics: true,
    child: DesignIcon(
      size >= 28 && _large.containsKey(icon)
          ? _large[icon]!
          : 'kit/${icon.name}',
      size: size,
    ),
  );
}
