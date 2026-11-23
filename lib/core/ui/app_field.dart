import 'package:aptechka/core/design/design.dart';
import 'package:flutter/material.dart';

/// Figma «field» (710:1675): pill with a 12 pt caption above a Body/Medium
/// value («filled»). Error state adds a 1.5 pt fail border.
///
/// With [placeholderWhenEmpty] an empty field shows the «empty» state:
/// the label as a placeholder in Body/Medium with a red asterisk when
/// [required].
class AppField extends StatelessWidget {
  const AppField({
    required this.label,
    required this.controller,
    this.error = false,
    this.autofocus = false,
    this.required = false,
    this.placeholderWhenEmpty = false,
    this.maxLength = 40,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.fieldKey,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool error;
  final bool autofocus;
  final bool required;
  final bool placeholderWhenEmpty;
  final int? maxLength;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  /// Key of the inner [TextFormField] (tests look it up).
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final empty = placeholderWhenEmpty && value.text.isEmpty;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: empty ? 19 : 9,
          ),
          decoration: BoxDecoration(
            color: palette.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: error ? Border.all(color: palette.fail, width: 1.5) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!empty) ...[
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
              ],
              TextFormField(
                key: fieldKey,
                controller: controller,
                autofocus: autofocus,
                maxLength: maxLength,
                maxLines: maxLines,
                minLines: 1,
                keyboardType: keyboardType,
                onChanged: onChanged,
                onFieldSubmitted: onSubmitted,
                textCapitalization: textCapitalization,
                cursorColor: palette.brandPrimary,
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textPrimary,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hint: empty
                      ? Text.rich(
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
                          style: AppTypography.bodyMedium.copyWith(
                            color: palette.placeholder,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
