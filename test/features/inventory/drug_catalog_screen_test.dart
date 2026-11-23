import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/core/ui/app_chip.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:aptechka/features/inventory/data/recent_searches.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_search.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package_form_helpers.dart';

/// «Добавление · 4 · Поиск по названию» (890:15549).
void main() {
  // Saving shows «… добавлен в «Дом» · Ещё одно» (894:18224).
  tearDown(hideAppToast);
  // The vertical list of the screen on top (the field scrolls sideways).
  final list = find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .last;
  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      target,
      150,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    DrugCatalogService catalog = const DemoDrugCatalogService(),
    Map<String, Object> preferences = const {},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    final container = ProviderContainer(
      overrides: [drugCatalogServiceProvider.overrideWithValue(catalog)],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .updateSettings(
          const AppSettings(appearance: AppAppearance.dark, textScale: 1.3),
        );
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go('/inventory');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    // «+» opens the camera; the catalog is the «Найти по названию» path.
    appRouter.push('/medicine/select');
    await tester.pumpAndSettle();
    return container;
  }

  final input = find.byKey(const ValueKey('catalog-name-input'));

  group('rules', () {
    late List<IndexedDrugGroup> groups;
    setUpAll(() async {
      groups = indexDrugGroups(await const DemoDrugCatalogService().listAll());
    });

    test('name first, then other names with the ingredient', () {
      final result = searchDrugGroups(groups, 'ибупро');
      expect(result.byName.map((g) => g.name), ['Ибупрофен']);
      expect(result.byIngredient.map((g) => g.name), [
        'Нурофен',
        'Нурофен Форте',
        'Нурофен Экспресс',
        'Нурофен Экспресс Форте',
      ]);
      expect(result.ingredient, 'ибупрофен');
      expect(drugGroupDetails(result.byName.single), 'Таблетки · 2 варианта');
    });

    test('a typo gives similar names; nothing gives an empty result', () {
      final typo = searchDrugGroups(groups, 'нурафен');
      expect(typo.byName, isEmpty);
      expect(typo.similar.first.name, 'Нурофен');
      expect(searchDrugGroups(groups, 'кардиомагнил форте').isEmpty, isTrue);
      expect(searchDrugGroups(groups, '').isEmpty, isTrue);
    });

    test('titles and recent searches', () {
      final loratadine = searchDrugGroups(groups, 'лора').byName.single;
      expect(drugGroupTitle(loratadine), 'Лоратадин, 10 мг');
      expect(shortDrugForm('ТАБЛЕТКИ, ПОКРЫТЫЕ ОБОЛОЧКОЙ'), 'Таблетки');
      expect(rememberRecent(['Смекта', 'Називин'], 'називин'), [
        'називин',
        'Смекта',
      ]);
      expect(rememberRecent(['1', '2', '3', '4', '5'], '6'), [
        '6',
        '1',
        '2',
        '3',
        '4',
      ]);
    });
  });

  testWidgets('start: names the user keeps and recent searches', (
    tester,
  ) async {
    await mount(
      tester,
      preferences: {
        'flutter.aptechka_recent_drug_searches_v1': ['Смекта', 'Називин'],
      },
    );
    expect(find.text('Найти по названию'), findsOneWidget);
    expect(find.text('Недавние'), findsOneWidget);
    expect(find.text('Смекта'), findsOneWidget);
    expect(find.text('Часто добавляют'), findsOneWidget);
    expect(find.text('Ибупрофен'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Нет в справочнике? Заполнить вручную'),
      150,
      scrollable: list,
    );
    await tester.scrollUntilVisible(
      find.text('Смекта'),
      -150,
      scrollable: list,
    );
    await tester.tap(find.text('Смекта'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, 'Смекта');
    expect(find.text('Не нашли в справочнике'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('results by name and by ingredient; opening is remembered', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(input, 'ибупро');
    await tester.pumpAndSettle();
    expect(find.text('По названию'), findsOneWidget);
    expect(find.text('Содержат ибупрофен'), findsOneWidget);
    await tapKey(tester, 'catalog-group-ибупрофен');
    expect(find.text('Выберите, что у вас на упаковке'), findsOneWidget);
    expect(find.text('Ибупрофен, 200 мг'), findsOneWidget);
    expect(find.text('Ибупрофен, 400 мг'), findsOneWidget);
    appRouter.pop();
    await tester.pumpAndSettle();
    expect(await RecentSearches.drugs.load(), ['Ибупрофен']);
    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Недавние'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typos suggest the name without choosing it', (tester) async {
    await mount(tester);
    await tester.enterText(input, 'нурафен');
    await tester.pumpAndSettle();
    expect(find.text('Возможно, вы искали'), findsOneWidget);
    expect(find.text('Похожие'), findsOneWidget);
    expect(find.text('Новая упаковка'), findsNothing);
    expect(tester.widget<TextField>(input).controller!.text, 'нурафен');
    await tester.tap(
      find.descendant(of: find.byType(AppChip), matching: find.text('Нурофен')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, 'Нурофен');
    expect(find.text('По названию'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected variant fills form and saving opens the new card without assigning a scanned GTIN',
    (tester) async {
      final container = await mount(tester);
      final before = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .length;
      await tester.enterText(input, 'Л');
      await tester.pumpAndSettle();
      await tapKey(tester, 'catalog-group-лоратадин');
      await tapKey(tester, 'catalog-entry-demo-loratadine-10-tablets');
      final form = PackageFormDriver(tester);
      await form.expectShown(find.text('Лоратадин, 10 мг'));
      await form.expiryLater();
      await form.save();
      expect(find.text('Где лежит'), findsOneWidget);
      final medicines = container
          .read(appControllerProvider)
          .requireValue
          .medicines;
      expect(medicines, hasLength(before + 1));
      final added = medicines.last;
      expect(added.catalogEntryId, 'demo-loratadine-10-tablets');
      expect(added.gtin, isNull);
      expect(added.expiryDate, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('nothing found offers the manual form', (tester) async {
    await mount(tester);
    await tester.enterText(input, 'кардиомагнил форте');
    await tester.pumpAndSettle();
    expect(find.text('Не нашли в справочнике'), findsOneWidget);
    await tester.tap(find.text('Заполнить вручную'));
    await tester.pumpAndSettle();
    expect(find.text('Новая упаковка'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed catalog can retry and manual form remains available', (
    tester,
  ) async {
    var calls = 0;
    final catalog = MdlpDrugCatalogService(
      loadAsset: () async {
        calls++;
        throw StateError('offline');
      },
    );
    await mount(tester, catalog: catalog);
    expect(find.text('Справочник недоступен'), findsOneWidget);
    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.tap(find.text('Нет в справочнике? Заполнить вручную'));
    await tester.pumpAndSettle();
    expect(find.text('Новая упаковка'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('drug-name-input')))
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
