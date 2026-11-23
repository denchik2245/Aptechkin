import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/action_group.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_field.dart';
import 'package:aptechka/core/ui/app_sheet.dart';
import 'package:aptechka/core/ui/form_section.dart';
import 'package:aptechka/core/ui/radio_card.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/kit_state.dart';
import 'package:aptechka/features/inventory/domain/package_detail.dart';
import 'package:aptechka/features/inventory/domain/package_status.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';

String medicinesCount(int count) =>
    russianCount(count, 'лекарство', 'лекарства', 'лекарств');

/// Status line of a kit in pickers: icon and «1 срок истёк · 2 скоро истекут».
class KitStatusLine extends StatelessWidget {
  const KitStatusLine({required this.summary, super.key});
  final KitSummary summary;

  static String text(KitSummary summary) {
    String plural(int n, String one, String few, String many) {
      final mod10 = n % 10;
      final mod100 = n % 100;
      if (mod10 == 1 && mod100 != 11) return one;
      if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
        return few;
      }
      return many;
    }

    final parts = [
      if (summary.expired > 0)
        '${summary.expired} ${plural(summary.expired, 'срок истёк', 'срока истекли', 'сроков истекли')}',
      if (summary.soon > 0)
        '${summary.soon} скоро ${plural(summary.soon, 'истечёт', 'истекут', 'истекут')}',
    ];
    return parts.isEmpty ? 'Всё в норме' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final icon = summary.expired > 0
        ? 'status-fail-16'
        : summary.soon > 0
        ? 'status-soon-16'
        : 'status-ok-16';
    return Row(
      children: [
        DesignIcon(icon, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text(summary),
            style: AppTypography.bodySmall.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

String _kitSubtitle(AppState state, Pharmacy kit) {
  final count = medicinesCount(state.medicinesIn(kit.id).length);
  final access = kit.accessLabel;
  return access == null ? count : '$access · $count';
}

sealed class KitSwitcherResult {
  const KitSwitcherResult();
}

class KitSelected extends KitSwitcherResult {
  const KitSelected(this.kitId);
  final String kitId;
}

class KitCreateRequested extends KitSwitcherResult {
  const KitCreateRequested();
}

class AllKitsRequested extends KitSwitcherResult {
  const AllKitsRequested();
}

/// «Аптечка / Переключатель аптечек» (827:5947, 862:11731).
Future<KitSwitcherResult?> showKitSwitcher(
  BuildContext context, {
  required AppState state,
}) {
  final now = DateTime.now();
  return showAppSheet<KitSwitcherResult>(
    context: context,
    title: 'Аптечки',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, kit) in state.pharmacies.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          RadioCard(
            title: kit.name,
            subtitle: _kitSubtitle(state, kit),
            selected: kit.id == state.selectedPharmacyId,
            footer: KitStatusLine(summary: state.summaryOf(kit.id, now)),
            onTap: () => Navigator.pop(sheetContext, KitSelected(kit.id)),
          ),
        ],
        const SizedBox(height: 12),
        ActionGroup(
          children: [
            ActionRow(
              title: 'Создать аптечку',
              onTap: () =>
                  Navigator.pop(sheetContext, const KitCreateRequested()),
            ),
            ActionRow(
              title: 'Все аптечки',
              subtitle: 'Список, порядок и управление',
              onTap: () => Navigator.pop(sheetContext, const AllKitsRequested()),
            ),
          ],
        ),
      ],
    ),
  );
}

enum KitMenuAction { state, places, rename, delete }

/// «Аптечка / Меню» (827:6006). Rows for features that are not built yet
/// («Проверить аптечку», «Общий доступ») are added together with their
/// screens.
Future<KitMenuAction?> showKitMenu(
  BuildContext context, {
  required AppState state,
  required Pharmacy kit,
}) {
  final places = state.placesOf(kit.id).length;
  final categories = kitCategories(
    state,
    kit.id,
    DateTime.now(),
    warningDays: state.settings.expiryWarningDays,
  );
  return showAppSheet<KitMenuAction>(
    context: context,
    title: kit.name,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionGroup(
          children: [
            ActionRow(
              title: 'Состояние аптечки',
              subtitle: kitStateSummary(categories),
              onTap: () => Navigator.pop(sheetContext, KitMenuAction.state),
            ),
            ActionRow(
              title: 'Места хранения',
              subtitle: places == 0
                  ? 'Пока нет мест'
                  : russianCount(places, 'место', 'места', 'мест'),
              onTap: () => Navigator.pop(sheetContext, KitMenuAction.places),
            ),
            if (kit.canEdit)
              ActionRow(
                title: 'Переименовать',
                onTap: () => Navigator.pop(sheetContext, KitMenuAction.rename),
              ),
          ],
        ),
        if (kit.isOwn) ...[
          const SizedBox(height: 12),
          ActionGroup(
            children: [
              ActionRow(
                title: 'Удалить аптечку',
                destructive: true,
                onTap: () => Navigator.pop(sheetContext, KitMenuAction.delete),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// Result of [showPlacePicker]: a place, '' for «Место не указано»,
/// `null` for «Все места», or a request to manage places.
sealed class PlacePick {
  const PlacePick();
}

class PlaceChosen extends PlacePick {
  const PlaceChosen(this.place);
  final String? place;
}

class ManagePlaces extends PlacePick {
  const ManagePlaces();
}

/// «Аптечка / Выбор места» (827:6072).
Future<PlacePick?> showPlacePicker(
  BuildContext context, {
  required AppState state,
  required String kitId,
  required String? selected,
  bool includeAll = true,
  bool allowManage = true,
}) {
  final places = state.placesOf(kitId);
  final total = state.medicinesIn(kitId).length;
  final unplaced = state.countAt(kitId, '');
  return showAppSheet<PlacePick>(
    context: context,
    title: 'Место хранения',
    builder: (sheetContext) {
      Widget option(String? value, String title, int count) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RadioCard(
          title: title,
          subtitle: medicinesCount(count),
          selected: value == selected,
          onTap: () => Navigator.pop(sheetContext, PlaceChosen(value)),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (includeAll) option(null, 'Все места', total),
          for (final place in places)
            option(place, place, state.countAt(kitId, place)),
          if (unplaced > 0 || !includeAll)
            option('', 'Место не указано', unplaced),
          if (allowManage) ...[
            const SizedBox(height: 4),
            ActionGroup(
              children: [
                ActionRow(
                  title: 'Управлять местами',
                  subtitle: 'Добавить, переименовать, удалить',
                  onTap: () => Navigator.pop(sheetContext, const ManagePlaces()),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

/// «Список лекарств / Изменить остаток» (830:5954). Returns the new amount.
/// From the package card [fromCard] gives «Сколько осталось?» with the
/// name and place above and «Было 14 · в упаковке было 20» (880:14866).
Future<int?> showStockSheet(
  BuildContext context,
  Medicine package, {
  bool fromCard = false,
}) {
  return showAppSheet<int>(
    context: context,
    title: fromCard
        ? 'Сколько осталось?'
        : package.dosage.trim().isEmpty
        ? readableDrugName(package.name)
        : '${readableDrugName(package.name)}, ${package.dosage.trim()}',
    builder: (_) => _StockEditor(package: package, fromCard: fromCard),
  );
}

class _StockEditor extends StatefulWidget {
  const _StockEditor({required this.package, this.fromCard = false});
  final Medicine package;
  final bool fromCard;

  @override
  State<_StockEditor> createState() => _StockEditorState();
}

class _StockEditorState extends State<_StockEditor> {
  late int _value = widget.package.quantity;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final package = widget.package;
    final place = package.location.trim();
    final status = packageStatusLine(package, DateTime.now()).text;
    final unit = amountLabel(package.copyWith(quantity: _value))
        .replaceFirst(RegExp(r'^\d+\s*'), '');
    Widget step(String icon, String label, int delta) {
      // 880:14866: «+» is the primary button in the card's sheet.
      final primary = widget.fromCard && delta > 0;
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: primary ? palette.brandPrimary : palette.buttonSecondary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _value + delta < 0
                ? null
                : () => setState(() => _value += delta),
            child: SizedBox.square(
              dimension: 56,
              child: Center(
                child: DesignIcon(
                  icon,
                  size: 24,
                  color: primary ? palette.textOnAccent : palette.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final secondary = AppTypography.bodySmall.copyWith(
      color: palette.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.fromCard
              ? [
                  readableDrugName(package.name),
                  if (place.isNotEmpty)
                    place[0].toLowerCase() + place.substring(1),
                ].join(' · ')
              : '${place.isEmpty ? 'Место не указано' : 'Место: $place'} · '
                    '${status[0].toLowerCase()}${status.substring(1)}',
          style: secondary,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surfaceCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              step('stepper-minus', 'Меньше', -1),
              Column(
                children: [
                  Text(
                    '$_value',
                    style: AppTypography.h1Tight.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(unit, style: secondary),
                ],
              ),
              step('stepper-plus', 'Больше', 1),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          [
            _value == package.quantity
                ? 'Сейчас ${package.quantity}'
                : 'Было ${package.quantity}',
            if (widget.fromCard)
              if (packagePieces(package) case final pieces?)
                'в упаковке было $pieces',
          ].join(' · '),
          textAlign: TextAlign.center,
          style: secondary,
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Сохранить',
          onPressed: _value == package.quantity
              ? null
              : () => Navigator.pop(context, _value),
        ),
      ],
    );
  }
}

typedef PackageDestination = ({String kitId, String place});

/// «Список лекарств / Перенести» (830:5999); from the package card
/// [fromCard] gives «Перенести упаковку» / «Куда переложили?» (880:15157).
Future<PackageDestination?> showMoveSheet(
  BuildContext context, {
  required AppState state,
  required Medicine package,
  bool fromCard = false,
}) => showAppSheet<PackageDestination>(
  context: context,
  title: fromCard
      ? 'Перенести упаковку'
      : 'Перенести ${readableDrugName(package.name)}',
  builder: (_) => _MoveEditor(
    state: state,
    package: package,
    question: fromCard ? 'Куда переложили?' : 'Куда переложили упаковку?',
  ),
);

class _MoveEditor extends StatefulWidget {
  const _MoveEditor({
    required this.state,
    required this.package,
    required this.question,
  });
  final AppState state;
  final Medicine package;
  final String question;

  @override
  State<_MoveEditor> createState() => _MoveEditorState();
}

class _MoveEditorState extends State<_MoveEditor> {
  late String _kit = widget.package.pharmacyId;
  late String _place = widget.package.location.trim();

  void _select(String kitId) => setState(() {
    if (_kit == kitId) return;
    _kit = kitId;
    _place = kitId == widget.package.pharmacyId
        ? widget.package.location.trim()
        : widget.state.placesOf(kitId).firstOrNull ?? '';
  });

  Future<void> _choosePlace() async {
    final picked = await showPlacePicker(
      context,
      state: widget.state,
      kitId: _kit,
      selected: _place,
      includeAll: false,
      allowManage: false,
    );
    if (picked is PlaceChosen) setState(() => _place = picked.place ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = widget.state;
    final current = widget.package.pharmacyId;
    final kits = state.pharmacies.where((kit) => kit.canEdit).toList();
    final unchanged =
        _kit == current && _place == widget.package.location.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.question,
          style: AppTypography.bodySmall.copyWith(color: palette.textSecondary),
        ),
        for (final kit in kits) ...[
          const SizedBox(height: 8),
          RadioCard(
            title: kit.name,
            subtitle: kit.id == current
                ? (widget.package.location.trim().isEmpty
                      ? 'Место не указано'
                      : widget.package.location.trim())
                : _kitSubtitle(state, kit),
            selected: kit.id == _kit,
            badge: kit.id == current ? const _HereBadge() : null,
            onTap: () => _select(kit.id),
            extra: ChoiceRow(
              label: 'Место',
              value: _place.isEmpty ? 'Не указано' : _place,
              onTap: _choosePlace,
            ),
          ),
        ],
        const SizedBox(height: 8),
        AppButton(
          label: 'Перенести',
          onPressed: unchanged
              ? null
              : () => Navigator.pop<PackageDestination>(context, (
                  kitId: _kit,
                  place: _place,
                )),
        ),
      ],
    );
  }
}

/// «Сейчас здесь» badge of the radio card.
class _HereBadge extends StatelessWidget {
  const _HereBadge();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.brandPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DesignIcon('pin-14-brand', size: 14),
          const SizedBox(width: 4),
          Text(
            'Сейчас здесь',
            style: AppTypography.labelMedium.copyWith(
              color: palette.brandPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// «Места хранения / Новое место» (827:5848); with [initial] it renames.
Future<String?> showPlaceEditor(
  BuildContext context, {
  required AppState state,
  required String kitId,
  String? initial,
}) => showAppSheet<String>(
  context: context,
  title: initial == null ? 'Новое место' : 'Переименовать место',
  builder: (_) => _PlaceEditor(state: state, kitId: kitId, initial: initial),
);

class _PlaceEditor extends StatefulWidget {
  const _PlaceEditor({required this.state, required this.kitId, this.initial});
  final AppState state;
  final String kitId;
  final String? initial;

  @override
  State<_PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<_PlaceEditor> {
  late final _name = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _value => _name.text.trim();
  bool get _taken =>
      _value.isNotEmpty &&
      widget.state.isPlaceTaken(widget.kitId, _value, except: widget.initial);

  void _submit() {
    if (_value.isEmpty || _taken || _value == widget.initial) return;
    Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField(
          label: 'Название места',
          controller: _name,
          autofocus: true,
          error: _taken,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        // «Выбор / Новое место» (894:17956): caption and button 8 apart.
        const SizedBox(height: 8),
        FieldCaption(
          _taken
              ? 'Место «$_value» уже есть в этой аптечке'
              : widget.initial == null
              ? 'Появится в аптечке «${widget.state.kitById(widget.kitId)?.name ?? ''}» '
                    'и в фильтре по местам'
              : 'Например: «Верхняя полка», «Холодильник», «Сумка ребёнка»',
          error: _taken,
        ),
        const SizedBox(height: 8),
        AppButton(
          label: widget.initial == null ? 'Добавить место' : 'Сохранить',
          onPressed: _value.isEmpty || _taken || _value == widget.initial
              ? null
              : _submit,
        ),
      ],
    );
  }
}
