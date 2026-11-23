import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(hideAppToast);

  Future<ProviderContainer> pumpInventory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    appRouter.go(AppRoutes.inventory);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('list shows the banner, filters and package cards', (
    tester,
  ) async {
    await pumpInventory(tester);
    expect(find.text('Дом'), findsOneWidget);
    expect(find.textContaining('требуют внимания'), findsOneWidget);
    expect(find.textContaining('Все · '), findsOneWidget);
    expect(find.text('Требуют внимания'), findsOneWidget);
    expect(find.text('Остальные'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('Срок истёк ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Срок истёк ·'));
    await tester.pumpAndSettle();
    expect(find.text('Остальные'), findsNothing);
  });

  testWidgets('swipe changes the stock and removes with undo', (tester) async {
    final container = await pumpInventory(tester);
    final card = find.text('14 таблеток');
    await tester.ensureVisible(card);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.drag(card, const Offset(-260, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Остаток'));
    await tester.pumpAndSettle();
    expect(find.text('Ибупрофен, 200 мг'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Меньше'));
    await tester.pump();
    expect(find.text('Было 14'), findsOneWidget);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    final stock = container
        .read(appControllerProvider)
        .requireValue
        .medicines
        .firstWhere((item) => item.id == 'ibuprofen-demo');
    expect(stock.quantity, 13);
    expect(stock.expiryDate, isNotNull);

    final updated = find.text('13 таблеток');
    await tester.ensureVisible(updated);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.drag(updated, const Offset(-260, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Ибупрофен убран из «Дом»'), findsOneWidget);
    expect(find.text('13 таблеток'), findsNothing);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('13 таблеток'), findsOneWidget);
  });

  testWidgets('switcher, menu and places management', (tester) async {
    await pumpInventory(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('Сменить аптечку')));
    await tester.pumpAndSettle();
    expect(find.text('Аптечки'), findsOneWidget);
    expect(find.text('Все аптечки'), findsOneWidget);
    await tester.tap(find.text('Аптечка мамы'));
    await tester.pumpAndSettle();
    expect(find.text('Аптечка мамы'), findsOneWidget);

    await tester.tap(find.byTooltip('Меню аптечки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Места хранения'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Места помогают'), findsOneWidget);
    await tester.tap(find.text('Добавить место'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Аптечка в машине');
    await tester.pump();
    await tester.tap(find.text('Добавить место').last);
    await tester.pumpAndSettle();
    expect(find.text('Аптечка в машине'), findsOneWidget);
  });
}
