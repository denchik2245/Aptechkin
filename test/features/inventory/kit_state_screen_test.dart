import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/presentation/kit_state_screen.dart';
import 'package:aptechka/features/inventory/presentation/widgets/category_row.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_card.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> pumpApp(
    WidgetTester tester,
    String path, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    final controller = container.read(appControllerProvider.notifier);
    await controller.updateSettings(AppSettings(textScale: textScale));
    // Demo «Дом»: usable ibuprofen and drops, expired ibuprofen → enough;
    // loratadine in «Дом» and «Аптечка мамы» → low.
    await controller.setPurposes('ibuprofen-demo', [MedicinePurpose.fever]);
    await controller.setPurposes('ibuprofen-old-demo', [MedicinePurpose.fever]);
    await controller.setPurposes('drops-demo', [MedicinePurpose.headache]);
    final loratadine = container
        .read(appControllerProvider)
        .requireValue
        .medicines
        .where((item) => item.name == 'Лоратадин');
    for (final item in loratadine) {
      await controller.setPurposes(item.id, [MedicinePurpose.allergy]);
    }
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go(AppRoutes.inventory);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (path != AppRoutes.inventory) {
      appRouter.push(path);
      await tester.pumpAndSettle();
    }
    return container;
  }

  testWidgets('kit menu opens «Состояние аптечки»', (tester) async {
    await pumpApp(tester, AppRoutes.inventory);
    await tester.tap(find.byTooltip('Меню аптечки'));
    await tester.pumpAndSettle();
    expect(find.text('Состояние аптечки'), findsOneWidget);
    expect(find.text('В 7 категориях лекарств нет или мало'), findsOneWidget);
    await tester.tap(find.text('Состояние аптечки'));
    await tester.pumpAndSettle();
    expect(find.byType(KitStateScreen), findsOneWidget);
  });

  testWidgets('categories, low category and empty category', (tester) async {
    await pumpApp(tester, AppRoutes.kitState('home'));
    expect(find.text('«Дом» по категориям'), findsOneWidget);
    expect(find.text('Нет или мало'), findsOneWidget);
    expect(find.text('1 упаковка'), findsOneWidget);
    expect(find.byType(CategoryRow), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Температура и боль'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Достаточно'), findsNWidgets(2)); // label and pill
    expect(find.text('2 упаковки'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Аллергия'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Аллергия'));
    await tester.pumpAndSettle();
    expect(find.text('Осталось мало'), findsOneWidget);
    expect(
      find.text('Одна упаковка. Ещё есть в аптечке «Аптечка мамы» — кухонный шкаф'),
      findsOneWidget,
    );
    expect(find.text('Аптечка мамы · Кухонный шкаф'), findsOneWidget);
    expect(find.byType(PackageCard), findsNWidgets(2));
    expect(find.text('Добавить лекарство'), findsOneWidget);

    appRouter.pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Живот'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Живот'));
    await tester.pumpAndSettle();
    expect(find.text('Нет лекарств для живота'), findsOneWidget);
    expect(find.textContaining('с отметкой «Живот»'), findsOneWidget);
  });

  testWidgets('low stock banner leads to the kit state', (tester) async {
    final container = await pumpApp(tester, AppRoutes.inventory);
    await container
        .read(appControllerProvider.notifier)
        .setQuantity('ibuprofen-demo', 1);
    appRouter.push(AppRoutes.medicine('ibuprofen-demo'));
    await tester.pumpAndSettle();
    expect(find.text('Осталось 1 таблетка'), findsOneWidget);
    await tester.tap(find.text('Состояние аптечки'));
    await tester.pumpAndSettle();
    expect(find.byType(KitStateScreen), findsOneWidget);
  });

  testWidgets('narrow screen and large text do not overflow', (tester) async {
    await pumpApp(
      tester,
      AppRoutes.kitState('home'),
      size: const Size(320, 640),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    appRouter.push(AppRoutes.kitStateCategory('home', 'fever'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    appRouter.push(AppRoutes.kitStateCategory('home', 'stomach'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
