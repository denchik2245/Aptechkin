import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_chip.dart';
import 'package:aptechka/core/ui/nav_bars.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_search.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_variant.dart';
import 'package:aptechka/features/inventory/presentation/widgets/catalog_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Figma «Поиск / Варианты препарата» (893:17423): the packages of one name,
/// form chips «Все · 12», «Таблетки · 6» and «Выберите, что у вас на
/// упаковке».
class DrugCatalogVariantsScreen extends ConsumerStatefulWidget {
  const DrugCatalogVariantsScreen({
    required this.groupKey,
    this.initialGroup,
    super.key,
  });
  final String groupKey;
  final DrugCatalogGroup? initialGroup;

  @override
  ConsumerState<DrugCatalogVariantsScreen> createState() =>
      _DrugCatalogVariantsScreenState();
}

class _DrugCatalogVariantsScreenState
    extends ConsumerState<DrugCatalogVariantsScreen> {
  DrugCatalogGroup? _group;
  List<DrugCatalogVariant> _variants = const [];
  String? _form;
  bool _loading = false;
  bool _failed = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialGroup;
    if (initial != null) {
      _setGroup(initial);
    } else {
      _load();
    }
  }

  void _setGroup(DrugCatalogGroup group) {
    _group = group;
    _variants = group.variants;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final entries = await ref.read(drugCatalogServiceProvider).listAll();
      if (!mounted) return;
      final matches = entries
          .where((entry) => drugCatalogNameKey(entry.name) == widget.groupKey)
          .toList(growable: false);
      setState(() {
        if (matches.isNotEmpty) {
          _setGroup(DrugCatalogGroup(key: widget.groupKey, entries: matches));
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  List<DrugCatalogVariant> get _visible => _form == null
      ? _variants
      : [
          for (final variant in _variants)
            if (shortDrugForm(variant.entry.form) == _form) variant,
        ];

  Future<void> _choose(DrugCatalogVariant variant) async {
    final entry = variant.entry;
    await _openForm(
      extra: variant.isAmbiguous ? variant : entry,
      parameters: variant.isAmbiguous
          ? {
              'candidates': variant.entries
                  .map((e) => e.gtin)
                  .whereType<String>()
                  .join(','),
            }
          : entry.gtin == null
          ? null
          : {'catalog': entry.gtin!},
    );
  }

  Future<void> _openForm({
    Object? extra,
    Map<String, String>? parameters,
  }) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final saved = await context.push<bool>(
        Uri(
          path: AppRoutes.medicineNew,
          queryParameters: parameters,
        ).toString(),
        extra: extra,
      );
      if (!mounted || saved != true) return;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(AppRoutes.inventory);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
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
            TitleNavBar.modal(title: _group?.name ?? 'Варианты'),
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

  Widget _manualLink(String name) => Align(
    alignment: Alignment.centerLeft,
    child: AppLinkButton(
      label: 'Нет в справочнике? Заполнить вручную',
      onPressed: _opening ? null : () => _openForm(parameters: {'name': name}),
    ),
  );

  Widget _body(BuildContext context) {
    final palette = context.palette;
    final bottom = 24 + MediaQuery.viewPaddingOf(context).bottom;
    final group = _group;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed || group == null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
        children: [
          Text(
            _failed
                ? 'Не удалось загрузить варианты препарата'
                : 'Препарат не найден в справочнике',
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textPrimary,
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: 12),
            AppButton.secondary(label: 'Повторить загрузку', onPressed: _load),
          ],
          const SizedBox(height: 12),
          _manualLink(widget.groupKey),
        ],
      );
    }
    final forms = drugVariantForms(_variants);
    final visible = _visible;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
      itemCount: visible.length + 3,
      itemBuilder: (context, index) {
        if (index == 0) {
          if (forms.length < 2) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  AppChip(
                    label: 'Все · ${_variants.length}',
                    selected: _form == null,
                    onTap: () => setState(() => _form = null),
                  ),
                  for (final (form, count) in forms) ...[
                    const SizedBox(width: 8),
                    AppChip(
                      key: ValueKey('variant-filter-$form'),
                      label: '$form · $count',
                      selected: _form == form,
                      onTap: () =>
                          setState(() => _form = _form == form ? null : form),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        if (index == 1) {
          return Semantics(
            header: true,
            child: Text(
              'Выберите, что у вас на упаковке',
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          );
        }
        if (index == visible.length + 2) {
          return Padding(
            // 20 to the text; the 44 pt link centres its 22 pt line.
            padding: const EdgeInsets.only(top: 9),
            child: _manualLink(group.name),
          );
        }
        final variant = visible[index - 2];
        final entry = variant.entry;
        final maker = entry.manufacturer.trim().isEmpty
            ? ''
            : entry.displayManufacturer;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CatalogListItem(
            key: ValueKey('catalog-entry-${entry.id}'),
            title: drugVariantTitle(entry),
            details: drugVariantDetails(variant),
            source: entry.isInactive
                ? [
                    maker,
                    'запись недействующая',
                  ].where((part) => part.isNotEmpty).join(' · ')
                : maker,
            gtin: variant.isAmbiguous ? null : entry.gtin,
            photoName: entry.name,
            onTap: _opening ? null : () => _choose(variant),
          ),
        );
      },
    );
  }
}
