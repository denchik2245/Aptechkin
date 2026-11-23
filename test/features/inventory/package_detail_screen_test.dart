import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/inventory/data/drug_photo_catalog.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(hideAppToast);

  final clock = DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final syrup = Medicine(
    id: 'syrup',
    name: 'Нурофен для детей',
    form: 'Суспензия для приёма внутрь',
    dosage: '',
    quantity: 1,
    unit: 'флакон',
    location: 'Верхняя полка',
    expiryDate: DateTime(today.year + 1, 4, 30),
    stockLevel: StockLevel.full,
    description: 'Жаропонижающее для детей с 3 месяцев',
  );
  final thermometer = Medicine(
    id: 'device',
    name: 'Термометр электронный',
    form: 'Прибор',
    dosage: '',
    quantity: 1,
    unit: 'шт.',
    location: 'Ящик стола',
    noExpiry: true,
    tracksStock: false,
    notes: 'Батарейка LR41.',
  );
  final expired = Medicine(
    id: 'expired',
    name: 'Отофизин',
    form: 'Капли ушные',
    dosage: '',
    quantity: 1,
    unit: 'флакон',
    location: 'Сумка в прихожей',
    expiryDate: today.subtract(const Duration(days: 10)),
    stockLevel: StockLevel.lessThanHalf,
  );
  final openedExpired = Medicine(
    id: 'opened-expired',
    name: 'Тобрекс',
    form: 'Капли глазные',
    dosage: '',
    quantity: 1,
    unit: 'флакон',
    location: 'Холодильник',
    expiryDate: DateTime(today.year + 2, 3, 31),
    openedAt: today.subtract(const Duration(days: 40)),
    afterOpeningDays: 28,
    stockLevel: StockLevel.lessThanHalf,
  );
  final pills = Medicine(
    id: 'pills',
    name: 'Амброксол',
    form: 'Таблетки',
    dosage: '30 мг',
    quantity: 2,
    unit: 'таблетки',
    location: 'Верхняя полка',
    expiryDate: DateTime(today.year + 1, 1, 31),
    gtin: '04600000009999',
    packageDescription: '2 x БЛИСТЕР по 10 шт',
  );
  final course = TreatmentCourse(
    id: 'cold',
    name: 'Простуда',
    person: 'Я',
    startsAt: today,
  );
  final doses = [
    for (final (id, hour) in [('r1', 8), ('r2', 14), ('r3', 20)])
      MedicationReminder(
        id: id,
        medicineId: 'pills',
        hour: hour,
        minute: 0,
        dose: '1 таблетка',
        enabled: true,
        courseId: 'cold',
        unit: 'таблетка',
      ),
  ];

  Future<ProviderContainer> pumpCard(
    WidgetTester tester,
    String id, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = ProviderContainer(
      overrides: [
        // A bundled picture stands in for the catalog photo of «pills».
        drugPhotoProvider.overrideWith(
          (ref, gtin) async => gtin == '04600000009999'
              ? const DrugPhoto(
                  asset:
                      'assets/illustrations/empty-first-aid-kit-liquid-glass-v2.png',
                  isDemo: true,
                )
              : null,
        ),
      ],
    );
    addTearDown(container.dispose);
    final state = await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .restoreSnapshot(
          state.copyWith(
            medicines: [
              ...state.medicines,
              for (final item in [
                syrup,
                thermometer,
                expired,
                openedExpired,
                pills,
              ])
                Medicine.fromJson({
                  ...item.toJson(),
                  'pharmacyId': state.selectedPharmacyId,
                }),
            ],
            reminders: [...state.reminders, ...doses],
            courses: [...state.courses, course],
          ),
        );
    appRouter.go(AppRoutes.medicine(id));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('level stock: «Вскрыть» and the level bar', (tester) async {
    final container = await pumpCard(tester, 'syrup');
    expect(find.text('Нурофен для детей'), findsOneWidget);
    expect(find.text('Жаропонижающее для детей с 3 месяцев'), findsOneWidget);
    expect(find.text('Полный'), findsOneWidget);
    expect(find.text('Вскрыть'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Меньше половины'));
    await tester.pumpAndSettle();
    final item = container
        .read(appControllerProvider)
        .requireValue
        .medicines
        .firstWhere((m) => m.id == 'syrup');
    expect(item.stockLevel, StockLevel.lessThanHalf);
    expect(item.stockUpdatedAt, isNotNull);
  });

  testWidgets('«Отметить вскрытие» without a term asks for it, then shows it', (
    tester,
  ) async {
    final container = await pumpCard(tester, 'syrup');
    await tester.tap(find.text('Вскрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Когда открыли флакон?'), findsOneWidget);
    expect(find.text('Не выбрано'), findsOneWidget);
    await tester.tap(find.text('Отметить вскрытие').last);
    await tester.pumpAndSettle();
    expect(find.text('Нужен срок после вскрытия'), findsOneWidget);
    expect(find.text('Неизвестно'), findsOneWidget);
    expect(find.text('Вскрыть'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Указать срок из инструкции'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('После вскрытия'), findsOneWidget);
    expect(find.text('Не указан'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Характеристики'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Указать срок из инструкции'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('28 дней'));
    await tester.pump();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    final item = container
        .read(appControllerProvider)
        .requireValue
        .medicines
        .firstWhere((m) => m.id == 'syrup');
    expect(item.openedAt, today);
    expect(item.afterOpeningDays, 28);
    expect(find.text('Нужен срок после вскрытия'), findsNothing);
    expect(find.text('Осталось 28 из 28 дней'), findsOneWidget);
  });

  testWidgets('term after opening is over', (tester) async {
    await pumpCard(tester, 'opened-expired');
    expect(find.text('Срок после вскрытия истёк'), findsNWidgets(2));
    expect(find.text('Убрать из аптечки'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('После вскрытия'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('28 дней'), findsOneWidget);
  });

  testWidgets('course banner opens the course', (tester) async {
    await pumpCard(tester, 'pills');
    expect(find.text('В курсе «Простуда» · хватит на 1 день'), findsOneWidget);
    expect(find.text('Осталось 2 таблетки'), findsNothing);
    await tester.tap(find.text('Открыть курс'));
    await tester.pumpAndSettle();
    expect(
      appRouter.routerDelegate.currentConfiguration.last.matchedLocation,
      AppRoutes.course('cold'),
    );
  });

  testWidgets('photo opens full screen', (tester) async {
    await pumpCard(tester, 'pills');
    await tester.tap(find.bySemanticsLabel(RegExp('Открыть фото')));
    await tester.pumpAndSettle();
    expect(find.text('Фото упаковки · РЛС Аврора · тестовый доступ'), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Амброксол, 30 мг'), findsOneWidget);
  });

  testWidgets('no instruction: «Добавить заметку» saves a note', (
    tester,
  ) async {
    final container = await pumpCard(tester, 'syrup');
    await tester.scrollUntilVisible(
      find.text('Характеристики'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Инструкции нет в справочнике'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить заметку'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'По 5 мл после еды');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    final item = container
        .read(appControllerProvider)
        .requireValue
        .medicines
        .firstWhere((m) => m.id == 'syrup');
    expect(item.notes, 'По 5 мл после еды');
    expect(find.text('Инструкции нет в справочнике'), findsNothing);
    expect(find.text('По 5 мл после еды'), findsOneWidget);
  });

  testWidgets('«Сколько осталось?»: pieces with the package size', (
    tester,
  ) async {
    final container = await pumpCard(tester, 'pills');
    await tester.tap(find.text('2 таблетки'));
    await tester.pumpAndSettle();
    expect(find.text('Сколько осталось?'), findsOneWidget);
    expect(find.text('Амброксол · верхняя полка'), findsOneWidget);
    expect(find.text('Сейчас 2 · в упаковке было 20'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Больше').last);
    await tester.pump();
    expect(find.text('Было 2 · в упаковке было 20'), findsOneWidget);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .firstWhere((m) => m.id == 'pills')
          .quantity,
      3,
    );
  });

  testWidgets('«Сколько осталось?»: by level', (tester) async {
    final container = await pumpCard(tester, 'syrup');
    await tester.tap(find.text('Полный'));
    await tester.pumpAndSettle();
    expect(
      find.text('Нурофен для детей. Достаточно оценить на глаз'),
      findsOneWidget,
    );
    await tester.tap(find.text('Меньше половины'));
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .firstWhere((m) => m.id == 'syrup')
          .stockLevel,
      StockLevel.lessThanHalf,
    );
  });

  testWidgets('«Перенести упаковку» from the card', (tester) async {
    await pumpCard(tester, 'pills');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перенести'));
    await tester.pumpAndSettle();
    expect(find.text('Перенести упаковку'), findsOneWidget);
    expect(find.text('Куда переложили?'), findsOneWidget);
    expect(find.text('Сейчас здесь'), findsOneWidget);
  });

  testWidgets('«Убрать» without a suggested reason waits for one', (
    tester,
  ) async {
    final container = await pumpCard(tester, 'pills');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Убрать'));
    await tester.pumpAndSettle();
    final button = find.text('Убрать из аптечки');
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Убрать Амброксол?'), findsOneWidget);
    await tester.tap(find.text('Добавлено по ошибке'));
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      container.read(appControllerProvider).requireValue.medicines.any(
        (m) => m.id == 'pills',
      ),
      isFalse,
    );
    expect(find.text('Амброксол убран из аптечки'), findsOneWidget);
    // Let the toast time out.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('device: stock off, note and no expiry', (tester) async {
    await pumpCard(tester, 'device');
    expect(find.text('Остаток не учитываем'), findsOneWidget);
    expect(find.text('Без срока годности'), findsOneWidget);
    expect(find.text('Вскрыть'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Заметка'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Батарейка LR41.'), findsOneWidget);
  });

  testWidgets('expired: banner asks the reason, removes with undo', (
    tester,
  ) async {
    final container = await pumpCard(tester, 'expired');
    expect(find.text('Срок истёк — не используйте'), findsOneWidget);
    expect(find.text('10 дней назад'), findsOneWidget);
    await tester.tap(find.text('Убрать из аптечки'));
    await tester.pumpAndSettle();
    expect(find.text('Убрать Отофизин?'), findsOneWidget);
    expect(find.text('Срок истёк, выбросили'), findsOneWidget);
    await tester.tap(find.text('Убрать из аптечки').last);
    await tester.pumpAndSettle();
    expect(find.text('Отофизин убран из аптечки'), findsOneWidget);
    expect(
      container.read(appControllerProvider).requireValue.medicines.any(
        (m) => m.id == 'expired',
      ),
      isFalse,
    );
    expect(find.text('Отменить'), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(
      container.read(appControllerProvider).requireValue.medicines.any(
        (m) => m.id == 'expired',
      ),
      isTrue,
    );
  });

  testWidgets('narrow screen and large type do not overflow', (tester) async {
    for (final id in [
      'syrup',
      'device',
      'expired',
      'opened-expired',
      'pills',
      'ibuprofen-demo',
    ]) {
      await pumpCard(
        tester,
        id,
        size: const Size(320, 640),
        textScale: 1.3,
      );
      await tester.scrollUntilVisible(
        find.text('Характеристики'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull, reason: id);
    }
  });
}
