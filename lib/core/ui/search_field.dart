import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Figma «search field» (823:4982): 48 pt pill with a search icon; once
/// filled, a clear button on the right.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.autofocus = false,
    this.focusNode,
    this.fieldKey,
    super.key,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Key of the inner [TextField] (tests look it up).
  final Key? fieldKey;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16, right: 14),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          DesignIcon('search-20', size: 20, color: palette.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: widget.fieldKey,
              controller: _controller,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              onChanged: (value) {
                widget.onChanged(value);
                setState(() {});
              },
              textCapitalization: TextCapitalization.sentences,
              cursorColor: palette.brandPrimary,
              style: AppTypography.paragraph.copyWith(
                color: palette.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                hintText: widget.hint,
                hintMaxLines: 1,
                hintStyle: AppTypography.paragraph.copyWith(
                  color: palette.textSecondary,
                  overflow: TextOverflow.ellipsis,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: 'Очистить поиск',
              child: Semantics(
                button: true,
                label: 'Очистить поиск',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _clear,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: DesignIcon('clear-20', size: 20),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
