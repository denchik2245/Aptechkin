import 'package:aptechka/core/design/design.dart';
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, destructive, secondaryDestructive }

/// Figma component «btn» (671:2082): 60 pt pill, Button/Default text.
/// A disabled button keeps its colours at 40 % opacity, as in the
/// «название занято» state.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    super.key,
  });

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.destructive({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : variant = AppButtonVariant.destructive;

  /// Grey «btn» with red text: «Убрать все просроченные» (833:7628).
  const AppButton.secondaryDestructive({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : variant = AppButtonVariant.secondaryDestructive;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (background, foreground) = switch (variant) {
      AppButtonVariant.primary => (palette.brandPrimary, palette.textOnAccent),
      AppButtonVariant.secondary => (
        palette.buttonSecondary,
        palette.textPrimary,
      ),
      AppButtonVariant.destructive => (palette.fail, palette.textOnAccent),
      AppButtonVariant.secondaryDestructive => (
        palette.buttonSecondary,
        palette.fail,
      ),
    };
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: background,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                // «btn» with an icon: 20 pt icon, gap 10, vertical padding 20.
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: icon == null ? 22 : 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      IconTheme.merge(
                        data: IconThemeData(color: foreground, size: 20),
                        child: icon!,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.button.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma component «text btn» (814:4795): no background, 44 pt touch area.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    required this.label,
    required this.onPressed,
    this.color,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onPressed,
      customBorder: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: color ?? context.palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A blue text link on the content edge, e.g. «Нет в справочнике? Заполнить
/// вручную» (890:15549): no side padding, 44 pt tall to tap.
class AppLinkButton extends StatelessWidget {
  const AppLinkButton({
    required this.label,
    required this.onPressed,
    this.small = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Label/Large (14/600) instead of Body/Medium — the links of the intake
  /// sheets and messages («Уточнить факт приёма», 1037:20407).
  final bool small;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: Text(
            label,
            style: (small ? AppTypography.labelLarge : AppTypography.bodyMedium)
                .copyWith(color: context.palette.brandPrimary),
          ),
        ),
      ),
    ),
  );
}
