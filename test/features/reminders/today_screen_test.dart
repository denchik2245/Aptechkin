import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/reminders/presentation/widgets/today_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('«Сегодня»: person picker, summary, now card and done card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    final controller = container.read(appControllerProvider.notifier);
    for (final reminder
        in container.read(appControllerProvider).requireValue.reminders) {
      await controller.setReminderEnabled(reminder.id, false);
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 2);
    // Midnight is always due, so «Я» has an «intake now» card.
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
          condition: 'после еды',
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
      ),
      [
        const MedicationReminder(
          id: 'mom-0',
          medicineId: 'ibuprofen-demo',
          courseId: 'mom',
          hour: 0,
          minute: 0,
          dose: '1 таблетка',
          enabled: true,
          unit: 'таблетка',
        ),
      ],
    );
    await controller.recordIntake(
      'mom-0',
      IntakeStatus.taken,
      scheduledDate: DateTime(now.year, now.month, now.day),
    );

    appRouter.go(AppRoutes.reminders);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Все'), findsOneWidget);
    expect(find.textContaining('Сегодня, '), findsOneWidget);
    expect(find.text('Принято 1 из 2'), findsOneWidget);
    expect(find.text('Я · сейчас'), findsOneWidget);
    expect(find.text('Нет запланированных приёмов'), findsNWidgets(2));
    expect(find.textContaining('Принято в '), findsOneWidget);

    await tester.tap(find.byType(PersonSwitcher));
    await tester.pumpAndSettle();
    expect(find.text('Выбор человека'), findsOneWidget);
    await tester.tap(find.text('Мама'));
    await tester.pumpAndSettle();
    expect(find.text('Мама'), findsWidgets);
    expect(find.text('Принято 1 из 1'), findsOneWidget);
    expect(find.text('Все приёмы на сегодня отмечены'), findsOneWidget);
    expect(find.textContaining('Следующий — завтра в 00:00'), findsOneWidget);
    expect(find.text('Я · сейчас'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
