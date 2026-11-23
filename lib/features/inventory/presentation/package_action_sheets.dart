import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_select.dart';
import 'package:aptechka/core/ui/app_sheet.dart';
import 'package:aptechka/core/ui/radio_card.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/features/inventory/domain/package_detail.dart';
import 'package:aptechka/features/inventory/domain/package_form.dart';
import 'package:aptechka/features/inventory/presentation/add_medicine_sheets.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:flutter/material.dart';

/// Sheets of the Figma «Карточка лекарства / 5 · Действия» (875:12470).
/// The count stepper and «Перенести упаковку» live in `inventory_sheets.dart`
/// (`showStockSheet` / `showMoveSheet` with `fromCard: true`).

/// «Сколько осталось?» for packages tracked by level (880:14928).
Future<StockLevel?> showLevelSheet(BuildContext context, Medicine package) =>
    showAppSheet<StockLevel>(
      context: context,
      title: 'Сколько осталось?',
      builder: (_) => _LevelPicker(package: package),
    );

class _LevelPicker extends StatefulWidget {
  const _LevelPicker({required this.package});
  final Medicine package;

  @override
  State<_LevelPicker> createState() => _LevelPickerState();
}

class _LevelPickerState extends State<_LevelPicker> {
  late StockLevel? _level = widget.package.stockLevel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final package = widget.package;
    final contents = readableDrugText(package.packageDescription ?? '');
    final name = [
      readableDrugName(package.name),
      if (contents.isNotEmpty) contents[0].toLowerCase() + contents.substring(1),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$name. Достаточно оценить на глаз',
          style: AppTypography.bodySmall.copyWith(color: palette.textSecondary),
        ),
        // Full first, as in the mockup.
        for (final level in StockLevel.values.reversed) ...[
          const SizedBox(height: 8),
          RadioCard(
            title: level.label,
            selected: level == _level,
            onTap: () => setState(() => _level = level),
          ),
        ],
        const SizedBox(height: 8),
        AppButton(
          label: 'Сохранить',
          onPressed: _level == null || _level == package.stockLevel
              ? null
              : () => Navigator.pop(context, _level),
        ),
      ],
    );
  }
}

/// Result of [showOpenSheet]: `days == null` — the term after opening is
/// not known yet.
typedef OpeningPick = ({DateTime openedAt, int? days});

/// «Отметить вскрытие» (880:15059): when and for how long it keeps.
Future<OpeningPick?> showOpenSheet(BuildContext context, Medicine package) =>
    showAppSheet<OpeningPick>(
      context: context,
      title: 'Отметить вскрытие',
      builder: (_) => _OpenEditor(package: package),
    );

class _OpenEditor extends StatefulWidget {
  const _OpenEditor({required this.package});
  final Medicine package;

  @override
  State<_OpenEditor> createState() => _OpenEditorState();
}

class _OpenEditorState extends State<_OpenEditor> {
  final _today = DateUtils.dateOnly(DateTime.now());
  DateTime? _otherDate;
  bool _other = false;
  late int? _days = widget.package.afterOpeningDays;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _otherDate ?? _today.subtract(const Duration(days: 1)),
      firstDate: DateTime(_today.year - 10),
      lastDate: _today,
      helpText: 'Дата вскрытия',
    );
    if (date == null || !mounted) return;
    setState(() {
      _otherDate = date;
      _other = true;
    });
  }

  Future<void> _pickTerm() async {
    final pick = await showAfterOpeningSheet(context, current: _days);
    if (pick == null || !mounted) return;
    setState(() => _days = pick.days);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final secondary = AppTypography.bodySmall.copyWith(
      color: palette.textSecondary,
    );
    final openedAt = _other ? _otherDate : _today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Когда открыли ${containerFor(widget.package.form)}?',
          style: secondary,
        ),
        const SizedBox(height: 8),
        RadioCard(
          title: 'Сегодня, ${shortDate(_today)}',
          selected: !_other,
          onTap: () => setState(() => _other = false),
        ),
        const SizedBox(height: 8),
        RadioCard(
          title: 'Другая дата',
          subtitle: _otherDate == null ? null : compactDate(_otherDate!),
          selected: _other,
          onTap: _pickDate,
        ),
        const SizedBox(height: 8),
        AppSelect(
          label: 'Срок после вскрытия',
          value: _days == null ? null : afterOpeningLabel(_days!),
          onTap: _pickTerm,
        ),
        const SizedBox(height: 8),
        Text(
          'Смотрите в инструкции: «после вскрытия хранить не более…». '
          'Не знаете — оставьте пустым, мы напомним уточнить',
          style: secondary,
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Отметить вскрытие',
          onPressed: openedAt == null
              ? null
              : () => Navigator.pop<OpeningPick>(context, (
                  openedAt: openedAt,
                  days: _days,
                )),
        ),
      ],
    );
  }
}

/// «Убрать …?» with the reason (880:15272).
Future<RemovalReason?> showRemoveSheet(
  BuildContext context,
  Medicine package, {
  RemovalReason? suggested,
}) => showAppSheet<RemovalReason>(
  context: context,
  title: 'Убрать ${readableDrugName(package.name)}?',
  builder: (_) => _RemoveReasonPicker(suggested: suggested),
);

class _RemoveReasonPicker extends StatefulWidget {
  const _RemoveReasonPicker({this.suggested});
  final RemovalReason? suggested;

  @override
  State<_RemoveReasonPicker> createState() => _RemoveReasonPickerState();
}

class _RemoveReasonPickerState extends State<_RemoveReasonPicker> {
  late RemovalReason? _reason = widget.suggested;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Почему убираете? Так точнее видно, чего не хватает',
          style: AppTypography.bodySmall.copyWith(color: palette.textSecondary),
        ),
        for (final reason in RemovalReason.values) ...[
          const SizedBox(height: 8),
          RadioCard(
            title: reason.label,
            selected: reason == _reason,
            onTap: () => setState(() => _reason = reason),
          ),
        ],
        const SizedBox(height: 8),
        AppButton.destructive(
          label: 'Убрать из аптечки',
          onPressed: _reason == null
              ? null
              : () => Navigator.pop(context, _reason),
        ),
      ],
    );
  }
}
