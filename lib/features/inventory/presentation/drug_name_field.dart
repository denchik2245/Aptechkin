import 'dart:async';

import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_field.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_search.dart';
import 'package:aptechka/features/inventory/presentation/widgets/catalog_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inline results remain part of the form scroll, including on narrow screens.
class DrugNameField extends ConsumerStatefulWidget {
  const DrugNameField({
    required this.controller,
    this.error = false,
    required this.onChanged,
    required this.onSelected,
    super.key,
  });

  final TextEditingController controller;
  final bool error;
  final ValueChanged<String> onChanged;
  final ValueChanged<DrugCatalogEntry> onSelected;

  @override
  ConsumerState<DrugNameField> createState() => _DrugNameFieldState();
}

class _DrugNameFieldState extends ConsumerState<DrugNameField> {
  Timer? _debounce;
  int _generation = 0;
  String _query = '';
  List<DrugCatalogEntry> _results = const [];
  bool _loading = false;
  bool _showResults = false;
  bool _failed = false;
  int _limit = 6;
  bool _hasMore = false;

  @override
  void didUpdateWidget(covariant DrugNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.text.trim() != _query) {
      // Scanner/programmatic prefills supersede any pending typed search.
      _dismiss();
      _query = widget.controller.text.trim();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    super.dispose();
  }

  void _dismiss() {
    _debounce?.cancel();
    _generation++;
    _showResults = false;
    _loading = false;
    _failed = false;
    _results = const [];
    _hasMore = false;
  }

  void _search(String value, {bool more = false}) {
    _debounce?.cancel();
    final generation = ++_generation;
    _query = value.trim();
    _limit = more ? _limit + 6 : 6;
    setState(() {
      if (!more) _results = const [];
      _hasMore = false;
      _failed = false;
      _showResults = _query.length >= 2;
      _loading = _showResults;
    });
    if (!_showResults) return;
    _debounce = Timer(Duration(milliseconds: more ? 0 : 250), () async {
      try {
        final matches = await ref
            .read(drugCatalogServiceProvider)
            .search(_query, limit: _limit + 1);
        if (!mounted || generation != _generation) return;
        setState(() {
          _hasMore = matches.length > _limit;
          _results = matches.take(_limit).toList();
          _loading = false;
        });
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    });
  }

  void _choose(DrugCatalogEntry entry) {
    setState(() {
      _dismiss();
      _query = entry.displayName;
    });
    widget.onSelected(entry);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final secondary = AppTypography.bodySmall.copyWith(
      color: palette.textSecondary,
    );
    Widget link(String label, VoidCallback onPressed) => Align(
      alignment: Alignment.centerLeft,
      child: AppLinkButton(label: label, onPressed: onPressed),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField(
          fieldKey: const ValueKey('drug-name-input'),
          label: 'Название',
          controller: widget.controller,
          required: true,
          placeholderWhenEmpty: true,
          error: widget.error,
          maxLength: 120,
          onChanged: (value) {
            widget.onChanged(value);
            _search(value);
          },
        ),
        // Suggestions as «catalog item» rows of «Поиск по названию»
        // (890:15549).
        if (_showResults) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _loading
                  ? 'Ищем в справочнике…'
                  : _failed
                  ? 'Не удалось выполнить поиск'
                  : _results.isEmpty
                  ? 'Совпадений не найдено'
                  : 'Выберите препарат · ${russianCount(_results.length, 'вариант', 'варианта', 'вариантов')}',
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
          if (!_loading && !_failed && _results.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Попробуйте другое название или заполните характеристики вручную.',
              style: secondary,
            ),
          ],
          if (_failed)
            link('Повторить поиск', () => _search(widget.controller.text)),
          for (final entry in _results) ...[
            const SizedBox(height: 8),
            CatalogListItem(
              title: drugVariantTitle(entry),
              details: CatalogItemCard.detailsOf(entry),
              source: entry.isInactive
                  ? 'В источнике: ${entry.registrationStatus}'
                  : CatalogItemCard.sourceOf(entry),
              gtin: entry.gtin,
              photoName: entry.name,
              onTap: () => _choose(entry),
            ),
          ],
          if (_hasMore && !_loading) ...[
            const SizedBox(height: 4),
            link(
              'Показать ещё варианты',
              () => _search(widget.controller.text, more: true),
            ),
          ],
          link('Заполнить вручную', () => setState(_dismiss)),
        ],
      ],
    );
  }
}
