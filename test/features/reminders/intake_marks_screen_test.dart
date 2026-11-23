import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/reminders/presentation/course_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// «Я» has a due intake at midnight; «Мама» has a constant course.
  Future<ProviderContainer> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    final controller = container.read(appControllerProvider.notifier);
    for (final r
        in container.read(appControllerProvider).requireValue.reminders) {
      await controller.setReminderEnabled(r.id, false);
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 2);
    await controller.saveCourse(
      TreatmentCourse(id: 'me', name: 'Простуда', person: 'Я', startsAt: start),
      [
        const MedicationReminder(
          id: 'me-0',
          medicineId: 'ibuprofen-demo',
          courseId: 'me',
          hour: 0,
          minute: 0,
          dose: '1 таблетка',
          enabled: true,
          unit: 'таблетка',
        ),
      ],
    );
    await controller.saveCourse(
      TreatmentCourse(
        id: 'mom',
        name: 'Давление',
        person: 'Мама',
        startsAt: start,
        durationDays: null,
      ),
      [
        const MedicationReminder(
          id: 'mom-0',
          medicineId: 'ibuprofen-demo',
          courseId: 'mom',
          hour: 23,
          minute: 59,
          dose: '1 таблетка',
          enabled: true,
          unit: 'таблетка',
        ),
      ],
    );
    appRouter.go(AppRoutes.reminders);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  IntakeRecord? record(ProviderContainer c) => c
      .read(appControllerProvider)
      .requireValue
      .intakeRecords
      .where((r) => r.reminderId == 'me-0')
      .firstOrNull;

  testWidgets('defer, already taken and undo', (tester) async {
    final container = await open(tester);
    final before = container
        .read(appControllerProvider)
        .requireValue
        .medicines
        .firstWhere((m) => m.id == 'ibuprofen-demo')
        .quantity;
    await tap(tester, 'Отложить');
    expect(find.text('Отложить приём'), findsOneWidget);
    expect(find.text('Я · Ибупрофен, 200 мг'), findsOneWidget);
    expect(find.textContaining('Остаток пока не изменится'), findsOneWidget);
    await tap(tester, '15 минут');
    await tester.tap(find.textContaining('Напомнить в ').last);
    await tester.pumpAndSettle();
    expect(record(container)!.status, IntakeStatus.deferred);
    expect(find.textContaining('Напомним в '), findsOneWidget);
    expect(
      find.text('Приём отложен на 15 минут. Остаток не изменился.'),
      findsOneWidget,
    );

    await tap(tester, 'Уже принял');
    expect(record(container)!.status, IntakeStatus.taken);
    expect(find.textContaining('Приём отмечен в '), findsOneWidget);
    expect(find.text('Открыть историю'), findsOneWidget);

    await tap(tester, 'Отменить');
    expect(record(container), isNull);
    expect(find.text('Отметка отменена'), findsOneWidget);
    expect(
      container
          .read(appControllerProvider)
          .requireValue
          .medicines
          .firstWhere((m) => m.id == 'ibuprofen-demo')
          .quantity,
      before,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip with a reason added later', (tester) async {
    final container = await open(tester);
    await tap(tester, 'Пропустить');
    expect(find.text('Пропустить приём?'), findsOneWidget);
    expect(
      find.textContaining('Сохранится пропуск. Остаток не изменится.'),
      findsOneWidget,
    );
    await tap(tester, 'Пропустить');
    expect(record(container)!.status, IntakeStatus.skipped);
    expect(find.text('Пропуск сохранён'), findsOneWidget);

    await tap(tester, 'Добавить причину');
    expect(find.text('Причина пропуска'), findsOneWidget);
    await tap(tester, 'Плохое самочувствие');
    await tap(tester, 'Сохранить причину');
    expect(record(container)!.reason, 'Плохое самочувствие');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missed intake is marked from «Когда приняли?»', (
    tester,
  ) async {
    final container = await open(tester);
    // Skip, then fix it: «Не отмечено» rows and skipped rows open the sheet.
    await tap(tester, 'Пропустить');
    await tap(tester, 'Пропустить');
    await tester.tap(find.textContaining('Пропущено · ').last);
    await tester.pumpAndSettle();
    expect(find.text('Когда приняли?'), findsOneWidget);
    await tap(tester, 'Сохранить приём');
    expect(record(container)!.status, IntakeStatus.taken);

    await tester.tap(find.textContaining('Принято в ').last);
    await tester.pumpAndSettle();
    expect(find.text('Исправить отметку'), findsOneWidget);
    expect(find.text('Повторного списания не будет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course list: groups, completed and person empty state', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'Курсы');
    expect(find.text('Текущие · 2'), findsOneWidget);
    expect(find.text('Я · 1 курс'), findsOneWidget);
    expect(find.text('Мама · 1 курс'), findsOneWidget);
    expect(find.textContaining('Постоянно · с '), findsOneWidget);

    await tap(tester, 'Завершённые · 0 ›');
    expect(find.text('Завершённых пока нет'), findsOneWidget);
    await tap(tester, 'К текущим курсам');
    expect(find.text('Текущие · 2'), findsOneWidget);

    await tap(tester, 'Простуда');
    expect(find.byType(CourseDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
