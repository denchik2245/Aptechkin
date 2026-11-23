import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_chip.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/core/ui/empty_state_card.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/core/ui/swipe_reveal.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/features/inventory/presentation/add_medicine_sheets.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/core/widgets/round_icon_button.dart';
import 'package:aptechka/features/home/presentation/kit_sheets.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/package_status.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/inventory/presentation/inventory_sheets.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_card.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Figma sections «2 · Содержимое аптечки» (825:4878) and «3 · Фильтры»
/// (825:4879).
class PharmacyInventoryScreen extends ConsumerStatefulWidget {
  const PharmacyInventoryScreen({super.key});

  @override
  ConsumerState<PharmacyInventoryScreen> createState() =>
      _PharmacyInventoryScreenState();
}

class _PharmacyInventoryScreenState
    extends ConsumerState<PharmacyInventoryScreen> {
  InventoryFilter _filter = InventoryFilter.all;

  /// `null` — all places, `''` — «Место не указано».
  String? _place;
  String? _kitId;
  String? _swiped;

  /// Status chips, so the selected one scrolls into view (833:7860).
  final _chipKeys = {for (final filter in InventoryFilter.values) filter: GlobalKey()};

  AppController get _controller => ref.read(appControllerProvider.notifier);

  void _setFilter(InventoryFilter filter) {
    setState(() => _filter = filter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chip = _chipKeys[filter]?.currentContext;
      if (chip == null || !chip.mounted) return;
      Scrollable.ensureVisible(
        chip,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  /// «Убрать все просроченные» (833:7440), with «Отменить».
  Future<void> _removeAll(AppState state, List<Medicine> packages) async {
    setState(() => _swiped = null);
    final snapshot = await _controller.removePackages([
      for (final package in packages) package.id,
    ]);
    if (!mounted) return;
    final kit = state.kitById(packages.first.pharmacyId)?.name ?? '';
    showAppToast(
      context,
      'Убрали из «$kit»: '
      '${russianCount(packages.length, 'упаковку', 'упаковки', 'упаковок')}',
      actionLabel: 'Отменить',
      onAction: () => _controller.restoreSnapshot(snapshot),
    );
  }

  /// «Указать срок» (833:8264): the first package without a date.
  Future<void> _setExpiry(Medicine package) async {
    final date = await showExpirySheet(context);
    if (date != null) await _controller.setExpiry(package.id, date);
  }

  void _resetFor(String kitId) {
    if (_kitId == kitId) return;
    _kitId = kitId;
    _filter = InventoryFilter.all;
    _place = null;
    _swiped = null;
  }

  Future<void> _switchKit(AppState state) async {
    final result = await showKitSwitcher(context, state: state);
    if (!mounted) return;
    switch (result) {
      case KitSelected(:final kitId):
        await _controller.selectPharmacy(kitId);
      case KitCreateRequested():
        final draft = await showKitEditorSheet(context, state: state);
        if (draft != null) {
          await _controller.createPharmacy(draft.name, icon: draft.icon);
        }
      case AllKitsRequested():
        context.go(AppRoutes.kits);
      case null:
        break;
    }
  }

  Future<void> _openMenu(AppState state, Pharmacy kit) async {
    final action = await showKitMenu(context, state: state, kit: kit);
    if (!mounted || action == null) return;
    switch (action) {
      case KitMenuAction.state:
        context.push(AppRoutes.kitState(kit.id));
      case KitMenuAction.places:
        context.push(AppRoutes.places);
      case KitMenuAction.rename:
        final draft = await showKitEditorSheet(context, state: state, kit: kit);
        if (draft != null) {
          await _controller.updatePharmacy(
            kit.id,
            name: draft.name,
            icon: draft.icon,
          );
        }
      case KitMenuAction.delete:
        final deleted = await deleteKitFlow(context, _controller, state, kit);
        if (deleted && mounted) context.go(AppRoutes.kits);
    }
  }

  Future<void> _choosePlace(AppState state, String kitId) async {
    final picked = await showPlacePicker(
      context,
      state: state,
      kitId: kitId,
      selected: _place,
    );
    if (!mounted) return;
    switch (picked) {
      case PlaceChosen(:final place):
        setState(() => _place = place);
      case ManagePlaces():
        context.push(AppRoutes.places);
      case null:
        break;
    }
  }

  Future<void> _editStock(Medicine package) async {
    setState(() => _swiped = null);
    final value = await showStockSheet(context, package);
    if (value != null) await _controller.setQuantity(package.id, value);
  }

  Future<void> _move(AppState state, Medicine package) async {
    setState(() => _swiped = null);
    final target = await showMoveSheet(context, state: state, package: package);
    if (target == null) return;
    await _controller.movePackage(
      package.id,
      kitId: target.kitId,
      place: target.place,
    );
    if (!mounted || target.kitId == package.pharmacyId) return;
    showAppToast(
      context,
      '${readableDrugName(package.name)} перенесён в '
      '«${state.kitById(target.kitId)?.name ?? ''}»',
    );
  }

  Future<void> _remove(AppState state, Medicine package) async {
    setState(() => _swiped = null);
    final snapshot = await _controller.removePackage(package.id);
    if (!mounted) return;
    showAppToast(
      context,
      '${readableDrugName(package.name)} убран из '
      '«${state.kitById(package.pharmacyId)?.name ?? ''}»',
      actionLabel: 'Отменить',
      onAction: () => _controller.restoreSnapshot(snapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = ref.watch(appControllerProvider);
    final state = value.asData?.value;
    final kit = state?.selectedPharmacyOrNull;
    if (state != null && kit == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.kits);
      });
    }
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (state != null && kit != null)
              _KitNavBar(
                kit: kit,
                onMenu: () => _openMenu(state, kit),
                onSwitch: () => _switchKit(state),
                onAdd: kit.canEdit
                    // Figma: «+» leads straight to the camera.
                    ? () => context.push(AppRoutes.scanner)
                    : null,
              )
            else
              const SizedBox(height: 54),
            Expanded(
              child: AsyncValueView(
                value: value,
                data: (state) {
                  final kit = state.selectedPharmacyOrNull;
                  if (kit == null) return const SizedBox.shrink();
                  _resetFor(kit.id);
                  return _content(state, kit);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppState state, Pharmacy kit) {
    final all = state.medicinesIn(kit.id);
    if (all.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 132),
          child: EmptyStateCard(
            image: 'assets/illustrations/onboarding/empty-medicines.png',
            imageZoom: 1.1146,
            title: 'Добавьте \nпервое лекарство',
            text:
                'Начните с того, что уже есть в аптечке.\n'
                'Остальное можно добавить позже.',
            buttonLabel: 'Добавить лекарство',
            onPressed: () => context.push(AppRoutes.scanner),
          ),
        ),
      );
    }
    final now = DateTime.now();
    final warningDays = state.settings.expiryWarningDays;
    final inPlace = _place == null
        ? all
        : all.where((item) => item.location.trim() == _place).toList();
    bool matches(Medicine item, InventoryFilter filter) =>
        matchesInventoryFilter(item, filter, now, warningDays: warningDays);

    int count(InventoryFilter filter) =>
        inPlace.where((item) => matches(item, filter)).length;
    final visible = _sorted(
      inPlace.where((item) => matches(item, _filter)).toList(),
      state.settings,
      now,
    );
    final attention = visible
        .where((item) => needsAttention(item, now, warningDays: warningDays))
        .toList();
    final others = visible.where((item) => !attention.contains(item)).toList();
    final grouped = _filter == InventoryFilter.all && attention.isNotEmpty;
    final summary = state.summaryOf(kit.id, now);
    final attentionTotal = all
        .where((item) => needsAttention(item, now, warningDays: warningDays))
        .length;

    // Filtered lists (825:4879) put 12 between all their blocks.
    final filtered = _filter != InventoryFilter.all || _place != null;
    Widget card(Medicine package) => Padding(
      padding: EdgeInsets.only(top: filtered ? 12 : AppSpacing.cardGap),
      child: SwipeReveal(
        key: ValueKey(package.id),
        enabled: kit.canEdit,
        open: _swiped == package.id,
        onOpenChanged: (open) =>
            setState(() => _swiped = open ? package.id : null),
        actions: [
          SwipeActionButton(
            icon: 'swipe-stock',
            label: 'Остаток',
            onTap: () => _editStock(package),
          ),
          SwipeActionButton(
            icon: 'swipe-move',
            label: 'Перенести',
            onTap: () => _move(state, package),
          ),
          SwipeActionButton(
            icon: 'swipe-delete',
            label: 'Удалить',
            destructive: true,
            onTap: () => _remove(state, package),
          ),
        ],
        child: PackageCard(
          package: package,
          now: now,
          warningDays: warningDays,
          onTap: () {
            if (_swiped != null) {
              setState(() => _swiped = null);
              return;
            }
            context.push(AppRoutes.medicine(package.id));
          },
        ),
      ),
    );

    Widget groupTitle(String text) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Text(
        text,
        style: AppTypography.bodyMedium.copyWith(
          color: context.palette.textSecondary,
        ),
      ),
    );

    final placeLabel = switch (_place) {
      null => 'Место: все',
      '' => 'Место не указано',
      // «Место: холодильник» (833:8685).
      final place => 'Место: ${place[0].toLowerCase()}${place.substring(1)}',
    };
    final palette = context.palette;
    Widget hint(String text) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(color: palette.textSecondary),
      ),
    );
    Widget action(Widget button) =>
        Padding(padding: const EdgeInsets.only(top: 12), child: button);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 132),
          children: [
            // A filter hides the banner (825:4879).
            if (attentionTotal > 0 && !filtered)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: StatusBanner(
                  tone: summary.soon > 0
                      ? StatusBannerTone.warning
                      : StatusBannerTone.fail,
                  title: _attentionTitle(attentionTotal),
                  text:
                      '${KitStatusLine.text(summary)}. '
                      '${checkedAgoLabel(kit.checkedAt, now)}',
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final chip in [
                    AppChip(
                      icon: 'filter-place',
                      whiteWhenSelected: true,
                      label: placeLabel,
                      selected: _place != null,
                      onTap: () => _choosePlace(state, kit.id),
                    ),
                    AppChip(
                      key: _chipKeys[InventoryFilter.all],
                      label: 'Все · ${count(InventoryFilter.all)}',
                      selected: _filter == InventoryFilter.all,
                      onTap: () => _setFilter(InventoryFilter.all),
                    ),
                    for (final (filter, icon, label) in const [
                      (InventoryFilter.expired, 'filter-expired', 'Срок истёк'),
                      (InventoryFilter.soon, 'filter-soon', 'Скоро истекает'),
                      (
                        InventoryFilter.noDate,
                        'filter-unknown',
                        'Срок не указан',
                      ),
                      (InventoryFilter.empty, 'filter-out', 'Нет в наличии'),
                    ])
                      AppChip(
                        key: _chipKeys[filter],
                        icon: icon,
                        label: '$label · ${count(filter)}',
                        selected: _filter == filter,
                        onTap: () => _setFilter(
                          _filter == filter ? InventoryFilter.all : filter,
                        ),
                      ),
                  ]) ...[chip, const SizedBox(width: 8)],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_filter != InventoryFilter.all)
                    ..._filterBlocks(
                      state,
                      kit,
                      visible,
                      card: card,
                      hint: hint,
                      action: action,
                      warningDays: warningDays,
                    )
                  else if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(
                        children: [
                          Text(
                            'В этой аптечке ничего не найдено',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppTextButton(
                            label: 'Сбросить фильтры',
                            color: context.palette.brandPrimary,
                            onPressed: () => setState(() {
                              _filter = InventoryFilter.all;
                              _place = null;
                            }),
                          ),
                        ],
                      ),
                    )
                  else if (grouped) ...[
                    groupTitle('Требуют внимания'),
                    ...attention.map(card),
                    if (others.isNotEmpty) ...[
                      groupTitle('Остальные'),
                      ...others.map(card),
                    ],
                  ] else ...[
                    if (!filtered) const SizedBox(height: 12),
                    ...visible.map(card),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «3 · Фильтры» (825:4879): a hint, the cards and the filter's action;
  /// when nothing matches, a card with an illustration under a 171 pt gap.
  List<Widget> _filterBlocks(
    AppState state,
    Pharmacy kit,
    List<Medicine> visible, {
    required Widget Function(Medicine) card,
    required Widget Function(String) hint,
    required Widget Function(Widget) action,
    required int warningDays,
  }) {
    if (visible.isEmpty) {
      final (image, zoom, title) = switch (_filter) {
        InventoryFilter.expired => (
          'assets/illustrations/filters/no-expired.png',
          1.0,
          'Просроченных лекарств нет',
        ),
        InventoryFilter.soon => (
          'assets/illustrations/filters/no-expiring.png',
          1.0,
          'Нет лекарств с истекающим сроком',
        ),
        // Not in Figma: the same card for the other two filters.
        InventoryFilter.noDate => (
          'assets/illustrations/filters/no-expired.png',
          1.0,
          'У всех лекарств указан срок',
        ),
        InventoryFilter.empty || InventoryFilter.all => (
          'assets/illustrations/onboarding/empty-medicines.png',
          1.1146,
          'Все лекарства в наличии',
        ),
      };
      return [
        Padding(
          padding: const EdgeInsets.only(top: 12 + 171),
          child: Center(
            child: EmptyStateCard(image: image, imageZoom: zoom, title: title),
          ),
        ),
        // With a place chosen too, one tap brings the whole kit back.
        if (_place != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: AppTextButton(
                label: 'Сбросить фильтры',
                color: context.palette.brandPrimary,
                onPressed: () => setState(() {
                  _filter = InventoryFilter.all;
                  _place = null;
                }),
              ),
            ),
          ),
      ];
    }
    final canEdit = kit.canEdit;
    return switch (_filter) {
      InventoryFilter.expired => [
        hint(
          'Просроченные лекарства не принимайте. Уберите их из аптечки и '
          'утилизируйте.',
        ),
        ...visible.map(card),
        if (canEdit)
          action(
            AppButton.secondaryDestructive(
              label: 'Убрать все просроченные',
              onPressed: () => _removeAll(state, visible),
            ),
          ),
      ],
      InventoryFilter.soon => [
        hint(
          'Используйте сначала эти упаковки. Предупреждаем за '
          '${russianCount(warningDays, 'день', 'дня', 'дней')} — можно '
          'изменить в настройках.',
        ),
        ...visible.map(card),
      ],
      InventoryFilter.noDate => [
        hint(
          'Без срока мы не сможем предупредить о просрочке. Посмотрите дату '
          'на упаковке и добавьте её.',
        ),
        ...visible.map(card),
        if (canEdit)
          action(
            AppButton.secondary(
              label: 'Указать срок',
              onPressed: () => _setExpiry(visible.first),
            ),
          ),
      ],
      InventoryFilter.empty || InventoryFilter.all => [
        ...visible.map(card),
        action(
          AppButton.secondary(
            label: 'Состояние аптечки',
            onPressed: () => context.push(AppRoutes.kitState(kit.id)),
          ),
        ),
        hint(
          'Закончившиеся лекарства остаются в аптечке — так видно, чего не '
          'хватает. Убрать — свайпом влево.',
        ),
      ],
    };
  }

  static String _attentionTitle(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    final word = mod10 == 1 && mod100 != 11
        ? 'лекарство требует'
        : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
        ? 'лекарства требуют'
        : 'лекарств требуют';
    return '$count $word внимания';
  }

  /// Expired first, then by expiry date; the user's sort for the rest.
  List<Medicine> _sorted(
    List<Medicine> items,
    AppSettings settings,
    DateTime now,
  ) {
    int byName(Medicine a, Medicine b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    int byExpiry(Medicine a, Medicine b) {
      final x = a.effectiveExpiryDate;
      final y = b.effectiveExpiryDate;
      if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
      return x.compareTo(y);
    }

    return [...items]..sort((a, b) {
      final attentionA = needsAttention(
        a,
        now,
        warningDays: settings.expiryWarningDays,
      );
      final attentionB = needsAttention(
        b,
        now,
        warningDays: settings.expiryWarningDays,
      );
      if (attentionA != attentionB) return attentionA ? -1 : 1;
      if (attentionA) return byExpiry(a, b);
      final primary = settings.inventorySort == InventorySort.expiry
          ? byExpiry(a, b)
          : byName(a, b);
      return primary != 0 ? primary : byExpiry(a, b);
    });
  }
}

/// Figma «nav bar / kit» (824:4914): menu, kit switcher, add.
class _KitNavBar extends StatelessWidget {
  const _KitNavBar({
    required this.kit,
    required this.onMenu,
    required this.onSwitch,
    required this.onAdd,
  });

  final Pharmacy kit;
  final VoidCallback onMenu;
  final VoidCallback onSwitch;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(
        height: AppSpacing.navBar,
        child: Row(
          children: [
            RoundIconButton(
              tooltip: 'Меню аптечки',
              icon: const Icon(Icons.more_horiz_rounded, size: 24),
              onPressed: onMenu,
            ),
            Expanded(
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Аптечка ${kit.name}. Сменить аптечку',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: onSwitch,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                kit.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            DesignIcon(
                              'kit-switcher-chevron',
                              size: 16,
                              color: palette.textPrimary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (onAdd != null)
              RoundIconButton(
                tooltip: 'Добавить лекарство',
                primary: true,
                icon: const DesignIcon('add-24', size: 24),
                onPressed: onAdd!,
              )
            else
              const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}
