import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/package_status.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 17);
  Medicine package({
    String id = 'p',
    String kit = 'home',
    String place = 'Полка',
    int quantity = 4,
    DateTime? expiry,
    DateTime? openedAt,
    int? afterOpening,
    String unit = 'таблеток',
  }) => Medicine(
    id: id,
    pharmacyId: kit,
    name: 'Ибупрофен',
    form: 'Таблетки',
    dosage: '200 мг',
    quantity: quantity,
    unit: unit,
    location: place,
    expiryDate: expiry,
    openedAt: openedAt,
    afterOpeningDays: afterOpening,
  );

  group('status line', () {
    String text(Medicine item) => packageStatusLine(item, now).text;

    test('follows the Figma medicine card wording', () {
      expect(
        text(package(expiry: now.subtract(const Duration(days: 10)))),
        'Срок истёк 10 дней назад',
      );
      expect(
        text(package(expiry: DateTime(2026, 12, 2))),
        'Срок до 2 декабря 2026',
      );
      expect(text(package(expiry: DateTime(2028, 9, 30))), 'Срок до сентября 2028');
      expect(text(package()), 'Срок не указан');
      expect(
        text(
          package(
            expiry: DateTime(2028),
            openedAt: now.subtract(const Duration(days: 4)),
            afterOpening: 7,
          ),
        ),
        'Вскрыт · ещё 3 дня',
      );
      expect(text(package(quantity: 0, expiry: DateTime(2028))), 'Закончилось');
    });

    test('tones and attention grouping', () {
      final soon = package(expiry: DateTime(2026, 12, 2));
      expect(packageStatusLine(soon, now).tone, PackageTone.warning);
      expect(needsAttention(soon, now), isTrue);
      expect(needsAttention(package(expiry: DateTime(2028)), now), isFalse);
      expect(needsAttention(package(quantity: 0), now), isTrue);
    });

    test('amount uses Russian plural forms and form icons', () {
      expect(amountLabel(package(quantity: 4)), '4 таблетки');
      expect(amountLabel(package(quantity: 14)), '14 таблеток');
      expect(amountLabel(package(quantity: 1, unit: 'флакон')), '1 флакон');
      expect(amountLabel(package(quantity: 10, unit: 'мл')), '10 мл');
      expect(formIcon('Таблетки'), 'form/pills');
      expect(formIcon('Капли назальные'), 'form/drops');
      expect(formIcon('Мазь'), 'form/cream');
    });

    test('purposes survive JSON; the old single purpose is read', () {
      final legacy = package().toJson()
        ..remove('purposes')
        ..['purpose'] = MedicinePurpose.ear.name;
      expect(Medicine.fromJson(legacy).purposes, [MedicinePurpose.ear]);

      final marked = package().copyWith(
        purposes: [MedicinePurpose.fever, MedicinePurpose.headache],
        customPurpose: ' Ушибы ',
      );
      final restored = Medicine.fromJson(marked.toJson());
      expect(restored.purposes, [
        MedicinePurpose.fever,
        MedicinePurpose.headache,
      ]);
      expect(restored.customPurpose, 'Ушибы');
      expect(restored.purposeLabel, 'Температура, Головная боль, Ушибы');
      expect(Medicine.fromJson(package().toJson()).purposes, isEmpty);
      expect(package().purposeLabel, isNull);
    });
  });

  group('places', () {
    const home = Pharmacy(
      id: 'home',
      name: 'Дом',
      ownerLabel: 'Вы',
      isShared: false,
      canEdit: true,
      places: ['Холодильник'],
    );
    const dacha = Pharmacy(
      id: 'dacha',
      name: 'Дача',
      ownerLabel: 'Вы',
      isShared: false,
      canEdit: true,
    );
    final state = AppState(
      pharmacies: const [home, dacha],
      selectedPharmacyId: 'home',
      medicines: [
        package(id: 'a', place: 'Полка'),
        package(id: 'b', place: 'Холодильник'),
        package(id: 'c', place: ''),
      ],
      reminders: const [],
      intakeRecords: const [],
    );

    test('listed places come first, then places used by packages', () {
      expect(state.placesOf('home'), ['Холодильник', 'Полка']);
      expect(state.countAt('home', ''), 1);
      expect(state.isPlaceTaken('home', ' полка '), isTrue);
    });

    test('rename and delete update the packages', () {
      final renamed = state.renamePlace('home', 'Полка', 'Верхняя полка');
      expect(renamed.placesOf('home'), ['Холодильник', 'Верхняя полка']);
      expect(renamed.medicines.first.location, 'Верхняя полка');
      final deleted = renamed.deletePlace('home', 'Холодильник');
      expect(deleted.placesOf('home'), ['Верхняя полка']);
      expect(deleted.countAt('home', ''), 2);
    });

    test('moving a package to another kit adds the place there', () {
      final moved = state.movePackage(
        'a',
        kitId: 'dacha',
        place: 'Шкаф в спальне',
        now: now,
      );
      expect(moved.medicinesIn('dacha').single.id, 'a');
      expect(moved.placesOf('dacha'), ['Шкаф в спальне']);
      expect(moved.kitById('dacha')!.checkedAt, now);
    });
  });
}
