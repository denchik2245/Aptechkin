import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/features/settings/data/backup_files.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:aptechka/features/settings/domain/backup_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replaces the share sheet and the file picker.
class _FakeBackupFiles implements BackupFiles {
  final saved = <String, String>{};
  final picks = <String?>[];
  bool closeSheet = false;

  @override
  Future<bool> save(String json, String fileName) async {
    if (closeSheet) return false;
    saved[fileName] = json;
    return true;
  }

  @override
  Future<String?> pick() async => picks.removeAt(0);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BackupStore.lastSavedAt.value = null;
  });

  Future<ProviderContainer> openApp(
    WidgetTester tester,
    String route, {
    BackupFiles? files,
  }) async {
    // A tall phone-width screen, so every settings row is built.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        if (files != null) backupFilesProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    appRouter.go(route);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('settings change theme, type size and warning window', (
    tester,
  ) async {
    final container = await openApp(tester, AppRoutes.settings);
    AppSettings settings() =>
        container.read(appControllerProvider).requireValue.settings;
    expect(find.text('Данные только на этом телефоне'), findsOneWidget);
    expect(find.text('Как в системе'), findsOneWidget);
    expect(find.text('Срок — за 30 дней · остаток — 2 ед.'), findsOneWidget);

    await tapText(tester, 'Оформление');
    await tapText(tester, 'Тёмная');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tapText(tester, 'Ещё крупнее');
    expect(settings().textScale, 1.3);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Тёмная'), findsOneWidget);

    await tapText(tester, 'Когда предупреждать');
    await tapText(tester, '7 дней');
    await tapText(tester, '5 ед.');
    expect(settings().expiryWarningDays, 7);
    expect(settings().lowStockThreshold, 5);
    expect(find.text('Сейчас под условия попадают'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications and the digest schedule', (tester) async {
    final container = await openApp(tester, AppRoutes.settingsNotifications);
    AppSettings settings() =>
        container.read(appControllerProvider).requireValue.settings;
    await tapText(tester, 'Приём лекарств');
    expect(settings().intakeSchedule, isFalse);
    await tapText(tester, 'Сводка по аптечкам');
    expect(settings().digestEnabled, isFalse);
    expect(find.text('Так выглядит сводка'), findsOneWidget);

    await tapText(tester, 'Когда присылать');
    expect(find.text('День недели'), findsOneWidget);
    expect(find.textContaining('Следующая — вс,'), findsOneWidget);
    await tapText(tester, 'Пн');
    expect(settings().digestWeekday, DateTime.monday);
    expect(find.textContaining('Следующая — пн,'), findsOneWidget);
    await tapText(tester, 'Каждый день');
    expect(settings().digestFrequency, DigestFrequency.daily);
    expect(find.text('День недели'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a backup copy is saved to a file', (tester) async {
    final files = _FakeBackupFiles()..closeSheet = true;
    final container = await openApp(tester, AppRoutes.settings, files: files);
    await tapText(tester, 'Сохранить данные');
    expect(find.text('Сохранность данных'), findsOneWidget);
    await tapText(tester, 'Создать копию');
    // The share sheet was closed: nothing saved, the screen stays.
    expect(find.text('Копия сохранена'), findsNothing);
    expect(BackupStore.lastSavedAt.value, isNull);

    files.closeSheet = false;
    await tapText(tester, 'Создать копию');
    expect(find.text('Копия сохранена'), findsOneWidget);
    expect(
      files.saved.keys.single,
      matches(RegExp(r'^aptechka-\d{4}-\d{2}-\d{2}\.json$')),
    );
    final state = container.read(appControllerProvider).requireValue;
    expect(
      BackupCodec.decode(files.saved.values.single).medicines,
      hasLength(state.medicines.length),
    );
    expect(find.text('${state.medicines.length}'), findsWidgets);
    expect(BackupStore.lastSavedAt.value, isNotNull);

    await tapText(tester, 'Готово');
    expect(find.text('Данные только на этом телефоне'), findsNothing);
    expect(find.text('Сегодня'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restore checks the file and replaces data after confirmation', (
    tester,
  ) async {
    final files = _FakeBackupFiles();
    final container = await openApp(
      tester,
      AppRoutes.settingsBackup,
      files: files,
    );
    final original = container.read(appControllerProvider).requireValue;
    final backup = original.copyWith(
      medicines: [],
      reminders: [],
      intakeRecords: [],
    );

    files.picks.add('{broken');
    await tapText(tester, 'Восстановить из файла');
    expect(find.text('Не удалось прочитать файл'), findsOneWidget);
    expect(
      container.read(appControllerProvider).requireValue.medicines,
      hasLength(original.medicines.length),
    );

    files.picks.add(
      BackupCodec.encode(backup, createdAt: DateTime(2026, 11, 6, 10, 30)),
    );
    await tapText(tester, 'Выбрать другой файл');
    expect(find.text('Заменить данные на этом телефоне?'), findsOneWidget);
    expect(find.textContaining('от 6 ноября 2026'), findsOneWidget);
    expect(find.text('Из файла'), findsOneWidget);

    // «Сначала сохранить текущие» is on: closing the sheet keeps the data.
    files.closeSheet = true;
    await tapText(tester, 'Заменить данные');
    expect(
      container.read(appControllerProvider).requireValue.medicines,
      hasLength(original.medicines.length),
    );

    // Let the «Копия не сохранена» toast go away.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    files.closeSheet = false;
    await tapText(tester, 'Заменить данные');
    expect(files.saved, hasLength(1));
    expect(
      container.read(appControllerProvider).requireValue.medicines,
      isEmpty,
    );
    expect(find.text('Данные восстановлены'), findsOneWidget);
    await tapText(tester, 'Открыть аптечки');
    expect(appRouter.routeInformationProvider.value.uri.path, AppRoutes.kits);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help answers open sections; about shows the version', (
    tester,
  ) async {
    await openApp(tester, AppRoutes.settings);
    await tapText(tester, 'Помощь');
    await tapText(tester, 'Когда лекарство «Скоро истекает»');
    expect(find.textContaining('сейчас за 30 дней'), findsOneWidget);
    await tapText(tester, 'Изменить порог');
    expect(find.text('Когда предупреждать'), findsWidgets);
    appRouter.go(AppRoutes.settingsAbout);
    await tester.pumpAndSettle();
    expect(find.text('Версия 1.0 (1)'), findsOneWidget);
    expect(find.text('Лицензии'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark filters scroll, remain legible and location reset works', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .updateSettings(const AppSettings(appearance: AppAppearance.dark));
    appRouter.go('/inventory');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final allChip = tester.widget<Text>(find.textContaining('Все · '));
    expect(allChip.style!.color, isNot(Colors.black));
    final emptyChip = find.textContaining('Нет в наличии ·');
    await tester.ensureVisible(emptyChip);
    await tester.pumpAndSettle();
    await tester.tap(emptyChip);
    await tester.pumpAndSettle();
    // «3 · Фильтры» (825:4879): an empty filter shows its own card.
    expect(find.text('Все лекарства в наличии'), findsOneWidget);
    await tester.tap(emptyChip);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Место: все'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Место: все'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Верхняя полка').last);
    await tester.pumpAndSettle();
    expect(find.text('Место: верхняя полка'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Нет в наличии ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Нет в наличии ·'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    expect(find.text('Место: все'), findsOneWidget);
  });

  testWidgets('alerts and paused schedule respond to settings', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .updateSettings(
          const AppSettings(
            expiryAlerts: false,
            stockAlerts: false,
            intakeSchedule: false,
          ),
        );
    appRouter.go('/reminders');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Расписание на паузе'), findsOneWidget);
    expect(find.text('Принял'), findsNothing);
    // Below Утро / День / Вечер, so the lazy list builds it after a scroll.
    await tester.scrollUntilVisible(
      find.text('Предупреждения выключены'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Предупреждения выключены'), findsOneWidget);
  });

  testWidgets('large type stays usable on a short phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await container
        .read(appControllerProvider.notifier)
        .updateSettings(
          const AppSettings(appearance: AppAppearance.dark, textScale: 1.3),
        );
    appRouter.go('/inventory');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AptechkaApp(),
      ),
    );
    await tester.pumpAndSettle();
    final empty = find.textContaining('Нет в наличии ·');
    await tester.ensureVisible(empty);
    await tester.pumpAndSettle();
    await tester.tap(empty);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(empty);
    await tester.pumpAndSettle();
    appRouter.go('/');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final route in [
      AppRoutes.settings,
      AppRoutes.settingsAppearance,
      AppRoutes.settingsNotifications,
      AppRoutes.settingsDigest,
      AppRoutes.settingsThresholds,
      AppRoutes.settingsBackup,
      AppRoutes.settingsHelp,
      AppRoutes.settingsAbout,
    ]) {
      appRouter.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
    expect(tester.takeException(), isNull);
  });
}
