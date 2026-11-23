import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/features/onboarding/data/onboarding_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    hideAppToast();
    OnboardingStore.completed.value = null;
  });

  Future<void> pumpApp(WidgetTester tester, String path) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appRouter.go(path);
    await tester.pumpWidget(const ProviderScope(child: AptechkaApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('first launch shows onboarding and «Пропустить» opens «Дом»', (
    tester,
  ) async {
    await OnboardingStore.load();
    expect(OnboardingStore.completed.value, isFalse);
    await pumpApp(tester, AppRoutes.kits);

    expect(find.text('Вся аптечка\nпод рукой'), findsOneWidget);
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Сроки и вскрытие\nпод контролем'), findsOneWidget);
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Позже'), findsOneWidget);
    expect(find.text('Добавить лекарство'), findsOneWidget);

    await tester.tap(find.text('Позже'));
    await tester.pumpAndSettle();
    expect(OnboardingStore.completed.value, isTrue);
    expect(
      appRouter.routeInformationProvider.value.uri.path,
      AppRoutes.inventory,
    );
  });

  testWidgets('creates a kit and rejects a duplicate name', (tester) async {
    await pumpApp(tester, AppRoutes.kits);
    expect(find.text('Мои аптечки'), findsOneWidget);
    expect(find.text('Общая · владелец Ольга'), findsOneWidget);

    await tester.tap(find.byTooltip('Создать аптечку'));
    await tester.pumpAndSettle();
    expect(find.text('Новая аптечка'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Дом');
    await tester.pump();
    expect(
      find.text('Аптечка «Дом» уже есть. Придумайте другое название'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Машина');
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Иконка аптечки: Машина')), findsOneWidget);
    await tester.tap(find.text('Создать аптечку'));
    await tester.pumpAndSettle();
    expect(
      appRouter.routeInformationProvider.value.uri.path,
      AppRoutes.inventory,
    );

    appRouter.go(AppRoutes.kits);
    await tester.pumpAndSettle();
    expect(find.text('Машина'), findsOneWidget);
    expect(find.text('Нет лекарств'), findsOneWidget);
  });

  testWidgets('swipe deletes a kit, moves medicines and can be undone', (
    tester,
  ) async {
    await pumpApp(tester, AppRoutes.kits);
    final card = find.text('Дом');
    await tester.drag(card, const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить «Дом»?'), findsOneWidget);
    expect(find.text('Перенести и удалить аптечку'), findsOneWidget);
    await tester.tap(find.text('Перенести и удалить аптечку'));
    await tester.pumpAndSettle();

    expect(find.textContaining('перенесены в «Аптечка мамы»'), findsOneWidget);
    expect(find.text('Дом'), findsNothing);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Дом'), findsOneWidget);
  });
}
