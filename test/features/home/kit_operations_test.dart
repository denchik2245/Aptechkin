import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_icon.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 17);
  Pharmacy kit(String id, String name) => Pharmacy(
    id: id,
    name: name,
    ownerLabel: 'Вы',
    isShared: false,
    canEdit: true,
  );
  Medicine medicine(String id, String kitId, {int expiresIn = 400}) => Medicine(
    id: id,
    pharmacyId: kitId,
    name: id,
    form: 'Таблетки',
    dosage: '',
    quantity: 1,
    unit: 'шт.',
    location: '',
    expiryDate: now.add(Duration(days: expiresIn)),
  );
  final state = AppState(
    pharmacies: [kit('home', 'Дом'), kit('dacha', 'Дача')],
    selectedPharmacyId: 'dacha',
    medicines: [
      medicine('a', 'home'),
      medicine('b', 'dacha', expiresIn: -1),
      medicine('c', 'dacha', expiresIn: 10),
    ],
    reminders: const [
      MedicationReminder(
        id: 'r',
        medicineId: 'b',
        hour: 9,
        minute: 0,
        dose: '1',
        enabled: true,
      ),
    ],
    intakeRecords: const [],
  );

  test('summary counts expired and soon packages', () {
    final summary = state.summaryOf('dacha', now);
    expect((summary.total, summary.expired, summary.soon), (2, 1, 1));
  });

  test('kit names are unique ignoring case and spaces', () {
    expect(state.isKitNameTaken(' дом '), isTrue);
    expect(state.isKitNameTaken('Дом', exceptId: 'home'), isFalse);
    expect(state.isKitNameTaken('Машина'), isFalse);
  });

  test('deleting a kit moves packages and keeps schedules', () {
    final result = state.deleteKit('dacha', moveTo: 'home', now: now);
    expect(result.pharmacies.map((item) => item.id), ['home']);
    expect(result.selectedPharmacyId, 'home');
    expect(result.medicinesIn('home').length, 3);
    expect(result.reminders, hasLength(1));
    expect(result.kitById('home')!.checkedAt, now);
  });

  test('deleting a kit with packages removes them and their schedules', () {
    final result = state.deleteKit('dacha');
    expect(result.medicines.map((item) => item.id), ['a']);
    expect(result.reminders, isEmpty);
  });

  test('the last kit can be deleted and state survives a round trip', () {
    final empty = state.deleteKit('dacha').deleteKit('home');
    expect(empty.pharmacies, isEmpty);
    expect(empty.selectedPharmacyOrNull, isNull);
    expect(AppState.fromJson(empty.toJson()).pharmacies, isEmpty);
  });

  test('kit icon and check date are persisted', () {
    final source = kit('car', 'Машина').copyWith(
      icon: KitIcon.car,
      checkedAt: now,
    );
    final restored = Pharmacy.fromJson(source.toJson());
    expect(restored.icon, KitIcon.car);
    expect(restored.checkedAt, now);
    // Older records without an icon get one from the name.
    expect(
      Pharmacy.fromJson({'id': 'x', 'name': 'Дача'}).icon,
      KitIcon.dacha,
    );
  });

  test('access line follows the Figma wording', () {
    const shared = Pharmacy(
      id: 'm',
      name: 'Аптечка мамы',
      ownerLabel: 'Ольга',
      isShared: true,
      canEdit: true,
    );
    const viewOnly = Pharmacy(
      id: 'g',
      name: 'Бабушка',
      ownerLabel: 'Сергей',
      isShared: true,
      canEdit: false,
    );
    expect(shared.accessLabel, 'Общая · владелец Ольга');
    expect(viewOnly.accessLabel, 'Только просмотр · владелец Сергей');
    expect(kit('home', 'Дом').accessLabel, isNull);
  });

  test('«Проверено …» uses relative wording without month names', () {
    String label(int days) =>
        checkedAgoLabel(now.subtract(Duration(days: days)), now);
    expect(label(0), 'Проверено сегодня');
    expect(label(1), 'Проверено вчера');
    expect(label(3), 'Проверено 3 дня назад');
    expect(label(14), 'Проверено 2 недели назад');
    expect(label(92), 'Проверено 3 месяца назад');
    expect(label(150), 'Проверено 4 месяца назад');
    expect(label(400), 'Проверено больше года назад');
  });
}
