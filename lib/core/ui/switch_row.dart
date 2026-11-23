import 'package:aptechka/core/design/design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Figma «switch row» (710:1705): pill with a Body/Medium title and a
/// 51×31 switch.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return MergeSemantics(
      child: Material(
        color: palette.surfaceCard,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                CupertinoSwitch(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: palette.brandPrimary,
                  inactiveTrackColor: palette.buttonSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
