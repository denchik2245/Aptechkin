import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_chip.dart';
import 'package:aptechka/core/ui/app_field.dart';
import 'package:aptechka/core/ui/app_sheet.dart';
import 'package:aptechka/core/ui/form_section.dart';
import 'package:aptechka/core/ui/radio_card.dart';
import 'package:aptechka/core/ui/radio_row.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/package_form.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:flutter/material.dart';

// Pickers of the package form: «Добавление · 5 · Выбор значений и выход»
// (890:15550).

/// «Выбор / Форма выпуска» (894:17472): «radio row» group; a tap chooses.
Future<DrugFormOption?> showDrugFormSheet(
  BuildContext context, {
  String? current,
}) => showAppSheet<DrugFormOption>(
  context: context,
  title: 'Форма выпуска',
  builder: (sheetContext) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RadioRowGroup(
        children: [
          for (final option in drugFormOptions)
            RadioRow(
              label: option.label,
              icon: option.icon,
              selected: option.form == current,
              onTap: () => Navigator.pop(sheetContext, option),
            ),
        ],
      ),
      const SizedBox(height: 8),
      const FieldCaption(
        'От формы зависит, как считать остаток: штуками или примерно',
      ),
    ],
  ),
);

/// «Выбор / Срок годности» (894:17618): month and year wheels. Returns the
/// end of the month.
Future<DateTime?> showExpirySheet(BuildContext context, {DateTime? current}) {
  final now = DateTime.now();
  final initial = current ?? DateTime(now.year + 1, now.month);
  final firstYear = now.year - 5;
  return showAppSheet<DateTime>(
    context: context,
    title: 'Срок годности',
    subtitle: 'На упаковке он подписан «Годен до» или EXP',
    builder: (_) =>
        _MonthYearPicker(initial: initial, firstYear: firstYear, years: 21),
  );
}

class _MonthYearPicker extends StatefulWidget {
  const _MonthYearPicker({
    required this.initial,
    required this.firstYear,
    required this.years,
  });
  final DateTime initial;
  final int firstYear;
  final int years;

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int _month = widget.initial.month;
  late int _year = widget.initial.year
      .clamp(widget.firstYear, widget.firstYear + widget.years - 1)
      .toInt();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _FlatWheel(
                      count: 12,
                      initial: _month - 1,
                      label: (i) => monthName(i + 1),
                      onChanged: (i) => _month = i + 1,
                    ),
                  ),
                  Expanded(
                    child: _FlatWheel(
                      count: widget.years,
                      initial: _year - widget.firstYear,
                      label: (i) => '${widget.firstYear + i}',
                      onChanged: (i) => _year = widget.firstYear + i,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Готово',
          onPressed: () => Navigator.pop(context, endOfMonth(_year, _month)),
        ),
      ],
    );
  }
}

/// Figma «Wheel» (894:17670): a flat list of 40 pt rows that snaps to the
/// row on the white plate. The selected row is Body/Large, the next ones
/// Body/Medium at 60 % and 30 %. A tap on a row selects it.
class _FlatWheel extends StatefulWidget {
  const _FlatWheel({
    required this.count,
    required this.initial,
    required this.label,
    required this.onChanged,
  });
  final int count;
  final int initial;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  State<_FlatWheel> createState() => _FlatWheelState();
}

class _FlatWheelState extends State<_FlatWheel> {
  static const _extent = 40.0;
  late int _selected = widget.initial;
  late final _scroll = ScrollController(
    initialScrollOffset: widget.initial * _extent,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _selected) return;
    setState(() => _selected = index);
    widget.onChanged(index);
  }

  void _snap() {
    final target = _selected * _extent;
    if (!_scroll.hasClients || (_scroll.offset - target).abs() < 0.5) return;
    // After the current gesture settles.
    Future.microtask(() {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _select(
            (_scroll.offset / _extent).round().clamp(0, widget.count - 1),
          );
        } else if (notification is ScrollEndNotification) {
          _snap();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: _extent * 2),
        itemExtent: _extent,
        itemCount: widget.count,
        itemBuilder: (context, i) {
          final distance = (i - _selected).abs();
          final text = widget.label(i);
          return Semantics(
            button: true,
            selected: distance == 0,
            label: text,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _select(i);
                _scroll.animateTo(
                  i * _extent,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                );
              },
              child: Center(
                child: distance == 0
                    ? Text(
                        text,
                        style: AppTypography.bodyLarge.copyWith(
                          color: palette.textPrimary,
                        ),
                      )
                    : Opacity(
                        opacity: distance == 1 ? 0.6 : 0.3,
                        child: Text(
                          text,
                          style: AppTypography.bodyMedium.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Result of [showAfterOpeningSheet]: `days == null` is «Не знаю — не
/// учитывать».
typedef AfterOpeningPick = ({int? days});

/// «Выбор / Срок после вскрытия» (894:17748).
Future<AfterOpeningPick?> showAfterOpeningSheet(
  BuildContext context, {
  int? current,
}) => showAppSheet<AfterOpeningPick>(
  context: context,
  title: 'Срок после вскрытия',
  subtitle: 'Срок указан в инструкции, в разделе «Условия хранения»',
  builder: (_) => _AfterOpeningPicker(current: current),
);

class _AfterOpeningPicker extends StatefulWidget {
  const _AfterOpeningPicker({this.current});
  final int? current;

  @override
  State<_AfterOpeningPicker> createState() => _AfterOpeningPickerState();
}

class _AfterOpeningPickerState extends State<_AfterOpeningPicker> {
  late int? _days = widget.current;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final days in afterOpeningOptions)
            AppChip(
              label: afterOpeningLabel(days),
              selected: _days == days,
              onTap: () => setState(() => _days = days),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: AppLinkButton(
          label: 'Не знаю — не учитывать',
          onPressed: () => Navigator.pop(context, (days: null)),
        ),
      ),
      const SizedBox(height: 8),
      AppButton(
        label: 'Готово',
        onPressed: _days == null
            ? null
            : () => Navigator.pop(context, (days: _days)),
      ),
    ],
  );
}

/// «Выбор / Аптечка» (894:17833): only kits the user can edit; the choice
/// is confirmed by «Готово».
Future<String?> showKitPickerSheet(
  BuildContext context, {
  required AppState state,
  required String current,
}) => showAppSheet<String>(
  context: context,
  title: 'В какую аптечку',
  builder: (_) => _KitPicker(state: state, current: current),
);

class _KitPicker extends StatefulWidget {
  const _KitPicker({required this.state, required this.current});
  final AppState state;
  final String current;

  @override
  State<_KitPicker> createState() => _KitPickerState();
}

class _KitPickerState extends State<_KitPicker> {
  late String _kitId = widget.current;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kit in state.pharmacies.where((kit) => kit.canEdit)) ...[
          RadioCard(
            title: kit.name,
            subtitle:
                kit.accessLabel ??
                russianCount(
                  state.medicinesIn(kit.id).length,
                  'лекарство',
                  'лекарства',
                  'лекарств',
                ),
            selected: kit.id == _kitId,
            onTap: () => setState(() => _kitId = kit.id),
          ),
          const SizedBox(height: 8),
        ],
        AppButton(
          label: 'Готово',
          onPressed: () => Navigator.pop(context, _kitId),
        ),
      ],
    );
  }
}

/// Result of [showPurposeSheet]: the chosen marks and «Свой вариант».
typedef PurposePick = ({List<MedicinePurpose> purposes, String custom});

/// «Выбор / Для чего» (894:17683): several chips and «Свой вариант».
Future<PurposePick?> showPurposeSheet(
  BuildContext context, {
  List<MedicinePurpose> purposes = const [],
  String custom = '',
}) => showAppSheet<PurposePick>(
  context: context,
  title: 'Для чего это лекарство',
  subtitle:
      'Можно выбрать несколько — по ним удобно искать, когда что-то болит',
  builder: (_) => _PurposePicker(purposes: purposes, custom: custom),
);

class _PurposePicker extends StatefulWidget {
  const _PurposePicker({required this.purposes, required this.custom});
  final List<MedicinePurpose> purposes;
  final String custom;

  @override
  State<_PurposePicker> createState() => _PurposePickerState();
}

class _PurposePickerState extends State<_PurposePicker> {
  late final _chosen = {...widget.purposes};
  late final _custom = TextEditingController(text: widget.custom);

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final purpose in MedicinePurpose.values)
            AppChip(
              label: purpose.label,
              icon: purpose.chipIcon,
              whiteWhenSelected: true,
              selected: _chosen.contains(purpose),
              onTap: () => setState(() {
                if (!_chosen.remove(purpose)) _chosen.add(purpose);
              }),
            ),
        ],
      ),
      const SizedBox(height: 16),
      AppField(
        fieldKey: const ValueKey('purpose-custom-input'),
        label: 'Свой вариант',
        controller: _custom,
        placeholderWhenEmpty: true,
      ),
      const SizedBox(height: 16),
      AppButton(
        label: 'Готово',
        onPressed: () => Navigator.pop(context, (
          purposes: [
            for (final purpose in MedicinePurpose.values)
              if (_chosen.contains(purpose)) purpose,
          ],
          custom: _custom.text.trim(),
        )),
      ),
    ],
  );
}

/// «Заметка». Returns the new text ('' clears it).
Future<String?> showNoteSheet(BuildContext context, {String current = ''}) =>
    showAppSheet<String>(
      context: context,
      title: 'Заметка',
      builder: (_) => _NoteEditor(current: current),
    );

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.current});
  final String current;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _text = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppField(
        label: 'Заметка',
        controller: _text,
        autofocus: true,
        maxLength: 300,
        maxLines: 5,
      ),
      const SizedBox(height: 12),
      AppButton(
        label: 'Сохранить',
        onPressed: () => Navigator.pop(context, _text.text.trim()),
      ),
    ],
  );
}
