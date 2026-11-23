import 'dart:async';

import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Distance from the screen bottom to the toast in the Figma frames
/// (tab bar + 24 pt gap). Screens without a tab bar pass a smaller value.
const kToastAboveTabBar = 82.0;

OverlayEntry? _current;
Timer? _timer;

/// Shows the Figma «toast» (710:1706) above the tab bar.
void showAppToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
  double bottomOffset = kToastAboveTabBar,
}) {
  hideAppToast();
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (overlayContext) {
      final inset = MediaQuery.viewPaddingOf(overlayContext).bottom;
      return Positioned(
        left: AppSpacing.page,
        right: AppSpacing.page,
        bottom: bottomOffset + (inset >= 25 ? 25 : (inset < 16 ? 16 : inset)),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppToast(
                message: message,
                actionLabel: actionLabel,
                onAction: onAction == null
                    ? null
                    : () {
                        hideAppToast();
                        onAction();
                      },
              ),
            ),
          ),
        ),
      );
    },
  );
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(duration, hideAppToast);
}

void hideAppToast() {
  _timer?.cancel();
  _timer = null;
  _current?.remove();
  _current = null;
}

class AppToast extends StatelessWidget {
  const AppToast({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
          decoration: BoxDecoration(
            color: palette.surfaceChoice,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x331C1A33),
                blurRadius: 12,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const DesignIcon('toast-ok-18', size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textOnAccent,
                  ),
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAction,
                  child: Text(
                    actionLabel!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: palette.toastLink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
