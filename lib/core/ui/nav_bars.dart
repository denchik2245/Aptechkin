import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/round_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Figma «nav bar / title» (824:4939): glass back button and a centred
/// headline. 54 pt tall including the 10 pt bottom padding.
/// [TitleNavBar.modal] is «nav bar / modal» (889:15546): close (×) and a
/// Body/Large title. [TitleNavBar.card] is «nav bar / card» (874:12613):
/// back, «Название, доза» in Body/Large and a pencil on the right.
class TitleNavBar extends StatelessWidget {
  const TitleNavBar({required this.title, this.onBack, super.key})
    : modal = false,
      onEdit = null,
      card = false;

  const TitleNavBar.card({
    required this.title,
    this.onBack,
    this.onEdit,
    super.key,
  }) : modal = false,
       card = true;

  const TitleNavBar.modal({required this.title, this.onBack, super.key})
    : modal = true,
      onEdit = null,
      card = false;

  final String title;
  final VoidCallback? onBack;
  final bool modal;
  final bool card;

  /// Pencil of [TitleNavBar.card]; hidden when `null`.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: SizedBox(
      height: AppSpacing.navBar,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: RoundIconButton(
              tooltip: modal ? 'Закрыть' : 'Назад',
              icon: Icon(
                modal ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
                size: modal ? 24 : 20,
              ),
              onPressed: onBack ?? () => context.pop(),
            ),
          ),
          if (onEdit != null)
            Align(
              alignment: Alignment.centerRight,
              child: RoundIconButton(
                tooltip: 'Изменить',
                icon: const Icon(Icons.edit_outlined, size: 22),
                onPressed: onEdit!,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (modal || card
                        ? AppTypography.bodyLarge
                        : AppTypography.headline)
                    .copyWith(
                  color: context.palette.textHeading,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
