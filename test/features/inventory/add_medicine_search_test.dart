import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/data/mdlp_drug_catalog_service.dart';
import 'package:aptechka/features/inventory/domain/package_form.dart';
import 'package:aptechka/features/inventory/presentation/drug_name_field.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/settings/domain/backup_codec.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package_form_helpers.dart';

void main() {
  // Saving shows «… добавлен в «Дом» · Ещё одно» (894:18224).
  tearDown(hideAppToast);
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    DrugCatalogService catalog = const DemoDrugCatalogService(),
  }) async {
    SharedPreferences.setMockInitialValues({});
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
    appRouter.push('/medicine/new');
    await tester.pumpAndSettle();
    return container;
  }

  Medicine lastSaved(ProviderContainer container) =>
      container.read(appControllerProvider).requireValue.medicines.last;

  Future<void> choose(PackageFormDriver form, String name) async {
    final option = find.descendant(
      of: find.byType(DrugNameField),
      // Suggestions read «Название, доза».
      matching: find.textContaining('$name,'),
    );
    await form.tap(option);
  }

  testWidgets(
    'readable prefill saves original catalog identity and displays saved text normally',
    (tester) async {
      final container = await mount(tester);
      final form = PackageFormDriver(tester);
      const entry = DrugCatalogEntry(
        id: 'uppercase',
        name: 'ПРЕПАРАТ',
        activeIngredient: 'ФЛУОЦИНОЛОНА АЦЕТОНИД',
        form: 'ТАБЛЕТКИ, ПОКРЫТЫЕ ОБОЛОЧКОЙ',
        dosage: '500 МЕ',
        unit: 'таблеток',
        manufacturer: 'АО ВЕРТЕКС',
        packageDescription: 'УПАКОВКА по 10 шт',
        registrationId: 'ЛП-002969',
      );
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.push('/medicine/new', extra: entry);
      await tester.pumpAndSettle();
      // «catalog item» instead of the manual fields.
      await form.expectShown(find.text('Препарат, 500 МЕ'));
      expect(
        find.text('Таблетки, покрытые оболочкой · 10 шт. в упаковке'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('drug-name-input')), findsNothing);
      expect(find.text('Заполните сами'), findsNothing);
      expect(await form.quantity(), '10 таблеток');
      expect(find.text('целая упаковка'), findsOneWidget);
      await form.expiryLater();
      await form.save();
      final medicine = lastSaved(container);
      expect(medicine.catalogEntryId, entry.id);
      expect(medicine.name, entry.name);
      expect(medicine.activeIngredient, entry.activeIngredient);
      expect(medicine.form, entry.form);
      expect(medicine.manufacturer, entry.manufacturer);
      expect(medicine.packageDescription, entry.packageDescription);
      expect(medicine.registrationId, entry.registrationId);
      expect(medicine.dosage, '500 МЕ');
      expect(medicine.quantity, 10);
      expect(medicine.unit, 'таблеток');
      expect(medicine.expiryDate, isNull);
      expect(medicine.noExpiry, isFalse);
      // The new package's card opens (894:18224).
      expect(find.text('Препарат, 500 МЕ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected capsule variant fills fields and saves without guessing package data',
    (tester) async {
      final container = await mount(tester);
      final form = PackageFormDriver(tester);
      expect(find.text('Заполните сами'), findsOneWidget);
      await form.plus(6);
      expect(await form.quantity(), '7 шт.');
      await form.enter('drug-name-input', 'нурофен капсулы 400');
      await choose(form, 'Нурофен Экспресс Форте');
      await form.expectShown(find.text('Нурофен Экспресс Форте, 400 мг'));
      expect(find.text('Заполните сами'), findsNothing);
      // The amount the user set survives the catalog fill.
      expect(await form.quantity(), '7 капсул');
      await form.addPlace('Бардачок');
      await form.expiryLater();
      await form.save();
      final medicine = lastSaved(container);
      expect(medicine.name, 'Нурофен Экспресс Форте');
      expect(medicine.activeIngredient, 'Ибупрофен');
      expect(medicine.form, 'Капсулы');
      expect(medicine.dosage, '400 мг');
      expect(medicine.unit, 'капсул');
      expect(medicine.quantity, 7);
      expect(medicine.location, 'Бардачок');
      expect(medicine.expiryDate, isNull);
      expect(medicine.gtin, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real catalog retains source details and an unknown dose through save and backup',
    (tester) async {
      final catalog = MdlpDrugCatalogService();
      // Asset IO/isolate parsing run outside the fake widget-test clock.
      await tester.runAsync(() => catalog.search('гомеовокс'));
      final container = await mount(tester, catalog: catalog);
      final form = PackageFormDriver(tester);
      await form.enter('drug-name-input', 'гомеовокс');
      await form.tap(
        find.descendant(
          of: find.byType(DrugNameField),
          matching: find.text('Гомеовокс'),
        ),
      );
      await form.expiryLater();
      await form.save();
      final state = container.read(appControllerProvider).requireValue;
      final medicine = state.medicines.last;
      expect(medicine.name, 'Гомеовокс');
      expect(medicine.dosage, isEmpty);
      expect(medicine.dosageLabel, 'Дозировка не указана');
      expect(medicine.catalogEntryId, startsWith('mdlp:'));
      expect(medicine.manufacturer, isNotEmpty);
      expect(medicine.packageDescription, isNotEmpty);
      expect(medicine.catalogVersion, '2026-10-01');
      expect(medicine.gtin, isNull);
      final restored = BackupCodec.decode(BackupCodec.encode(state))
          .medicines
          .last;
      expect(restored.toJson(), medicine.toJson());
      expect(
        restored.copyWith(quantity: 2).manufacturer,
        medicine.manufacturer,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing a chosen name removes stale autofill and allows manual save',
    (tester) async {
      final container = await mount(tester);
      final form = PackageFormDriver(tester);
      await form.enter('drug-name-input', 'лора');
      await choose(form, 'Лоратадин');
      await form.tap(find.text('Изменить'));
      expect(await form.text('drug-name-input'), 'Лоратадин');
      await form.enter('drug-name-input', 'Свой препарат');
      await form.expectShown(find.text('Совпадений не найдено'));
      await form.tap(find.text('Заполнить вручную'));
      expect(await form.text('drug-dosage-input'), isEmpty);
      await form.expectShown(find.text('Заполните сами'));
      await form.enter('drug-dosage-input', 'по упаковке');
      await form.chooseForm('Таблетки, капсулы');
      await form.expiryLater();
      await form.save();
      final medicine = lastSaved(container);
      expect(medicine.name, 'Свой препарат');
      expect(medicine.activeIngredient, isNull);
      expect(medicine.dosage, 'по упаковке');
      expect(medicine.form, 'Таблетки');
      expect(medicine.unit, 'таблеток');
      expect(medicine.catalogEntryId, isNull);
      expect(medicine.gtin, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty form shows the errors of «Ошибки заполнения»', (
    tester,
  ) async {
    final container = await mount(tester);
    final form = PackageFormDriver(tester);
    final before = container
        .read(appControllerProvider)
        .requireValue
        .medicines
        .length;
    await form.save();
    await form.reveal(find.text('Введите название с упаковки'));
    expect(
      find.text('Выберите форму — от неё зависит, как считать остаток'),
      findsOneWidget,
    );
    await form.reveal(find.text('Укажите срок или выберите «Укажу позже»'));
    expect(
      container.read(appControllerProvider).requireValue.medicines.length,
      before,
    );
    // «Укажу позже» hides the month field and its error.
    await form.expiryLater();
    expect(find.text('Укажите срок или выберите «Укажу позже»'), findsNothing);
    await form.expectShown(
      find.text('Напомним указать срок. В карточке будет «Срок не указан»'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('syrup is counted by level and remembers the opening', (
    tester,
  ) async {
    final container = await mount(tester);
    final form = PackageFormDriver(tester);
    await form.enter('drug-name-input', 'Сироп от кашля');
    await form.chooseForm('Сироп, суспензия, раствор');
    expect(find.text('Полный'), findsOneWidget);
    expect(find.text('новый флакон'), findsOneWidget);
    await form.tap(find.text('Уже начата'));
    expect(find.text('Больше половины'), findsOneWidget);
    await form.tap(find.byKey(const ValueKey('package-expiry-input')));
    await form.tapInSheet('Готово');
    final now = DateTime.now();
    final expiry = DateTime(now.year + 1, now.month);
    expect(find.text(monthYearLabel(expiry)), findsOneWidget);
    await form.tap(find.text('Флакон уже вскрыт'));
    await form.reveal(find.text(compactDate(now)));
    await form.tap(find.text('Срок после вскрытия'));
    await form.tapInSheet('6 месяцев');
    await form.tapInSheet('Готово');
    await form.save();
    final medicine = lastSaved(container);
    expect(medicine.name, 'Сироп от кашля');
    expect(medicine.form, 'Сироп');
    expect(medicine.unit, 'флакон');
    expect(medicine.quantity, 1);
    expect(medicine.stockLevel, StockLevel.moreThanHalf);
    expect(medicine.expiryDate, endOfMonth(expiry.year, expiry.month));
    expect(medicine.openedAt, isNotNull);
    expect(medicine.afterOpeningDays, 180);
    expect(tester.takeException(), isNull);
  });

  testWidgets('device has no stock count and no expiry', (tester) async {
    final container = await mount(tester);
    final form = PackageFormDriver(tester);
    await form.enter('drug-name-input', 'Термометр');
    await form.chooseForm('Прибор');
    expect(find.text('Остаток'), findsOneWidget);
    expect(find.text('Считать остаток'), findsOneWidget);
    expect(find.text('Уже начата'), findsNothing);
    await form.tap(find.text('Без срока годности'));
    expect(find.byKey(const ValueKey('package-expiry-input')), findsNothing);
    await form.save();
    final medicine = lastSaved(container);
    expect(medicine.tracksStock, isFalse);
    expect(medicine.noExpiry, isTrue);
    expect(medicine.statusAt(DateTime.now()), MedicineStatus.okay);
    expect(tester.takeException(), isNull);
  });
}
