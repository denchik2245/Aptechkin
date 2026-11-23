import 'dart:math' as math;

import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Opens a bottom sheet styled as the Figma «sheet» frames: background
/// colour, 28 pt top corners, «sheet header» and a 34 pt bottom inset.
/// With [subtitle] the header is the one of the pickers in «Выбор
/// значений» (890:15550): grabber, H3 title and a hint, no close button.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
}) {
  final palette = context.palette;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: palette.background,
    barrierColor: palette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => AppSheet(
      title: title,
      subtitle: subtitle,
      child: builder(sheetContext),
    ),
  );
}

class AppSheet extends StatelessWidget {
  const AppSheet({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = math.max(34.0, media.viewPadding.bottom) +
        media.viewInsets.bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (subtitle case final subtitle?) ...[
              _PickerHeader(title: title, subtitle: subtitle),
              const SizedBox(height: 16),
            ] else ...[
              SheetHeader(title: title),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Header of the picker sheets (894:17664): grabber, Heading/H3 and a
/// Body/Small hint; the sheet closes by a swipe or «Готово».
class _PickerHeader extends StatelessWidget {
  const _PickerHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: palette.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.h3.copyWith(color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma component «sheet header» (824:4952): grabber, title and close.
class SheetHeader extends StatelessWidget {
  const SheetHeader({required this.title, this.onClose, super.key});
  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: palette.divider,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTypography.h2.copyWith(color: palette.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Закрыть',
                excludeSemantics: true,
                child: InkResponse(
                  radius: 22,
                  onTap: onClose ?? () => Navigator.of(context).maybePop(),
                  child: const DesignIcon('sheet-close', size: 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
