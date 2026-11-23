import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/presentation/drug_catalog_screen.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_card.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> pumpSearch(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .updateSettings(AppSettings(textScale: textScale));
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go(AppRoutes.kits);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.push(AppRoutes.search);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  testWidgets('start, results by kit and «Недавние»', (tester) async {
    await pumpSearch(tester);
    expect(find.text('Поиск'), findsOneWidget);
    expect(find.text('Лекарство во всех аптечках'), findsOneWidget);
    expect(find.text('Недавние'), findsNothing);
    expect(find.text('Что есть от…'), findsOneWidget);
    for (final label in [
      'Температура',
      'Головная боль',
      'Насморк',
      'Кашель',
      'Горло',
      'Живот',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await search(tester, 'лоратадин');
    expect(find.text('Дом'), findsOneWidget);
    expect(find.text('Аптечка мамы · общая'), findsOneWidget);
    expect(find.byType(PackageCard), findsNWidgets(2));

    await tester.tap(find.byType(PackageCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Где лежит'), findsOneWidget);
    appRouter.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Недавние'), findsOneWidget);
    await tester.tap(find.text('лоратадин'));
    await tester.pumpAndSettle();
    expect(find.byType(PackageCard), findsNWidgets(2));
  });

  testWidgets('only in another kit shows the banner', (tester) async {
    final container = await pumpSearch(tester);
    await container
        .read(appControllerProvider.notifier)
        .selectPharmacy('mother');
    await search(tester, 'ибупрофен');
    expect(find.text('В аптечке «Аптечка мамы» нет'), findsOneWidget);
    expect(find.text('Нашли в аптечке «Дом»'), findsOneWidget);
    expect(find.text('Дом · 2 упаковки'), findsOneWidget);
  });

  testWidgets('symptom chip groups by date and names the kit', (tester) async {
    final container = await pumpSearch(tester);
    final controller = container.read(appControllerProvider.notifier);
    await controller.setPurposes('ibuprofen-demo', [MedicinePurpose.fever]);
    await controller.setPurposes('ibuprofen-old-demo', [MedicinePurpose.fever]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Температура'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Это не замена консультации'), findsOneWidget);
    expect(find.text('Можно использовать по сроку'), findsOneWidget);
    expect(find.text('Не используйте'), findsOneWidget);
    expect(find.text('Дом · Верхняя полка'), findsOneWidget);
  });

  testWidgets('nothing found opens the catalog with the query', (
    tester,
  ) async {
    await pumpSearch(tester);
    await search(tester, 'аспирин');
    expect(find.text('Ни в одной аптечке нет'), findsOneWidget);
    expect(
      find.text(
        'Искали «аспирин» в 2 аптечках по названию и действующему веществу.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Найти вручную'));
    await tester.pumpAndSettle();
    final catalog = tester.widget<DrugCatalogScreen>(
      find.byType(DrugCatalogScreen),
    );
    expect(catalog.initialQuery, 'аспирин');
    expect(find.widgetWithText(TextField, 'аспирин'), findsOneWidget);
  });

  testWidgets('narrow screen and large text do not overflow', (tester) async {
    await pumpSearch(tester, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await search(tester, 'ибупрофен');
    expect(tester.takeException(), isNull);
    await search(tester, 'аспирин');
    expect(tester.takeException(), isNull);
  });
}
