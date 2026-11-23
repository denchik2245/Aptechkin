import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_chip.dart';
import 'package:aptechka/core/ui/app_select.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_entry.dart';
import 'package:aptechka/features/inventory/domain/package_form.dart';
import 'package:aptechka/features/inventory/domain/quick_add.dart';
import 'package:aptechka/features/inventory/presentation/add_medicine_sheets.dart';
import 'package:aptechka/features/inventory/presentation/widgets/catalog_item.dart';
import 'package:aptechka/features/scanner/domain/scanned_code.dart';
import 'package:flutter/material.dart';

/// What the quick card adds: the place and, for a plain barcode, the date
/// the user picked.
typedef QuickAddPick = ({String place, DateTime? expiry});

/// Figma «quick card» (892:16950, 892:17074): the scanned package under the
/// camera — catalog item with «Подробнее», «Срок годности *» when the code
/// has no date, place chips «Положить в «Дом»», «Пропустить» / «Добавить».
class QuickAddCard extends StatefulWidget {
  const QuickAddCard({
    required this.entry,
    required this.code,
    required this.kitName,
    required this.places,
    required this.initialPlace,
    required this.onDetails,
    required this.onSkip,
    required this.onAdd,
    this.busy = false,
    super.key,
  });

  final DrugCatalogEntry entry;
  final ScannedCode code;
  final String kitName;
  final List<String> places;
  final String? initialPlace;
  final VoidCallback onDetails;
  final VoidCallback onSkip;
  final ValueChanged<QuickAddPick> onAdd;
  final bool busy;

  @override
  State<QuickAddCard> createState() => _QuickAddCardState();
}

class _QuickAddCardState extends State<QuickAddCard> {
  late String? _place = widget.initialPlace;
  DateTime? _expiry;

  bool get _needsExpiry => widget.code.expiry == null;

  Future<void> _pickExpiry() async {
    final date = await showExpirySheet(context, current: _expiry);
    if (date != null && mounted) setState(() => _expiry = date);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ready = !widget.busy && (!_needsExpiry || _expiry != null);
    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: palette.divider,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          CatalogItemCard(
            entry: widget.entry,
            onChange: widget.onDetails,
            actionLabel: 'Подробнее',
            actionSemantics: 'Подробнее о препарате',
            source: quickSourceLine(widget.code),
          ),
          if (_needsExpiry) ...[
            const SizedBox(height: 12),
            AppSelect(
              label: 'Срок годности',
              required: true,
              value: _expiry == null ? null : monthYearLabel(_expiry!),
              onTap: _pickExpiry,
            ),
          ],
          if (widget.places.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Положить в «${widget.kitName}»',
              style: AppTypography.caption.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final item in widget.places) ...[
                    if (item != widget.places.first) const SizedBox(width: 8),
                    AppChip(
                      label: item,
                      icon: item == _place ? 'pin-16-white' : 'pin-16-brand',
                      selected: item == _place,
                      onTap: () => setState(() => _place = item),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Пропустить',
                  onPressed: widget.busy ? null : widget.onSkip,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Добавить',
                  onPressed: ready
                      ? () => widget.onAdd((
                          place: _place ?? '',
                          expiry: widget.code.expiry ?? _expiry,
                        ))
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
