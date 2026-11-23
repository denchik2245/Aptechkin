import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:flutter/material.dart';

/// Centered confirmation from «Аптечки / Удалить пустую аптечку» (832:6835).
/// Returns `true` when the user confirms.
Future<bool> showAppAlert({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Отмена',
  bool destructive = true,
}) async {
  final palette = context.palette;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: palette.scrim,
    builder: (dialogContext) => Dialog(
      backgroundColor: palette.surfaceCard,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.alert),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: cancelLabel,
                      onPressed: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: confirmLabel,
                      variant: destructive
                          ? AppButtonVariant.destructive
                          : AppButtonVariant.primary,
                      onPressed: () => Navigator.pop(dialogContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}
