import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// A button of a [StateCard].
class StateCardAction {
  const StateCardAction(this.label, this.onPressed, {this.primary = true});
  final String label;
  final VoidCallback onPressed;
  final bool primary;
}

/// «Пустое состояние» of the course list (1113:27401, 1113:27538): white
/// card with radius 24, a 64 pt «status / empty» symbol or an illustration,
/// a 22/29 bold title, Body/Small text and full-width buttons, 16 pt apart.
class StateCard extends StatelessWidget {
  const StateCard({
    required this.title,
    required this.text,
    this.actions = const [],
    this.image,
    super.key,
  });

  final String title;
  final String text;
  final List<StateCardAction> actions;

  /// An illustration instead of the symbol («Добавьте первый курс»).
  final Widget? image;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child:
                image ??
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.background,
                    shape: BoxShape.circle,
                  ),
                  child: const DesignIcon('status-empty-16', size: 28),
                ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              // The Figma text is 22/29 Bold without a named style.
              style: AppTypography.h2.copyWith(
                fontSize: 22,
                height: 29 / 22,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(height: 16),
            action.primary
                ? AppButton(label: action.label, onPressed: action.onPressed)
                : AppButton.secondary(
                    label: action.label,
                    onPressed: action.onPressed,
                  ),
          ],
        ],
      ),
    );
  }
}
