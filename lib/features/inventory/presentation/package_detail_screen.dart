import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/action_group.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/core/ui/info_card.dart';
import 'package:aptechka/core/ui/nav_bars.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/core/ui/stock_control.dart';
import 'package:aptechka/core/ui/swipe_reveal.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/package_detail.dart';
import 'package:aptechka/features/inventory/domain/package_status.dart';
import 'package:aptechka/features/inventory/presentation/add_medicine_screen.dart';
import 'package:aptechka/features/inventory/presentation/add_medicine_sheets.dart';
import 'package:aptechka/features/inventory/presentation/package_action_sheets.dart';
import 'package:aptechka/features/inventory/presentation/inventory_sheets.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_hero.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Figma «Карточка лекарства»: «1 · Статусы срока» (875:12466) and
/// «2 · Формы лекарств» (875:12467), «3 · Вскрытие» (875:12468), «4 · Упаковки, курс и справка» (875:12469), «5 · Действия» (875:12470). One physical
/// package: status banner, pack hero, pack facts, stock control, actions,
/// «После вскрытия», other packages of the
/// same medicine, «Как применять» / «Заметка», «Характеристики» and dates.
class PackageDetailScreen extends ConsumerStatefulWidget {
  const PackageDetailScreen({required this.packageId, super.key});
  final String packageId;
  @override
  ConsumerState<PackageDetailScreen> createState() =>
      _PackageDetailScreenState();
}

class _PackageDetailScreenState extends ConsumerState<PackageDetailScreen> {
  bool _saving = false;

  AppController get _controller => ref.read(appControllerProvider.notifier);

  void _back() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.inventory);

  Future<void> _run(Future<void> Function() action, String error) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted) showAppToast(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The pencil opens «Изменить упаковку» (894:18072); its «Убрать из
  /// аптечки» comes back here for the removal sheet.
  Future<void> _edit(Medicine package) async {
    final result = await context.push<Object?>(
      AppRoutes.medicineEdit(package.id),
    );
    if (!mounted || result != PackageEditResult.remove) return;
    final state = ref.read(appControllerProvider).asData?.value;
    if (state != null) await _remove(state, package);
  }

  Future<void> _setQuantity(Medicine package, int quantity) => _run(
    () => _controller.setQuantity(package.id, quantity),
    'Не удалось сохранить остаток. Повторите попытку.',
  );

  Future<void> _choosePlace(AppState state, Medicine package) async {
    final picked = await showPlacePicker(
      context,
      state: state,
      kitId: package.pharmacyId,
      selected: package.location.trim(),
      includeAll: false,
    );
    if (!mounted) return;
    switch (picked) {
      case PlaceChosen(:final place?):
        await _run(
          () => _controller.movePackage(
            package.id,
            kitId: package.pharmacyId,
            place: place,
          ),
          'Не удалось сохранить место. Повторите попытку.',
        );
      case ManagePlaces():
        context.push(AppRoutes.places);
      case PlaceChosen() || null:
        break;
    }
  }

  Future<void> _choosePurpose(Medicine package) async {
    final pick = await showPurposeSheet(
      context,
      purposes: package.purposes,
      custom: package.customPurpose ?? '',
    );
    if (pick == null) return;
    await _run(
      () => _controller.setPurposes(
        package.id,
        pick.purposes,
        custom: pick.custom,
      ),
      'Не удалось сохранить. Повторите попытку.',
    );
  }

  Future<void> _setExpiry(Medicine package) async {
    final date = await showExpirySheet(context, current: package.expiryDate);
    if (date == null) return;
    await _run(
      () => _controller.setExpiry(package.id, date),
      'Не удалось сохранить срок. Повторите попытку.',
    );
  }

  Future<void> _open(Medicine package) async {
    // An empty term still marks the package opened: the card then asks for
    // the term after opening (875:12468).
    final pick = await showOpenSheet(context, package);
    if (pick == null) return;
    await _run(
      () => _controller.openPackage(
        package.id,
        pick.days,
        openedAt: pick.openedAt,
      ),
      'Не удалось отметить вскрытие. Повторите попытку.',
    );
  }

  Future<void> _editCount(Medicine package) async {
    final quantity = await showStockSheet(context, package, fromCard: true);
    if (quantity == null) return;
    await _setQuantity(package, quantity);
  }

  Future<void> _editLevel(Medicine package) async {
    final level = await showLevelSheet(context, package);
    if (level == null) return;
    await _run(
      () => _controller.setStockLevel(package.id, level),
      'Не удалось сохранить остаток. Повторите попытку.',
    );
  }

  Future<void> _addNote(Medicine package) async {
    final note = await showNoteSheet(context, current: package.notes ?? '');
    if (note == null || note.trim().isEmpty) return;
    await _run(
      () => _controller.setNotes(package.id, note),
      'Не удалось сохранить заметку. Повторите попытку.',
    );
  }

  Future<void> _setAfterOpening(Medicine package) async {
    final pick = await showAfterOpeningSheet(
      context,
      current: package.afterOpeningDays,
    );
    final days = pick?.days;
    if (days == null) return;
    await _run(
      () => _controller.setAfterOpeningDays(package.id, days),
      'Не удалось сохранить срок. Повторите попытку.',
    );
  }

  Future<void> _move(AppState state, Medicine package) async {
    final target = await showMoveSheet(
      context,
      state: state,
      package: package,
      fromCard: true,
    );
    if (target == null || !mounted) return;
    await _run(
      () => _controller.movePackage(
        package.id,
        kitId: target.kitId,
        place: target.place,
      ),
      'Не удалось перенести упаковку. Повторите попытку.',
    );
    if (!mounted || target.kitId == package.pharmacyId) return;
    showAppToast(
      context,
      '${readableDrugName(package.name)} перенесён в '
      '«${state.kitById(target.kitId)?.name ?? ''}»',
    );
  }

  Future<void> _remove(AppState state, Medicine package) async {
    // The reason is asked as in 880:15272; nothing stores it yet.
    final reason = await showRemoveSheet(
      context,
      package,
      suggested: suggestedRemovalReason(
        package,
        DateTime.now(),
        warningDays: state.settings.expiryWarningDays,
      ),
    );
    if (reason == null || !mounted) return;
    // The screen closes before «Отменить» is tapped: keep the controller.
    final controller = _controller;
    final AppState snapshot;
    try {
      snapshot = await controller.removePackage(package.id);
    } catch (_) {
      if (mounted) {
        showAppToast(context, 'Не удалось убрать упаковку. Повторите попытку.');
      }
      return;
    }
    if (!mounted) return;
    showAppToast(
      context,
      '${readableDrugName(package.name)} убран из аптечки',
      actionLabel: 'Отменить',
      onAction: () => controller.restoreSnapshot(snapshot),
    );
    _back();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = ref.watch(appControllerProvider);
    final state = value.asData?.value;
    final package = state?.medicines
        .where((m) => m.id == widget.packageId)
        .firstOrNull;
    final canEdit =
        package != null && state?.kitById(package.pharmacyId)?.canEdit == true;
    return Scaffold(
      backgroundColor: palette.background,
      extendBody: true,
      bottomNavigationBar: const AppNavigationBar(selectedIndex: 0),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleNavBar.card(
              title: package == null ? 'Лекарство' : packageTitle(package),
              onBack: _back,
              onEdit: canEdit ? () => _edit(package) : null,
            ),
            Expanded(
              child: AsyncValueView(
                value: value,
                data: (state) {
                  final package = state.medicines
                      .where((m) => m.id == widget.packageId)
                      .firstOrNull;
                  if (package == null) {
                    return Center(
                      child: Text(
                        'Упаковка не найдена',
                        style: AppTypography.bodySmall.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    );
                  }
                  return _content(state, package, canEdit: canEdit);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppState state, Medicine package, {required bool canEdit}) {
    final palette = context.palette;
    final now = DateTime.now();
    final settings = state.settings;
    final alert = packageAlert(
      package,
      now,
      warningDays: settings.expiryWarningDays,
      lowStockThreshold: settings.lowStockThreshold,
      course: packageCourse(state, package, now),
    );
    final opened = openedSummary(
      package,
      now,
      warningDays: settings.expiryWarningDays,
    );
    final others = otherPackages(state, package);
    final specs = packageSpecs(package);
    final meta = packageMetaLine(package, now);
    final usage = package.usage?.trim();
    final note = package.notes?.trim();
    const gap = SizedBox(height: 16);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            8,
            AppSpacing.page,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (alert != null) ...[
              StatusBanner(
                tone: switch (alert.tone) {
                  PackageAlertTone.warning => StatusBannerTone.warning,
                  PackageAlertTone.fail => StatusBannerTone.fail,
                  PackageAlertTone.info => StatusBannerTone.info,
                },
                title: alert.title,
                text: alert.text,
                actionLabel: canEdit
                    ? switch (alert.action) {
                        PackageAlertAction.remove => 'Убрать из аптечки',
                        PackageAlertAction.setExpiry => 'Указать срок',
                        PackageAlertAction.complete => 'Дополнить',
                        PackageAlertAction.setAfterOpening => 'Указать срок',
                        PackageAlertAction.openCourse => 'Открыть курс',
                        PackageAlertAction.kitState => 'Состояние аптечки',
                        null => null,
                      }
                    : null,
                onAction: !canEdit
                    ? null
                    : switch (alert.action) {
                        PackageAlertAction.remove => () =>
                            _remove(state, package),
                        PackageAlertAction.setExpiry => () =>
                            _setExpiry(package),
                        PackageAlertAction.complete => () => _edit(package),
                        PackageAlertAction.setAfterOpening => () =>
                            _setAfterOpening(package),
                        PackageAlertAction.openCourse => () => context.push(
                          AppRoutes.course(alert.courseId!),
                        ),
                        PackageAlertAction.kitState => () => context.push(
                          AppRoutes.kitState(package.pharmacyId),
                        ),
                        null => null,
                      },
              ),
              gap,
            ],
            PackageHero(
              package: package,
              expiry: packageExpiry(
                package,
                now,
                warningDays: settings.expiryWarningDays,
              ),
              dimmed: isUsedUp(package),
            ),
            gap,
            PackageFacts(
              facts: [
                PackageFact(
                  icon: 'detail-location',
                  label: 'Где лежит',
                  value: placeLabel(state, package),
                  onTap: canEdit ? () => _choosePlace(state, package) : null,
                ),
                PackageFact(
                  icon:
                      package.purposes.firstOrNull?.tagIcon ??
                      customPurposeIcon,
                  label: 'Для чего',
                  value: package.purposeLabel ?? 'Не указано',
                  onTap: canEdit ? () => _choosePurpose(package) : null,
                ),
              ],
            ),
            gap,
            _stock(package, now, canEdit: canEdit),
            if (canEdit) ...[
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: SwipeActionButton(
                        width: null,
                        icon: 'swipe-move',
                        label: 'Перенести',
                        onTap: () => _move(state, package),
                      ),
                    ),
                  ),
                  if (stockKindOf(package) == StockKind.level &&
                      package.openedAt == null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Center(
                        child: SwipeActionButton(
                        width: null,
                          icon: 'swipe-open',
                          label: 'Вскрыть',
                          onTap: () => _open(package),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: SwipeActionButton(
                        width: null,
                        icon: 'swipe-delete',
                        label: 'Убрать',
                        destructive: true,
                        onTap: () => _remove(state, package),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (opened != null) ...[
              gap,
              OpenedBlock(
                summary: opened,
                onSetTerm: canEdit ? () => _setAfterOpening(package) : null,
              ),
            ],
            if (others.isNotEmpty) ...[
              gap,
              Text(
                'Другие упаковки · ${others.length}',
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ActionGroup(
                radius: AppRadius.md,
                children: [
                  for (final other in others)
                    ActionRow(
                      title: otherPackageTitle(state, other),
                      subtitle: otherPackageSubtitle(other, now),
                      onTap: () => context.push(AppRoutes.medicine(other.id)),
                    ),
                ],
              ),
              if (packagesTotal(package, others) case final total?) ...[
                const SizedBox(height: 8),
                Text(
                  total,
                  style: AppTypography.caption.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ],
            if (usage != null && usage.isNotEmpty) ...[
              gap,
              InfoCard(
                title: 'Как применять',
                text: usage,
                caption: 'Перед применением прочитайте инструкцию',
              ),
            ] else if (note == null || note.isEmpty) ...[
              gap,
              // 879:14912. «Сфотографировать вкладыш» needs a photo picker
              // the app does not have yet, so only the note is offered.
              InfoCard(
                title: 'Инструкции нет в справочнике',
                text: 'Добавьте заметку — например, как принимать.',
                linkLabel: canEdit ? 'Добавить заметку' : null,
                onLink: canEdit ? () => _addNote(package) : null,
              ),
            ],
            if (note != null && note.isNotEmpty) ...[
              gap,
              InfoCard(
                title: 'Заметка',
                text: note,
                caption: 'Заметка видна только участникам этой аптечки',
              ),
            ],
            if (specs.isNotEmpty) ...[
              gap,
              SpecsCard(title: 'Характеристики', rows: specs),
            ],
            if (meta != null) ...[
              gap,
              Text(
                meta,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stock(Medicine package, DateTime now, {required bool canEdit}) {
    final caption = stockCaption(package, now);
    switch (stockKindOf(package)) {
      case StockKind.off:
        return const StockOffCard();
      case StockKind.level:
        return StockLevelBar(
          labels: [for (final level in StockLevel.values) level.label],
          level: package.stockLevel!.index,
          caption: caption,
          onValueTap: canEdit ? () => _editLevel(package) : null,
          onChanged: (index) {
            if (!canEdit) return;
            _run(
              () => _controller.setStockLevel(
                package.id,
                StockLevel.values[index],
              ),
              'Не удалось сохранить остаток. Повторите попытку.',
            );
          },
        );
      case StockKind.count:
        final quantity = package.quantity;
        return StockCounter(
          value: amountLabel(package),
          caption: caption,
          onValueTap: canEdit && !_saving ? () => _editCount(package) : null,
          onMinus: canEdit && !_saving && quantity > 0
              ? () => _setQuantity(package, quantity - 1)
              : null,
          onPlus: canEdit && !_saving
              ? () => _setQuantity(package, quantity + 1)
              : null,
        );
    }
  }
}
