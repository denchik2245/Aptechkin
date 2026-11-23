import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/core/ui/radio_row.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/package_form.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package_form_helpers.dart';

/// «Добавление · 5 · Выбор значений и выход» (890:15550).
void main() {
  tearDown(hideAppToast);

  Future<ProviderContainer> pumpApp(WidgetTester tester, String path) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go(AppRoutes.inventory);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.push(path);
    await tester.pumpAndSettle();
    return container;
  }

  Medicine package(ProviderContainer container, String id) => container
      .read(appControllerProvider)
      .requireValue
      .medicines
      .firstWhere((item) => item.id == id);

  Finder inSheet(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  testWidgets('form sheet is a radio row group with the caption', (
    tester,
  ) async {
    await pumpApp(tester, AppRoutes.medicineNew);
    final form = PackageFormDriver(tester);
    await form.tap(find.byKey(const ValueKey('drug-form-input')));
    expect(find.byType(RadioRow), findsNWidgets(10));
    expect(
      find.text('От формы зависит, как считать остаток: штуками или примерно'),
      findsOneWidget,
    );
    await form.tapInSheet('Капли');
    expect(find.text('Капли'), findsOneWidget);
  });

  testWidgets('picker sheets: subtitle headers, several purposes, kit', (
    tester,
  ) async {
    await pumpApp(tester, AppRoutes.medicineNew);
    final form = PackageFormDriver(tester);

    await form.tap(find.byKey(const ValueKey('package-expiry-input')));
    expect(inSheet('На упаковке он подписан «Годен до» или EXP'), findsOneWidget);
    expect(find.byTooltip('Закрыть'), findsOneWidget); // only the form's ×
    // A tap on a row of the flat wheel selects it.
    final now = DateTime.now();
    await form.tapInSheet('${now.year + 2}');
    await form.tapInSheet('Готово');
    await form.expectShown(
      find.text(monthYearLabel(DateTime(now.year + 2, now.month))),
    );

    await form.tap(find.text('Для чего'));
    expect(
      inSheet(
        'Можно выбрать несколько — по ним удобно искать, когда что-то болит',
      ),
      findsOneWidget,
    );
    for (final label in ['Боль в горле', 'Давление', 'Витамины', 'Другое']) {
      expect(inSheet(label), findsOneWidget);
    }
    await form.tapInSheet('Температура');
    await form.tapInSheet('Головная боль');
    await tester.enterText(
      find.byKey(const ValueKey('purpose-custom-input')),
      'Ушибы',
    );
    await tester.pumpAndSettle();
    await form.tapInSheet('Готово');
    await form.expectShown(find.text('Температура, Головная боль, Ушибы'));

    // «В какую аптечку»: a tap only selects, «Готово» confirms.
    await form.tap(find.byKey(const ValueKey('package-kit-input')));
    await form.tapInSheet('Аптечка мамы');
    expect(find.byType(BottomSheet), findsOneWidget);
    await form.tapInSheet('Готово');
    await form.expectShown(find.text('Аптечка мамы'));

    await form.tap(find.text('+ Новое место'));
    expect(
      inSheet('Появится в аптечке «Аптечка мамы» и в фильтре по местам'),
      findsOneWidget,
    );
    expect(inSheet('Добавить место'), findsOneWidget);
  });

  testWidgets('a new package opens its card with «Ещё одно»', (tester) async {
    final container = await pumpApp(tester, AppRoutes.medicineNew);
    final form = PackageFormDriver(tester);
    await form.enter('drug-name-input', 'Ибупрофен');
    await form.chooseForm('Таблетки, капсулы');
    await form.expiryLater();
    await form.tap(find.byKey(const ValueKey('package-save')));
    expect(find.text('Ибупрофен добавлен в «Дом»'), findsOneWidget);
    expect(find.text('Ещё одно'), findsOneWidget);
    expect(find.text('Где лежит'), findsOneWidget);
    final added = container
        .read(appControllerProvider)
        .requireValue
        .medicines
        .last;
    expect(appRouter.state.uri.path, AppRoutes.medicine(added.id));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('pencil edits the package; leaving with changes asks first', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      AppRoutes.medicine('ibuprofen-demo'),
    );
    final before = package(container, 'ibuprofen-demo');
    await tester.tap(find.byTooltip('Изменить'));
    await tester.pumpAndSettle();
    expect(find.text('Изменить упаковку'), findsOneWidget);
    final form = PackageFormDriver(tester);
    expect(await form.quantity(), '14 таблеток');
    await form.expectShown(find.text('Сохранить изменения'));
    expect(find.text('Убрать из аптечки'), findsOneWidget);

    // No change: × leaves at once.
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Изменить упаковку'), findsNothing);

    await tester.tap(find.byTooltip('Изменить'));
    await tester.pumpAndSettle();
    await form.minus(2);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти без сохранения?'), findsOneWidget);
    expect(find.text('Изменения не сохранятся'), findsOneWidget);
    await tester.tap(find.text('Остаться'));
    await tester.pumpAndSettle();

    await form.tap(find.text('Для чего'));
    await form.tapInSheet('Температура');
    await form.tapInSheet('Готово');
    await form.tap(find.text('Сохранить изменения'));
    expect(find.text('Изменить упаковку'), findsNothing);
    final after = package(container, 'ibuprofen-demo');
    expect(after.quantity, before.quantity - 2);
    expect(after.purposes, [MedicinePurpose.fever]);
    expect(after.name, before.name);
    expect(after.expiryDate, before.expiryDate);
    expect(after.addedAt, before.addedAt);
    expect(find.text('Температура'), findsWidgets);
  });

  testWidgets('«Убрать из аптечки» on the edit form opens the removal', (
    tester,
  ) async {
    await pumpApp(tester, AppRoutes.medicine('ibuprofen-demo'));
    await tester.tap(find.byTooltip('Изменить'));
    await tester.pumpAndSettle();
    final form = PackageFormDriver(tester);
    await form.tap(find.text('Убрать из аптечки'));
    expect(find.text('Убрать Ибупрофен?'), findsOneWidget);
  });
}
