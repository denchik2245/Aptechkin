import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/empty_state_card.dart';
import 'package:aptechka/core/ui/swipe_reveal.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/home/presentation/kit_sheets.dart';
import 'package:aptechka/features/home/presentation/widgets/kit_card.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Figma section «1 · Мои аптечки» (825:4877).
class PharmaciesScreen extends ConsumerStatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  ConsumerState<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends ConsumerState<PharmaciesScreen> {
  String? _swiped;

  AppController get _controller => ref.read(appControllerProvider.notifier);

  Future<void> _create(AppState state) async {
    final draft = await showKitEditorSheet(context, state: state);
    if (draft == null) return;
    await _controller.createPharmacy(draft.name, icon: draft.icon);
    if (mounted) context.go(AppRoutes.inventory);
  }

  Future<void> _edit(AppState state, Pharmacy kit) async {
    setState(() => _swiped = null);
    final draft = await showKitEditorSheet(context, state: state, kit: kit);
    if (draft == null) return;
    await _controller.updatePharmacy(kit.id, name: draft.name, icon: draft.icon);
  }

  Future<void> _delete(AppState state, Pharmacy kit) async {
    setState(() => _swiped = null);
    await deleteKitFlow(context, _controller, state, kit);
  }

  Future<void> _open(Pharmacy kit) async {
    if (_swiped != null) {
      setState(() => _swiped = null);
      return;
    }
    await _controller.selectPharmacy(kit.id);
    if (mounted) context.go(AppRoutes.inventory);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: AsyncValueView(
          value: ref.watch(appControllerProvider),
          data: (state) => state.pharmacies.isEmpty
              ? _EmptyKits(onCreate: () => _create(state))
              : _list(state),
        ),
      ),
    );
  }

  Widget _list(AppState state) {
    final palette = context.palette;
    final now = DateTime.now();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 132),
          children: [
            SizedBox(
              height: AppSpacing.navBar,
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Мои аптечки',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h1.copyWith(
                          color: palette.textHeading,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AddButton(onPressed: () => _create(state)),
                ],
              ),
            ),
            const SizedBox(height: 36),
            for (final (index, kit) in state.pharmacies.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.cardGap),
              SwipeReveal(
                key: ValueKey(kit.id),
                enabled: kit.isOwn,
                open: _swiped == kit.id,
                onOpenChanged: (open) =>
                    setState(() => _swiped = open ? kit.id : null),
                actions: [
                  SwipeActionButton(
                    icon: 'swipe-edit',
                    label: 'Изменить',
                    onTap: () => _edit(state, kit),
                  ),
                  SwipeActionButton(
                    icon: 'swipe-delete',
                    label: 'Удалить',
                    destructive: true,
                    onTap: () => _delete(state, kit),
                  ),
                ],
                child: KitCard(
                  kit: kit,
                  summary: state.summaryOf(kit.id, now),
                  now: now,
                  onTap: () => _open(kit),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Primary 44 pt glass button with the Figma «+» (671:1383).
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Создать аптечку',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Создать аптечку',
        child: Material(
          color: palette.brandPrimary,
          shape: const CircleBorder(),
          shadowColor: const Color(0x05000000),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(child: DesignIcon('add-24', size: 24)),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Аптечки / Пусто» (671:1432): shown only after every kit was deleted.
class _EmptyKits extends StatelessWidget {
  const _EmptyKits({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 120),
      child: EmptyStateCard(
        image: 'assets/illustrations/onboarding/empty-kits.png',
        title: 'Создайте первую аптечку',
        text: 'Начните с одной аптечки. Остальные можно создать позже.',
        buttonLabel: 'Создать аптечку',
        onPressed: onCreate,
      ),
    ),
  );
}
