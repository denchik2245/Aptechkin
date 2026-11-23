import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/theme/app_theme.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/inventory/domain/quick_add.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/scanner/application/add_batch.dart';
import 'package:aptechka/features/scanner/domain/scanned_code.dart';
import 'package:aptechka/features/scanner/presentation/quick_add_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../inventory/package_form_helpers.dart';

void main() {
  const tablets = DrugCatalogEntry(
    id: 'mdlp:04600000000077',
    gtin: '04600000000077',
    name: 'АМБРОКСОЛ',
    activeIngredient: 'АМБРОКСОЛ',
    form: 'ТАБЛЕТКИ',
    dosage: '30 мг',
    unit: 'таблеток',
    packageDescription: '2 x БЛИСТЕР по 10 шт',
  );
  const syrup = DrugCatalogEntry(
    id: 'syrup',
    name: 'Нурофен для детей',
    activeIngredient: 'Ибупрофен',
    form: 'Суспензия для приёма внутрь',
    dosage: '100 мг/5 мл',
    unit: 'мл',
    packageDescription: 'ФЛАКОН по 100.000 мл',
  );
  const device = DrugCatalogEntry(
    id: 'device',
    name: 'Термометр',
    activeIngredient: '',
    form: 'Прибор',
    dosage: '',
    unit: 'шт.',
  );

  group('quick add rules (890:15548)', () {
    test('stock as the form gives it by default', () {
      final pills = quickStockFor(tablets);
      expect(pills.quantity, 20);
      expect(pills.unit, 'таблеток');
      expect(pills.tracksStock, isTrue);
      expect(pills.stockLevel, isNull);
      final bottle = quickStockFor(syrup);
      expect(bottle.unit, 'флакон');
      expect(bottle.stockLevel, StockLevel.full);
      final thermometer = quickStockFor(device);
      expect(thermometer.tracksStock, isFalse);
    });

    test('source line and the place picked first', () {
      expect(
        quickSourceLine(
          ScannedCode(
            gtin: '1',
            kind: ScanKind.dataMatrix,
            expiry: DateTime(2027, 5, 31),
          ),
        ),
        'Срок до мая 2027 — из кода',
      );
      expect(
        quickSourceLine(const ScannedCode(gtin: '1', kind: ScanKind.barcode)),
        'Найдено по штрихкоду',
      );
      expect(quickDefaultPlace(['Холодильник', 'Полка'], 'Полка'), 'Полка');
      expect(
        quickDefaultPlace(['Холодильник', 'Полка'], 'Ящик'),
        'Холодильник',
      );
      expect(quickDefaultPlace([], null), isNull);
    });

    test('summary counts the packages and the missing dates', () {
      Medicine package(String id, {DateTime? expiry}) => Medicine(
        id: id,
        pharmacyId: 'home',
        name: 'Смекта',
        form: 'Порошок',
        dosage: '3 г',
        quantity: 10,
        unit: 'пакетиков',
        location: 'Верхняя полка',
        expiryDate: expiry,
      );
      final state = AppState(
        pharmacies: const [
          Pharmacy(
            id: 'home',
            name: 'Дом',
            ownerLabel: 'Вы',
            isShared: false,
            canEdit: true,
          ),
        ],
        selectedPharmacyId: 'home',
        medicines: [
          package('a', expiry: DateTime(2027, 5, 31)),
          package('b'),
          package('c', expiry: DateTime(2028, 1, 31)),
        ],
        reminders: const [],
        intakeRecords: const [],
      );
      final summary = batchSummary(state, ['a', 'b', 'gone', 'c']);
      expect(summary.packages.map((m) => m.id), ['a', 'b', 'c']);
      expect(summary.title, '3 упаковки добавлено в «Дом»');
      expect(
        summary.text,
        'У одной не указан срок — её отметили, чтобы вернуться позже',
      );
      final one = batchSummary(state, ['a']);
      expect(one.title, '1 упаковка добавлена в «Дом»');
      expect(one.text, isNull);
    });
  });

  group('quick card', () {
    Future<List<QuickAddPick>> pumpCard(
      WidgetTester tester,
      ScannedCode code,
    ) async {
      final picks = <QuickAddPick>[];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: QuickAddCard(
                  entry: tablets,
                  code: code,
                  kitName: 'Дом',
                  places: const ['Холодильник', 'Верхняя полка', 'Ящик стола'],
                  initialPlace: 'Холодильник',
                  onDetails: () {},
                  onSkip: () {},
                  onAdd: picks.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return picks;
    }

    testWidgets('a DataMatrix date is enough to add', (tester) async {
      final picks = await pumpCard(
        tester,
        ScannedCode(
          gtin: '04600000000077',
          kind: ScanKind.dataMatrix,
          expiry: DateTime(2027, 5, 31),
        ),
      );
      expect(find.text('Амброксол, 30 мг'), findsOneWidget);
      expect(find.text('Срок до мая 2027 — из кода'), findsOneWidget);
      expect(find.text('Подробнее'), findsOneWidget);
      expect(find.text('Положить в «Дом»'), findsOneWidget);
      expect(find.text('Срок годности *'), findsNothing);
      await tester.tap(find.text('Верхняя полка'));
      await tester.pump();
      await tester.tap(find.text('Добавить'));
      expect(picks.single.place, 'Верхняя полка');
      expect(picks.single.expiry, DateTime(2027, 5, 31));
    });

    testWidgets('a plain barcode waits for the date', (tester) async {
      final picks = await pumpCard(
        tester,
        const ScannedCode(gtin: '04600000000077', kind: ScanKind.barcode),
      );
      expect(find.text('Найдено по штрихкоду'), findsOneWidget);
      expect(find.text('Срок годности *'), findsOneWidget);
      await tester.tap(find.text('Добавить'));
      expect(picks, isEmpty);
    });
  });

  group('batch screens', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<ProviderContainer> mount(
      WidgetTester tester,
      String location, {
      Object? extra,
    }) async {
      final container = ProviderContainer(
        overrides: [
          drugCatalogServiceProvider.overrideWithValue(
            const DemoDrugCatalogService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      appRouter.go(AppRoutes.inventory);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AptechkaApp(),
        ),
      );
      await tester.pumpAndSettle();
      appRouter.push(location, extra: extra);
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('the form from «Подробнее» saves into the batch', (
      tester,
    ) async {
      final container = await mount(
        tester,
        '${AppRoutes.medicineNew}?batch=1',
        extra: tablets,
      );
      final form = PackageFormDriver(tester);
      expect(find.text('Сохранить и добавить ещё'), findsNothing);
      await form.expiryLater();
      await form.save();
      final added = container.read(addBatchProvider);
      final saved = container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .last;
      expect(added, [saved.id]);
      expect(find.text('Новая упаковка'), findsNothing);
    });

    testWidgets('«Сохранить и добавить ещё» starts a batch', (tester) async {
      final container = await mount(
        tester,
        AppRoutes.medicineNew,
        extra: tablets,
      );
      final form = PackageFormDriver(tester);
      await form.expiryLater();
      await form.tap(find.text('Сохранить и добавить ещё'));
      expect(container.read(addBatchProvider), hasLength(1));
      expect(
        appRouter.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.scanner,
      );
      expect(find.text('Несколько подряд'), findsOneWidget);
      expect(find.text('Добавлено 1'), findsOneWidget);
    });

    testWidgets('summary lists the batch and «Готово» clears it', (
      tester,
    ) async {
      final container = await mount(tester, AppRoutes.inventory);
      final state = container.read(appControllerProvider).requireValue;
      final ids = state.medicines
          .where((m) => m.pharmacyId == state.selectedPharmacyId)
          .take(2)
          .map((m) => m.id)
          .toList();
      for (final id in ids) {
        container.read(addBatchProvider.notifier).add(id);
      }
      appRouter.push(AppRoutes.addSummary);
      await tester.pumpAndSettle();
      expect(find.text('Добавлено 2'), findsOneWidget);
      expect(find.textContaining('2 упаковки добавлено в'), findsOneWidget);
      expect(find.text('Сканировать ещё'), findsOneWidget);
      await tester.ensureVisible(find.text('Готово'));
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(container.read(addBatchProvider), isEmpty);
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        AppRoutes.inventory,
      );
    });
  });
}
