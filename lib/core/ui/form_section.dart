import 'package:aptechka/core/design/design.dart';
import 'package:flutter/material.dart';

/// A form section of the add screens («section / Препарат»): Body/Medium
/// title, an optional Caption hint and the content with 8 pt gaps.
class FormSection extends StatelessWidget {
  const FormSection({
    required this.title,
    required this.children,
    this.hint,
    super.key,
  });

  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
        ],
        for (final child in children) ...[const SizedBox(height: 8), child],
      ],
    );
  }
}

/// Caption under a form control: secondary text, or fail colour for an
/// error («Введите название с упаковки»).
class FieldCaption extends StatelessWidget {
  const FieldCaption(this.text, {this.error = false, super.key});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: error,
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: error ? palette.fail : palette.textSecondary,
        ),
      ),
    );
  }
}
