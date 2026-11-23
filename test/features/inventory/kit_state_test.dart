import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 10);

  Medicine package(
    String id,
    MedicinePurpose purpose, {
    String kit = 'home',
    String place = 'Полка',
    int quantity = 4,
    DateTime? expiry,
    DateTime? openedAt,
    int? afterOpening,
  }) => Medicine(
    id: id,
    pharmacyId: kit,
    name: id,
    form: 'Капли',
    dosage: '',
    quantity: quantity,
    unit: 'флакон',
    location: place,
    expiryDate: expiry,
    openedAt: openedAt,
    afterOpeningDays: afterOpening,
    purposes: [purpose],
  );

  AppState state(List<Medicine> medicines) => AppState(
    pharmacies: const [
      Pharmacy(
        id: 'home',
        name: 'Дом',
        ownerLabel: 'Вы',
        isShared: false,
        canEdit: true,
      ),
      Pharmacy(
        id: 'dacha',
        name: 'Дача',
        ownerLabel: 'Вы',
        isShared: false,
        canEdit: true,
      ),
    ],
    selectedPharmacyId: 'home',
    medicines: medicines,
    reminders: const [],
    intakeRecords: const [],
  );

  final far = DateTime(2028, 9);
  final soon = DateTime(2026, 9, 20);
  final past = DateTime(2026, 8);

  final figma = state([
    package('e1', MedicinePurpose.ear, expiry: past),
    package('e2', MedicinePurpose.ear, expiry: past),
    package('w1', MedicinePurpose.wounds, kit: 'dacha', place: 'Ящик в прихожей', expiry: far),
    package(
      'n1',
      MedicinePurpose.runnyNose,
      expiry: far,
      openedAt: DateTime(2026, 8, 16),
      afterOpening: 28,
    ),
    package('c1', MedicinePurpose.cough, expiry: far),
    package('f1', MedicinePurpose.fever, expiry: far),
    package('f2', MedicinePurpose.headache, expiry: far),
    package('f3', MedicinePurpose.fever, expiry: soon),
  ]);

  test('rows follow the Figma order and wording', () {
    final rows = kitCategories(figma, 'home', now);
    expect(
      [for (final row in rows) (row.category.label, row.level, row.summary)],
      [
        ('Боль в ухе', CategoryLevel.none, 'Годных нет · 2 с истёкшим сроком'),
        ('Аллергия', CategoryLevel.none, 'Лекарств нет'),
        ('Ушибы и раны', CategoryLevel.none, 'Есть только в другой аптечке'),
        ('Горло', CategoryLevel.none, 'Лекарств нет'),
        ('Живот', CategoryLevel.none, 'Лекарств нет'),
        ('Насморк', CategoryLevel.low, '1 упаковка · скоро истечёт'),
        ('Кашель', CategoryLevel.low, '1 упаковка'),
        ('Температура и боль', CategoryLevel.enough, '3 упаковки'),
      ],
    );
    expect(kitStateSummary(rows), 'В 7 категориях лекарств нет или мало');
    expect(
      kitStateSummary([rows.last]),
      'Во всех категориях достаточно',
    );
  });

  test('all expiring soon is low', () {
    final row = kitCategory(
      state([
        package('a', MedicinePurpose.cough, expiry: soon),
        package('b', MedicinePurpose.cough, expiry: soon),
      ]),
      'home',
      KitCategory.cough,
      now,
    );
    expect(row.level, CategoryLevel.low);
    expect(row.summary, '2 упаковки · скоро истекут');
  });

  test('used up only', () {
    final row = kitCategory(
      state([package('a', MedicinePurpose.cough, quantity: 0, expiry: far)]),
      'home',
      KitCategory.cough,
      now,
    );
    expect(row.summary, 'Годных нет · закончились');
  });

  group('banner', () {
    CategoryBanner? banner(AppState s, KitCategory category) => categoryBanner(
      s,
      'home',
      kitCategory(s, 'home', category, now),
      now,
    );

    test('one opened package, none elsewhere', () {
      final value = banner(figma, KitCategory.runnyNose)!;
      expect(value.tone, CategoryBannerTone.warning);
      expect(value.title, 'Осталось мало');
      expect(
        value.text,
        'Одна упаковка, и та вскрыта — использовать ещё 3 дня. '
        'В других аптечках нет',
      );
    });

    test('one package with more elsewhere', () {
      final value = banner(
        state([
          package('c1', MedicinePurpose.cough, expiry: far),
          package('c2', MedicinePurpose.cough, kit: 'dacha', expiry: far),
        ]),
        KitCategory.cough,
      )!;
      expect(value.text, 'Одна упаковка. Ещё есть в аптечке «Дача» — полка');
    });

    test('expired here', () {
      final value = banner(figma, KitCategory.ear)!;
      expect(value.tone, CategoryBannerTone.fail);
      expect(
        value.text,
        '2 упаковки с истёкшим сроком — их лучше убрать. В других аптечках нет',
      );
    });

    test('only in another kit', () {
      final value = banner(figma, KitCategory.wounds)!;
      expect(value.tone, CategoryBannerTone.info);
      expect(value.title, 'В «Доме» нет');
      expect(value.text, 'Есть в аптечке «Дача» — ящик в прихожей');
    });

    test('enough and empty have none', () {
      expect(banner(figma, KitCategory.fever), isNull);
      expect(banner(figma, KitCategory.allergy), isNull);
      expect(kitCategory(figma, 'home', KitCategory.allergy, now).isEmpty, isTrue);
    });
  });

  test('empty text names every mark', () {
    expect(
      KitCategory.allergy.emptyText,
      'Ни в одной аптечке нет лекарств с отметкой «Аллергия». Если такое '
      'лекарство уже есть, добавьте отметку в его карточке.',
    );
    expect(
      KitCategory.fever.emptyText,
      startsWith(
        'Ни в одной аптечке нет лекарств с отметками «Температура» или '
        '«Головная боль».',
      ),
    );
  });
}
