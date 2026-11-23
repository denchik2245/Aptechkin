import 'package:aptechka/core/ui/app_toast.dart';
import 'dart:async';

import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_group.dart';
import 'package:aptechka/features/inventory/presentation/drug_name_field.dart';
import 'package:aptechka/features/inventory/presentation/widgets/catalog_item.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package_form_helpers.dart';

const _entries = [
  DrugCatalogEntry(
    id: 'a',
    gtin: '04603988017259',
    name: 'Лоперамид',
    activeIngredient: 'Лоперамид',
    form: 'Капсулы',
    dosage: '2 мг',
    unit: 'капсул',
    manufacturer: 'АО Обновление',
    packageDescription: '2 x УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт',
    registrationId: 'ЛП-005975',
    registrationStatus: 'Действующий',
  ),
  DrugCatalogEntry(
    id: 'b',
    gtin: '04603988017242',
    name: 'Лоперамид',
    activeIngredient: 'Лоперамид',
    form: 'Капсулы',
    dosage: '2 мг',
    unit: 'капсул',
    manufacturer: 'АО Обновление',
    packageDescription: '2 x УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт',
    registrationId: 'ЛП-005975',
    registrationStatus: 'Действующий',
  ),
  DrugCatalogEntry(
    id: 'c',
    gtin: '04605949000195',
    name: 'Лоперамид',
    activeIngredient: 'Лоперамид',
    form: 'Таблетки',
    dosage: '2 мг',
    unit: 'таблеток',
    manufacturer: 'ЗАО Биоком',
    packageDescription: 'УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт',
    registrationId: 'ЛС-001166',
    registrationStatus: 'Недействующий',
  ),
];

class _Catalog implements DrugCatalogService {
  _Catalog({this.resolver});
  final Future<DrugCatalogEntry?> Function(String)? resolver;
  @override
  String get sourceLabel => 'Тестовый справочник';
  @override
  Future<List<DrugCatalogEntry>> listAll() async => _entries;
  @override
  Future<DrugCatalogEntry?> findByGtin(String gtin) async {
    if (resolver != null) return resolver!(gtin);
    for (final entry in _entries) {
      if (entry.gtin == gtin) return entry;
    }
    return null;
  }

  @override
  Future<List<DrugCatalogEntry>> search(String query, {int limit = 6}) async =>
      _entries.take(limit).toList();
}

void main() {
  // Saving shows «… добавлен в «Дом» · Ещё одно» (894:18224).
  tearDown(hideAppToast);
  final group = DrugCatalogGroup(key: 'лоперамид', entries: _entries);

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    DrugCatalogService? catalog,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        drugCatalogServiceProvider.overrideWithValue(catalog ?? _Catalog()),
      ],
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
    appRouter.push('/medicine/variants?name=лоперамид', extra: group);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final form = PackageFormDriver(tester);
    await form.expiryLater();
    await form.save();
  }

  testWidgets(
    'identical rows are one card; technical codes stay hidden (893:17423)',
    (tester) async {
      await mount(tester);
      expect(find.text('Лоперамид'), findsOneWidget);
      expect(find.text('Выберите, что у вас на упаковке'), findsOneWidget);
      expect(find.text('Все · 2'), findsOneWidget);
      expect(find.text('Капсулы · 1'), findsOneWidget);
      expect(find.text('Таблетки · 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('catalog-entry-b')), findsNothing);
      expect(find.text('Капсулы · 20 шт.'), findsOneWidget);
      expect(find.textContaining('Обновление'), findsOneWidget);
      expect(find.textContaining('GTIN'), findsNothing);
      expect(find.textContaining('ЛП-'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('form chips filter the packages; inactive records say so', (
    tester,
  ) async {
    await mount(tester);
    final tablets = find.byKey(const ValueKey('variant-filter-Таблетки'));
    await tester.ensureVisible(tablets);
    await tester.pumpAndSettle();
    await tester.tap(tablets);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('catalog-entry-a')), findsNothing);
    expect(find.byKey(const ValueKey('catalog-entry-c')), findsOneWidget);
    expect(find.textContaining('запись недействующая'), findsOneWidget);
    await tester.ensureVisible(find.text('Все · 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все · 2'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('catalog-entry-a')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'group selection fills full package quantity without inventing record identity',
    (tester) async {
      final container = await mount(tester);
      await reveal(tester, find.byKey(const ValueKey('catalog-entry-a')));
      await tester.tap(find.byKey(const ValueKey('catalog-entry-a')));
      await tester.pumpAndSettle();
      await save(tester);
      final added = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .last;
      expect(added.gtin, isNull);
      expect(added.catalogEntryId, isNull);
      expect(added.manufacturer, 'АО Обновление');
      expect(added.packageDescription, _entries.first.packageDescription);
      expect(added.registrationId, 'ЛП-005975');
      expect(added.quantity, 20);
      expect(added.expiryDate, isNull);
      expect(find.text('Где лежит'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'group selection restores from URL without choosing the first GTIN',
    (tester) async {
      final container = await mount(tester);
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.push('/medicine/new?candidates=04603988017259,04603988017242');
      await tester.pumpAndSettle();
      await save(tester);
      final added = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .last;
      expect(added.name, 'Лоперамид');
      expect(added.catalogEntryId, isNull);
      expect(added.gtin, isNull);
      expect(added.quantity, 20);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scanner result assigns exact identity and GTIN, including a grouped member',
    (tester) async {
      final container = await mount(tester);
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.push('/medicine/new?scanned=04603988017242');
      await tester.pumpAndSettle();
      await save(tester);
      final added = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .last;
      expect(added.catalogEntryId, 'b');
      expect(added.gtin, '04603988017242');
      expect(added.quantity, 20);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late scan lookup cannot replace manual name or scanned identity',
    (tester) async {
      final response = Completer<DrugCatalogEntry?>();
      await mount(tester, catalog: _Catalog(resolver: (_) => response.future));
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.push('/medicine/new?scanned=04603988017242');
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('drug-name-input')));
      await tester.enterText(
        find.byKey(const ValueKey('drug-name-input')),
        'Другой',
      );
      response.complete(_entries[1]);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('drug-name-input')),
            )
            .controller!
            .text,
        'Другой',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manual escape retains only the name', (tester) async {
    await mount(tester);
    final manual = find.text('Нет в справочнике? Заполнить вручную');
    await reveal(tester, manual);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('drug-name-input')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('drug-name-input')))
          .controller!
          .text,
      'Лоперамид',
    );
    await reveal(tester, find.byKey(const ValueKey('drug-dosage-input')));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('drug-dosage-input')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  for (final edited in [false, true]) {
    testWidgets(
      'inline selection updates automatic quantity and preserves manual input: $edited',
      (tester) async {
        final container = await mount(tester);
        appRouter.pop();
        await tester.pumpAndSettle();
        appRouter.push('/medicine/new', extra: _entries.first);
        await tester.pumpAndSettle();
        final form = PackageFormDriver(tester);
        expect(await form.quantity(), '20 капсул');
        if (edited) await form.minus(13);
        await form.tap(find.text('Изменить'));
        await form.enter('drug-name-input', 'Лоперами');
        final choice = find
            .descendant(
              of: find.byType(DrugNameField),
              matching: find.byType(CatalogListItem),
            )
            .last;
        await form.tap(choice);
        expect(await form.quantity(), edited ? '7 таблеток' : '10 таблеток');
        await save(tester);
        final added = container
            .read(appControllerProvider)
            .requireValue
            .medicines
            .last;
        expect(added.quantity, edited ? 7 : 10);
        expect(added.unit, 'таблеток');
        expect(added.catalogEntryId, 'c');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'late catalog load keeps quantity explicitly edited before it resolves',
    (tester) async {
      final response = Completer<DrugCatalogEntry?>();
      final container = await mount(
        tester,
        catalog: _Catalog(resolver: (_) => response.future),
      );
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.push('/medicine/new?scanned=04603988017242');
      await tester.pumpAndSettle();
      final form = PackageFormDriver(tester);
      await form.plus();
      await form.minus();
      response.complete(_entries[1]);
      await tester.pumpAndSettle();
      expect(await form.quantity(), '1 капсула');
      await save(tester);
      expect(
        container
            .read(appControllerProvider)
            .requireValue
            .medicines
            .last
            .quantity,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown package count and mismatched units are not filled from dosage or volume',
    (tester) async {
      await mount(tester);
      appRouter.pop();
      await tester.pumpAndSettle();
      for (final entry in [
        const DrugCatalogEntry(
          id: 'unknown',
          name: 'Препарат',
          activeIngredient: '',
          form: 'Таблетки',
          dosage: '500 мг',
          unit: 'таблеток',
          packageDescription: 'ФЛАКОН по 10.000 мл',
        ),
        const DrugCatalogEntry(
          id: 'unit',
          name: 'Препарат',
          activeIngredient: '',
          form: 'Капсулы',
          dosage: '2 мг',
          unit: 'мл',
          packageDescription: '2 x УПАКОВКА ЯЧЕЙКОВАЯ КОНТУРНАЯ по 10 шт',
        ),
      ]) {
        appRouter.push('/medicine/new', extra: entry);
        await tester.pumpAndSettle();
        expect(await PackageFormDriver(tester).quantity(), startsWith('1 '));
        appRouter.pop();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing the name clears automatic package count', (
    tester,
  ) async {
    await mount(tester);
    appRouter.pop();
    await tester.pumpAndSettle();
    appRouter.push('/medicine/new', extra: _entries.first);
    await tester.pumpAndSettle();
    final form = PackageFormDriver(tester);
    expect(await form.quantity(), '20 капсул');
    await form.tap(find.text('Изменить'));
    await form.enter('drug-name-input', 'Другой препарат');
    expect(await form.quantity(), '1 шт.');
    expect(tester.takeException(), isNull);
  });
}
