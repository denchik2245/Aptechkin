import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_chip.dart';
import 'package:aptechka/core/ui/search_field.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/recent_searches.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_search.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_card.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// «Аптечка · 4 · Поиск по всем аптечкам» (825:4881): start with «Недавние»
/// and «Что есть от…», results by kit, «В «Доме» нет», «Ничего не
/// найдено» and the search by symptom.
class KitSearchScreen extends ConsumerStatefulWidget {
  const KitSearchScreen({super.key});

  @override
  ConsumerState<KitSearchScreen> createState() => _KitSearchScreenState();
}

class _KitSearchScreenState extends ConsumerState<KitSearchScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    RecentSearches.kits.load().then((value) {
      if (mounted) setState(() => _recent = value);
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String text) {
    _query.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  void _open(Medicine package) {
    FocusScope.of(context).unfocus();
    RecentSearches.kits.remember(_query.text).then((value) {
      if (mounted) setState(() => _recent = value);
    });
    context.push(AppRoutes.medicine(package.id));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      extendBody: true,
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: -1,
        searchSelected: true,
        onSearch: _focus.requestFocus,
      ),
      body: SafeArea(
        bottom: false,
        child: AsyncValueView(
          value: ref.watch(appControllerProvider),
          data: _content,
        ),
      ),
    );
  }

  Widget _content(AppState state) {
    final palette = context.palette;
    final now = DateTime.now();
    final warningDays = state.settings.expiryWarningDays;
    final result = searchKits(
      state,
      _query.text,
      now,
      warningDays: warningDays,
    );
    final kitNames = {for (final kit in state.pharmacies) kit.id: kit.name};

    List<Widget> cards(
      List<KitSearchGroup> groups, {
      bool withKit = false,
    }) => [
      for (final group in groups) ...[
        const SizedBox(height: 20),
        _SectionLabel(group.title),
        for (final hit in group.hits) ...[
          const SizedBox(height: 8),
          PackageCard(
            package: hit.package,
            now: now,
            warningDays: warningDays,
            statusNote: hit.ingredient,
            place: withKit ? _kitPlace(kitNames, hit.package) : null,
            onTap: () => _open(hit.package),
          ),
        ],
      ],
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
          children: [
            Semantics(
              header: true,
              child: Text(
                'Поиск',
                style: AppTypography.h1.copyWith(color: palette.textHeading),
              ),
            ),
            const SizedBox(height: 20),
            AppSearchField(
              hint: 'Лекарство во всех аптечках',
              controller: _query,
              focusNode: _focus,
              onChanged: (_) => setState(() {}),
            ),
            ...switch (result) {
              KitSearchIdle() => _idle(),
              KitSearchByName(:final groups, :final missing) => [
                if (missing != null) ...[
                  const SizedBox(height: 20),
                  StatusBanner(
                    tone: StatusBannerTone.info,
                    title: missing.title,
                    text: missing.text,
                  ),
                ],
                ...cards(groups),
              ],
              KitSearchBySymptom(groups: final found) => [
                const SizedBox(height: 20),
                _Hint(
                  'По вашим отметкам «Для чего». Это не замена консультации '
                  'врача — перед приёмом проверьте инструкцию.',
                ),
                ...cards(found, withKit: true),
              ],
              KitSearchNothing() => [
                const SizedBox(height: 12),
                _NothingFound(
                  text: result.text,
                  onFind: result.purpose != null
                      ? null
                      : () => context.push(
                          AppRoutes.medicineSelectQuery(_query.text.trim()),
                        ),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _idle() => [
    if (_recent.isNotEmpty) ...[
      const SizedBox(height: 20),
      const _SectionLabel('Недавние'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final text in _recent)
            AppChip(
              label: text,
              icon: 'search-16',
              tintIcon: true,
              selected: false,
              onTap: () => _setQuery(text),
            ),
        ],
      ),
    ],
    const SizedBox(height: 20),
    const _SectionLabel('Что есть от…'),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (purpose, label) in searchSymptoms)
          AppChip(
            label: label,
            icon: purpose.chipIcon,
            selected: false,
            onTap: () => _setQuery(label),
          ),
      ],
    ),
    const SizedBox(height: 8),
    const _Hint(
      'Ищем по названию и действующему веществу во всех ваших и общих '
      'аптечках.',
    ),
  ];
}

/// «Дом · Ящик стола»: in the search by symptom cards of all kits are mixed.
String _kitPlace(Map<String, String> kitNames, Medicine package) {
  final kit = kitNames[package.pharmacyId];
  final place = package.location.trim();
  return [?kit, if (place.isNotEmpty) place].join(' · ');
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: AppTypography.bodyMedium.copyWith(
        color: context.palette.textSecondary,
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.bodySmall.copyWith(
      color: context.palette.textSecondary,
    ),
  );
}

/// «empty» of 835:9170: white card, title, text and «Найти вручную».
class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.text, required this.onFind});
  final String text;
  final VoidCallback? onFind;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ни в одной аптечке нет',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
          ),
          if (onFind != null) ...[
            const SizedBox(height: 12),
            AppButton(label: 'Найти вручную', onPressed: onFind),
          ],
        ],
      ),
    );
  }
}
