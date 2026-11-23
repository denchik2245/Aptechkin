import 'package:aptechka/app/app.dart';
import 'package:aptechka/app/router.dart';
import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/inventory/presentation/kit_state_screen.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_card.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «Аптечка · 3 · Фильтры» (825:4879).
void main() {
  final now = DateTime(2026, 9, 10);

  Medicine package(
    String id, {
    String kit = 'home',
    int quantity = 4,
    DateTime? expiry,
  }) => Medicine(
    id: id,
    pharmacyId: kit,
    name: id,
    form: 'Таблетки',
    dosage: '',
    quantity: quantity,
    unit: 'таблеток',
    location: 'Полка',
    expiryDate: expiry,
  );

  group('rules', () {
    test('each filter takes its packages', () {
      final expired = package('a', expiry: DateTime(2026, 8));
      final soon = package('b', expiry: DateTime(2026, 9, 20));
      final undated = package('c');
      final usedUp = package('d', quantity: 0, expiry: DateTime(2028));
      bool match(Medicine item, InventoryFilter filter) =>
          matchesInventoryFilter(item, filter, now);
      expect(match(expired, InventoryFilter.expired), isTrue);
      expect(match(soon, InventoryFilter.soon), isTrue);
      expect(match(soon, InventoryFilter.expired), isFalse);
      expect(match(undated, InventoryFilter.noDate), isTrue);
      expect(match(usedUp, InventoryFilter.empty), isTrue);
      expect(match(usedUp, InventoryFilter.expired), isFalse);
      expect(
        [for (final item in [expired, soon, undated, usedUp])
          match(item, InventoryFilter.all)],
        everyElement(isTrue),
      );
    });

    test('removePackages drops reminders, history and shopping marks', () {
      final state = AppState(
        pharmacies: const [
          Pharmacy(
            id: 'home',
            name: 'Дом',
            ownerLabel: 'Вы',
            isShared: false,
            canEdit: true,
          ),
        ],
        selectedPharmacyId: 'home',
        medicines: [package('a'), package('b'), package('c')],
        reminders: const [],
        intakeRecords: const [],
        treatmentShoppingIds: const ['a', 'c'],
      );
      final next = state.removePackages({'a', 'b'}, now);
      expect(next.medicines.map((item) => item.id), ['c']);
      expect(next.treatmentShoppingIds, ['c']);
      expect(next.pharmacies.single.checkedAt, now);
      expect(identical(state.removePackages({'x'}, now), state), isTrue);
    });
  });

  group('screen', () {
    tearDown(hideAppToast);

    Future<ProviderContainer> pumpKit(WidgetTester tester) async {
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
      return container;
    }

    Future<void> chip(WidgetTester tester, String label) async {
      final target = find.textContaining('$label ·');
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    testWidgets('«Срок истёк»: hint, no banner, remove all with undo', (
      tester,
    ) async {
      final container = await pumpKit(tester);
      expect(find.textContaining('требуют внимания'), findsOneWidget);
      await chip(tester, 'Срок истёк');
      expect(find.textContaining('требуют внимания'), findsNothing);
      expect(
        find.text(
          'Просроченные лекарства не принимайте. Уберите их из аптечки и '
          'утилизируйте.',
        ),
        findsOneWidget,
      );
      expect(find.byType(PackageCard), findsNWidgets(2));
      await tester.tap(find.text('Убрать все просроченные'));
      await tester.pumpAndSettle();
      expect(find.text('Убрали из «Дом»: 2 упаковки'), findsOneWidget);
      expect(find.text('Просроченных лекарств нет'), findsOneWidget);
      final left = container
          .read(appControllerProvider)
          .requireValue
          .medicinesIn('home')
          .length;
      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();
      expect(
        container.read(appControllerProvider).requireValue.medicinesIn('home'),
        hasLength(left + 2),
      );
      expect(find.byType(PackageCard), findsNWidgets(2));
    });

    testWidgets('«Скоро истекает», «Нет в наличии» and «Срок не указан»', (
      tester,
    ) async {
      final container = await pumpKit(tester);
      final controller = container.read(appControllerProvider.notifier);
      await chip(tester, 'Скоро истекает');
      expect(
        find.text(
          'Используйте сначала эти упаковки. Предупреждаем за 30 дней — '
          'можно изменить в настройках.',
        ),
        findsOneWidget,
      );
      expect(find.byType(PackageCard), findsOneWidget);
      await chip(tester, 'Скоро истекает'); // a second tap shows all

      await controller.setQuantity('ibuprofen-demo', 0);
      await tester.pumpAndSettle();
      await chip(tester, 'Нет в наличии');
      expect(find.byType(PackageCard), findsOneWidget);
      expect(find.textContaining('Закончившиеся лекарства остаются'), findsOneWidget);
      await tester.tap(find.text('Состояние аптечки'));
      await tester.pumpAndSettle();
      expect(find.byType(KitStateScreen), findsOneWidget);
      appRouter.pop();
      await tester.pumpAndSettle();

      await controller.addMedicine(
        name: 'Парацетамол',
        form: 'Таблетки',
        dosage: '500 мг',
        quantity: 8,
        unit: 'таблеток',
        location: 'Ящик стола',
      );
      await tester.pumpAndSettle();
      await chip(tester, 'Срок не указан');
      expect(
        find.textContaining('Без срока мы не сможем предупредить'),
        findsOneWidget,
      );
      await tester.tap(find.text('Указать срок'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Готово'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('У всех лекарств указан срок'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
