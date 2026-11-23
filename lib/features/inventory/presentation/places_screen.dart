import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/action_group.dart';
import 'package:aptechka/core/ui/app_alert.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_sheet.dart';
import 'package:aptechka/core/ui/chevron_arrow.dart';
import 'package:aptechka/core/ui/nav_bars.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/presentation/inventory_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// «Места хранения» (827:5781): places of the selected kit in the user's
/// order. Long-press and drag to reorder; tap to rename or delete.
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref, AppState state) async {
    final kitId = state.selectedPharmacy.id;
    final name = await showPlaceEditor(context, state: state, kitId: kitId);
    if (name != null) {
      await ref.read(appControllerProvider.notifier).addPlace(kitId, name);
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AppState state,
    String place,
  ) async {
    final kitId = state.selectedPharmacy.id;
    final controller = ref.read(appControllerProvider.notifier);
    final action = await showAppSheet<String>(
      context: context,
      title: place,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionGroup(
            children: [
              ActionRow(
                title: 'Переименовать',
                onTap: () => Navigator.pop(sheetContext, 'rename'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ActionGroup(
            children: [
              ActionRow(
                title: 'Удалить место',
                destructive: true,
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ],
          ),
        ],
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'rename') {
      final name = await showPlaceEditor(
        context,
        state: state,
        kitId: kitId,
        initial: place,
      );
      if (name != null) await controller.renamePlace(kitId, place, name);
      return;
    }
    final count = state.countAt(kitId, place);
    final confirmed = await showAppAlert(
      context: context,
      title: 'Удалить место «$place»?',
      message: count == 0
          ? 'Здесь нет лекарств.'
          : '${medicinesCount(count)} останутся в аптечке с пометкой '
                '«Место не указано».',
      confirmLabel: 'Удалить',
    );
    if (confirmed) await controller.deletePlace(kitId, place);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TitleNavBar(title: 'Места хранения'),
            Expanded(
              child: AsyncValueView(
                value: ref.watch(appControllerProvider),
                data: (state) => _content(context, ref, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, AppState state) {
    final palette = context.palette;
    final kit = state.selectedPharmacyOrNull;
    if (kit == null) return const SizedBox.shrink();
    final places = state.placesOf(kit.id);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              'Места помогают быстро найти упаковку. Перетащите, чтобы '
              'изменить порядок.',
              style: AppTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (places.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (from, to) {
                    final ordered = [...places];
                    final item = ordered.removeAt(from);
                    ordered.insert(to, item);
                    ref
                        .read(appControllerProvider.notifier)
                        .reorderPlaces(kit.id, ordered);
                  },
                  children: [
                    for (final (i, place) in places.indexed)
                      ReorderableDelayedDragStartListener(
                        key: ValueKey(place),
                        index: i,
                        enabled: kit.canEdit,
                        child: Material(
                          color: palette.surfaceCard,
                          child: Column(
                            children: [
                              if (i > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Container(
                                    height: 1,
                                    color: palette.divider,
                                  ),
                                ),
                              ActionRow(
                                title: place,
                                subtitle: medicinesCount(
                                  state.countAt(kit.id, place),
                                ),
                                trailing: const ChevronArrow(),
                                onTap: kit.canEdit
                                    ? () => _edit(context, ref, state, place)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (kit.canEdit) ...[
              const SizedBox(height: 8),
              AppButton.secondary(
                label: 'Добавить место',
                onPressed: () => _add(context, ref, state),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
