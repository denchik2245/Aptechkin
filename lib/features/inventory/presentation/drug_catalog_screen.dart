import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_chip.dart';
import 'package:aptechka/core/ui/empty_state_card.dart';
import 'package:aptechka/core/ui/nav_bars.dart';
import 'package:aptechka/core/ui/search_field.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/data/recent_searches.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_search.dart';
import 'package:aptechka/features/inventory/presentation/widgets/catalog_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Figma «Добавление препарата / 4 · Поиск по названию» (890:15549):
/// «Поиск / Начало» (recent searches, packages the user adds most),
/// «Результаты» (by name and by active ingredient), «Опечатка» («Возможно,
/// вы искали» and similar names) and «Ничего не найдено».
class DrugCatalogScreen extends ConsumerStatefulWidget {
  const DrugCatalogScreen({this.initialQuery = '', super.key});

  /// «Найти вручную» of the all-kits search passes what was searched.
  final String initialQuery;

  @override
  ConsumerState<DrugCatalogScreen> createState() => _DrugCatalogScreenState();
}

class _DrugCatalogScreenState extends ConsumerState<DrugCatalogScreen> {
  late final _query = TextEditingController(text: widget.initialQuery);
  final _scroll = ScrollController();
  List<IndexedDrugGroup> _groups = const [];
  DrugSearchResult _result = const DrugSearchResult();
  List<String> _recent = const [];
  bool _loading = true;
  bool _failed = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
    RecentSearches.drugs.load().then((value) {
      if (mounted) setState(() => _recent = value);
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final entries = await ref.read(drugCatalogServiceProvider).listAll();
      if (!mounted) return;
      setState(() {
        _groups = indexDrugGroups(entries);
        _loading = false;
        _result = searchDrugGroups(_groups, _query.text);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _search(String text) {
    setState(() => _result = searchDrugGroups(_groups, text));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _setQuery(String text) {
    _query.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _search(text);
  }

  void _done() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.inventory);
    }
  }

  Future<void> _openForm() async {
    if (_opening) return;
    _opening = true;
    FocusScope.of(context).unfocus();
    try {
      final saved = await context.push<bool>(AppRoutes.medicineNew);
      if (mounted && saved == true) _done();
    } finally {
      _opening = false;
    }
  }

  Future<void> _openGroup(DrugCatalogGroup group) async {
    if (_opening) return;
    _opening = true;
    FocusScope.of(context).unfocus();
    RecentSearches.drugs.remember(group.name).then((value) {
      if (mounted) setState(() => _recent = value);
    });
    try {
      final saved = await context.push<bool>(
        Uri(
          path: AppRoutes.medicineVariants,
          queryParameters: {'name': group.key},
        ).toString(),
        extra: group,
      );
      if (mounted && saved == true) _done();
    } finally {
      _opening = false;
    }
  }

  /// «Часто добавляют»: catalog names the user already keeps, most packages
  /// first.
  List<DrugCatalogGroup> _frequent() {
    final state = ref.watch(appControllerProvider).asData?.value;
    if (state == null || _groups.isEmpty) return const [];
    final counts = <String, int>{};
    for (final medicine in state.medicines) {
      final key = drugCatalogNameKey(medicine.name);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final byKey = {for (final item in _groups) item.group.key: item.group};
    final keys = counts.keys.where(byKey.containsKey).toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return [for (final key in keys.take(3)) byKey[key]!];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TitleNavBar.modal(title: 'Найти по названию'),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: _body(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final palette = context.palette;
    final bottom = 24 + MediaQuery.viewPaddingOf(context).bottom;
    final rows = <Widget Function()>[];
    void gap(double height) => rows.add(() => SizedBox(height: height));
    void label(String text) => rows.add(
      () => Semantics(
        header: true,
        child: Text(
          text,
          style: AppTypography.bodyMedium.copyWith(
            color: palette.textSecondary,
          ),
        ),
      ),
    );
    void groups(List<DrugCatalogGroup> items, {bool ingredient = false}) {
      for (var i = 0; i < items.length; i++) {
        final group = items[i];
        gap(8);
        rows.add(
          () => CatalogListItem(
            key: ValueKey('catalog-group-${group.key}'),
            title: drugGroupTitle(group),
            details: drugGroupDetails(group, ingredient: ingredient),
            gtin: group.entries
                .map((entry) => entry.gtin)
                .whereType<String>()
                .firstOrNull,
            photoName: group.name,
            onTap: () => _openGroup(group),
          ),
        );
      }
    }

    void manual() {
      // 20 to the text; the 44 pt link centres its 22 pt line.
      gap(9);
      rows.add(
        () => Align(
          alignment: Alignment.centerLeft,
          child: AppLinkButton(
            label: 'Нет в справочнике? Заполнить вручную',
            onPressed: _openForm,
          ),
        ),
      );
    }

    final query = _query.text.trim();
    if (_loading) {
      gap(20);
      rows.add(
        () => Text(
          'Загружаем справочник…',
          style: AppTypography.bodySmall.copyWith(color: palette.textSecondary),
        ),
      );
    } else if (_failed) {
      gap(20);
      rows.add(
        () => Text(
          'Справочник недоступен',
          style: AppTypography.bodyMedium.copyWith(color: palette.textPrimary),
        ),
      );
      gap(12);
      rows.add(
        () =>
            AppButton.secondary(label: 'Повторить загрузку', onPressed: _load),
      );
      manual();
    } else if (query.isEmpty) {
      if (_recent.isNotEmpty) {
        gap(20);
        label('Недавние');
        gap(8);
        rows.add(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in _recent)
                AppChip(
                  label: item,
                  icon: 'search-16',
                  tintIcon: true,
                  selected: false,
                  onTap: () => _setQuery(item),
                ),
            ],
          ),
        );
      }
      final frequent = _frequent();
      if (frequent.isNotEmpty) {
        gap(20);
        label('Часто добавляют');
        groups(frequent);
      }
      manual();
    } else if (_result.isEmpty) {
      gap(80);
      rows.add(
        () => Center(
          child: EmptyStateCard(
            image: 'assets/illustrations/onboarding/empty-medicines.png',
            imageZoom: 1.1146,
            title: 'Не нашли в справочнике',
            text:
                'Проверьте написание или заполните карточку сами — хватит '
                'названия, формы и срока',
            buttonLabel: 'Заполнить вручную',
            onPressed: _openForm,
          ),
        ),
      );
    } else if (_result.byName.isEmpty && _result.byIngredient.isEmpty) {
      final suggestion = _result.similar.first;
      gap(20);
      rows.add(
        () => Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Возможно, вы искали',
              style: AppTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
            AppChip(
              label: suggestion.name,
              selected: false,
              onTap: () => _setQuery(suggestion.name),
            ),
          ],
        ),
      );
      gap(20);
      label('Похожие');
      groups(_result.similar);
      manual();
    } else {
      if (_result.byName.isNotEmpty) {
        gap(20);
        label('По названию');
        groups(_result.byName);
      }
      if (_result.byIngredient.isNotEmpty) {
        gap(20);
        label('Содержат ${_result.ingredient ?? query.toLowerCase()}');
        groups(_result.byIngredient, ingredient: true);
      }
      manual();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AppSearchField(
            fieldKey: const ValueKey('catalog-name-input'),
            controller: _query,
            hint: 'Название или действующее вещество',
            onChanged: _search,
          ),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: ListView.builder(
              key: const ValueKey('catalog-list'),
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
              itemCount: rows.length,
              itemBuilder: (context, index) => rows[index](),
            ),
          ),
        ),
      ],
    );
  }
}
