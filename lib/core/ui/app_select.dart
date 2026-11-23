import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Figma «select» (710:1696): pill with the label on the left (placeholder
/// colour, red asterisk when [required]), the value on the right and a
/// 16 pt up/down chevron. Error state adds a 1.5 pt fail border.
class AppSelect extends StatelessWidget {
  const AppSelect({
    required this.label,
    required this.value,
    required this.onTap,
    this.required = false,
    this.error = false,
    this.small = false,
    super.key,
  });

  final String label;

  /// `null` shows «Не выбрано».
  final String? value;
  final VoidCallback? onTap;
  final bool required;
  final bool error;

  /// Label/Large label and value in `text/primary` — the treatment sheets
  /// («Напомнить в», «Фактически», 1037:19177).
  final bool small;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = small ? AppTypography.labelLarge : AppTypography.bodyMedium;
    return Semantics(
      button: true,
      label: label,
      value: value ?? 'Не выбрано',
      excludeSemantics: true,
      child: Material(
        color: palette.surfaceCard,
        shape: StadiumBorder(
          side: error
              ? BorderSide(color: palette.fail, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  // The label keeps its width; the value takes the rest and
                  // sits against the chevron.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.6,
                    ),
                    child: Text.rich(
                      TextSpan(
                        text: label,
                        children: [
                          if (required)
                            TextSpan(
                              text: ' *',
                              style: TextStyle(color: palette.fail),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                        color: small
                            ? palette.textPrimary
                            : palette.placeholder,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      value ?? 'Не выбрано',
                      textAlign: TextAlign.right,
                      style: style.copyWith(color: palette.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  DesignIcon(
                    'select-chevron-16',
                    size: 16,
                    color: palette.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
