import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_alert.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_sheet.dart';
import 'package:aptechka/core/ui/search_field.dart';
import 'package:aptechka/core/ui/radio_card.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/home/presentation/widgets/kit_icon_view.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_icon.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:flutter/material.dart';

typedef KitDraft = ({String name, KitIcon icon});

/// «Аптечки / Новая аптечка» (832:6713) and its error state (832:6766).
/// With [kit] the same sheet edits an existing kit.
Future<KitDraft?> showKitEditorSheet(
  BuildContext context, {
  required AppState state,
  Pharmacy? kit,
}) => showAppSheet<KitDraft>(
  context: context,
  title: kit == null ? 'Новая аптечка' : 'Изменить аптечку',
  builder: (_) => _KitEditor(state: state, kit: kit),
);

class _KitEditor extends StatefulWidget {
  const _KitEditor({required this.state, this.kit});
  final AppState state;
  final Pharmacy? kit;

  @override
  State<_KitEditor> createState() => _KitEditorState();
}

class _KitEditorState extends State<_KitEditor> {
  late final _name = TextEditingController(text: widget.kit?.name ?? '');
  late KitIcon _icon = widget.kit?.icon ?? KitIcon.home;
  late bool _iconChosen = widget.kit != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _value => _name.text.trim();
  bool get _taken =>
      _value.isNotEmpty &&
      widget.state.isKitNameTaken(_value, exceptId: widget.kit?.id);

  Future<void> _pickIcon() async {
    final icon = await showKitIconSheet(context, selected: _icon);
    if (icon != null) {
      setState(() {
        _icon = icon;
        _iconChosen = true;
      });
    }
  }

  void _submit() {
    if (_value.isEmpty || _taken) return;
    Navigator.pop<KitDraft>(context, (name: _value, icon: _icon));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final taken = _taken;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitNameField(
          controller: _name,
          icon: _icon,
          error: taken,
          onIconTap: _pickIcon,
          onChanged: (value) => setState(() {
            if (!_iconChosen) _icon = KitIcon.suggest(value);
          }),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        Text(
          taken
              ? 'Аптечка «$_value» уже есть. Придумайте другое название'
              : 'Пригласить близких можно после создания — в меню аптечки '
                    '«Общий доступ».',
          style: AppTypography.bodySmall.copyWith(
            color: taken ? palette.fail : palette.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: widget.kit == null ? 'Создать аптечку' : 'Сохранить',
          onPressed: _value.isEmpty || taken ? null : _submit,
        ),
      ],
    );
  }
}

/// Figma «kit name field» (846:10675): icon button with an edit badge and
/// the name field; error state adds a 1.5 pt fail border.
class KitNameField extends StatelessWidget {
  const KitNameField({
    required this.controller,
    required this.icon,
    required this.onIconTap,
    this.error = false,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final KitIcon icon;
  final VoidCallback onIconTap;
  final bool error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Иконка аптечки: ${icon.label}. Изменить',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onIconTap,
            child: SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: palette.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: KitIconView(icon, size: 28),
                  ),
                  Positioned(
                    left: 44,
                    top: 44,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.brandPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.background, width: 2),
                      ),
                      child: const DesignIcon('pen-12', size: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: palette.surfaceCard,
              borderRadius: BorderRadius.circular(30),
              border: error
                  ? Border.all(color: palette.fail, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Название',
                  style: AppTypography.labelMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  autofocus: controller.text.isEmpty,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  cursorColor: palette.brandPrimary,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// «Аптечки / Новая аптечка — выбор иконки» (844:10306).
Future<KitIcon?> showKitIconSheet(
  BuildContext context, {
  required KitIcon selected,
}) => showAppSheet<KitIcon>(
  context: context,
  title: 'Иконка аптечки',
  builder: (_) => _IconPicker(selected: selected),
);

class _IconPicker extends StatefulWidget {
  const _IconPicker({required this.selected});
  final KitIcon selected;

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  late KitIcon _selected = widget.selected;
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final query = _query.trim().toLowerCase();
    final groups = [
      for (final (title, icons) in kitIconGroups)
        (
          title,
          icons
              .where(
                (icon) =>
                    query.isEmpty ||
                    icon.label.toLowerCase().contains(query) ||
                    title.toLowerCase().contains(query),
              )
              .toList(),
        ),
    ].where((group) => group.$2.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          hint: 'Поиск иконки',
          onChanged: (value) => setState(() => _query = value),
        ),
        for (final (title, icons) in groups) ...[
          const SizedBox(height: 20),
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const Spacer(),
                if (i < icons.length)
                  _IconTile(
                    icon: icons[i],
                    selected: icons[i] == _selected,
                    onTap: () => setState(() => _selected = icons[i]),
                  )
                else
                  const SizedBox(width: 52),
              ],
            ],
          ),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: 'Готово',
          onPressed: () => Navigator.pop(context, _selected),
        ),
      ],
    );
  }
}

/// Figma «icon tile» (843:10339).
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final KitIcon icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: icon.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: selected
                ? Border.all(color: palette.brandPrimary, width: 2)
                : null,
          ),
          child: KitIconView(icon),
        ),
      ),
    );
  }
}

/// Result of the «Удалить «Дача»?» sheet: move target or `null` = delete.
typedef KitDeletion = ({String? moveTo});

/// «Удалить аптечку с лекарствами» (832:6843) and «… вместе с
/// лекарствами» (844:10540).
Future<KitDeletion?> showDeleteKitSheet(
  BuildContext context, {
  required AppState state,
  required Pharmacy kit,
}) => showAppSheet<KitDeletion>(
  context: context,
  title: 'Удалить «${kit.name}»?',
  builder: (_) => _DeleteKit(state: state, kit: kit),
);

class _DeleteKit extends StatefulWidget {
  const _DeleteKit({required this.state, required this.kit});
  final AppState state;
  final Pharmacy kit;

  @override
  State<_DeleteKit> createState() => _DeleteKitState();
}

class _DeleteKitState extends State<_DeleteKit> {
  late final List<Pharmacy> _targets = widget.state.pharmacies
      .where((item) => item.id != widget.kit.id && item.canEdit)
      .toList();
  late String? _target = _targets.firstOrNull?.id;
  late bool _move = _targets.isNotEmpty;

  Future<void> _chooseTarget() async {
    final picked = await showAppSheet<String>(
      context: context,
      title: 'Куда перенести',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, kit) in _targets.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            RadioCard(
              title: kit.name,
              subtitle: russianCount(
                widget.state.medicinesIn(kit.id).length,
                'лекарство',
                'лекарства',
                'лекарств',
              ),
              selected: kit.id == _target,
              onTap: () => Navigator.pop(sheetContext, kit.id),
            ),
          ],
        ],
      ),
    );
    if (picked != null) setState(() => _target = picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = widget.state.medicinesIn(widget.kit.id).length;
    final medicines = russianCount(count, 'лекарство', 'лекарства', 'лекарств');
    final targetName = widget.state.kitById(_target ?? '')?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'В аптечке $medicines. Что с ними сделать?',
          style: AppTypography.paragraph.copyWith(color: palette.textSecondary),
        ),
        if (_targets.isNotEmpty) ...[
          const SizedBox(height: 12),
          RadioCard(
            title: 'Перенести в другую аптечку',
            subtitle: 'Лекарства сохранятся вместе со сроками и остатками',
            selected: _move,
            onTap: () => setState(() => _move = true),
            extra: ChoiceRow(
              label: 'Куда',
              value: targetName,
              onTap: _chooseTarget,
            ),
          ),
        ],
        const SizedBox(height: 12),
        RadioCard(
          title: 'Удалить вместе с лекарствами',
          subtitle: '$medicines удалятся, восстановить будет нельзя',
          selected: !_move,
          onTap: () => setState(() => _move = false),
        ),
        const SizedBox(height: 12),
        _move
            ? AppButton(
                label: 'Перенести и удалить аптечку',
                onPressed: () => Navigator.pop<KitDeletion>(context, (
                  moveTo: _target,
                )),
              )
            : AppButton.destructive(
                label: 'Удалить аптечку и лекарства',
                onPressed: () =>
                    Navigator.pop<KitDeletion>(context, (moveTo: null)),
              ),
      ],
    );
  }
}

/// Full deletion flow from «1 · Мои аптечки»: alert for an empty kit,
/// the move-or-delete sheet otherwise, then a toast with «Отменить».
/// Returns true when the kit was deleted.
Future<bool> deleteKitFlow(
  BuildContext context,
  AppController controller,
  AppState state,
  Pharmacy kit,
) async {
  final count = state.medicinesIn(kit.id).length;
  String? moveTo;
  if (count == 0) {
    final confirmed = await showAppAlert(
      context: context,
      title: 'Удалить аптечку «${kit.name}»?',
      message: 'В ней нет лекарств. Это действие нельзя отменить.',
      confirmLabel: 'Удалить',
    );
    if (!confirmed) return false;
  } else {
    final choice = await showDeleteKitSheet(context, state: state, kit: kit);
    if (choice == null) return false;
    moveTo = choice.moveTo;
  }
  final snapshot = await controller.deletePharmacy(kit.id, moveTo: moveTo);
  if (!context.mounted) return true;
  final medicines = russianCount(count, 'лекарство', 'лекарства', 'лекарств');
  final target = moveTo == null ? null : state.kitById(moveTo)?.name;
  final moved =
      count % 10 == 1 && count % 100 != 11 ? 'перенесено' : 'перенесены';
  showAppToast(
    context,
    count == 0
        ? 'Аптечка «${kit.name}» удалена'
        : target != null
        ? 'Аптечка «${kit.name}» удалена, $medicines $moved в «$target»'
        : 'Аптечка «${kit.name}» удалена вместе с лекарствами',
    actionLabel: 'Отменить',
    onAction: () => controller.restoreSnapshot(snapshot),
  );
  return true;
}
