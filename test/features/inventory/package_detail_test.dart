import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/package_detail.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 17, 15);
  final today = DateTime(2026, 11, 17);
  Medicine package({
    String id = 'p',
    String kit = 'home',
    String place = 'Верхняя полка',
    int quantity = 14,
    DateTime? expiry,
    bool noExpiry = false,
    DateTime? openedAt,
    int? afterOpening,
    StockLevel? level,
    bool tracksStock = true,
    String? storage,
    String? gtin,
  }) => Medicine(
    id: id,
    pharmacyId: kit,
    name: 'Ибупрофен',
    form: 'Таблетки, покрытые оболочкой',
    dosage: '200 мг',
    quantity: quantity,
    unit: 'таблеток',
    location: place,
    expiryDate: expiry,
    noExpiry: noExpiry,
    openedAt: openedAt,
    afterOpeningDays: afterOpening,
    stockLevel: level,
    tracksStock: tracksStock,
    storage: storage,
    gtin: gtin,
  );
  final later = DateTime(2028, 9, 30);

  group('status banner (875:12466)', () {
    PackageAlert? alert(Medicine item) => packageAlert(item, now);

    test('no banner while the term is fine', () {
      expect(alert(package(expiry: later)), isNull);
    });

    test('expiring soon counts the days', () {
      final result = alert(
        package(expiry: today.add(const Duration(days: 12))),
      )!;
      expect(result.tone, PackageAlertTone.warning);
      expect(result.title, 'Срок истекает через 12 дней');
      expect(result.action, isNull);
    });

    test('expired wins over everything and offers removal', () {
      final result = alert(
        package(expiry: today.subtract(const Duration(days: 10)), quantity: 0),
      )!;
      expect(result.tone, PackageAlertTone.fail);
      expect(result.title, 'Срок истёк — не используйте');
      expect(result.action, PackageAlertAction.remove);
    });

    test('unknown term asks for the date', () {
      final result = alert(package())!;
      expect(result.title, 'Срок не указан');
      expect(result.action, PackageAlertAction.setExpiry);
    });

    test('low stock uses the threshold and the Russian plural', () {
      expect(alert(package(expiry: later, quantity: 2))!.title,
          'Осталось 2 таблетки');
      expect(alert(package(expiry: later, quantity: 3)), isNull);
    });

    test('used up keeps the package and offers removal', () {
      final result = alert(package(expiry: later, quantity: 0))!;
      expect(result.title, 'Закончилось');
      expect(result.tone, PackageAlertTone.info);
      expect(result.action, PackageAlertAction.remove);
    });

    test('no place and no term asks to complete the card', () {
      final result = alert(package(place: ''))!;
      expect(result.title, 'Дополните карточку');
      expect(result.action, PackageAlertAction.complete);
    });

    test('fridge storage shows a note without action', () {
      final result = alert(package(expiry: later, storage: '2–8 °C'))!;
      expect(result.title, 'Хранить в холодильнике');
      expect(result.action, isNull);
      expect(alert(package(expiry: later, storage: 'Не выше 25 °C')), isNull);
    });

    test('level and untracked stock never report low pieces', () {
      expect(
        alert(package(expiry: later, quantity: 0, level: StockLevel.full)),
        isNull,
      );
      expect(alert(package(expiry: later, quantity: 0, tracksStock: false)),
          isNull);
    });
  });

  group('pack hero expiry', () {
    test('fine term shows the month', () {
      final result = packageExpiry(package(expiry: later), now);
      expect(result.label, 'Срок до');
      expect(result.value, 'Сентябрь 2028');
      expect(result.tone, ExpiryTone.ok);
    });

    test('soon shows the exact date', () {
      final result = packageExpiry(
        package(expiry: DateTime(2026, 12, 1)),
        now,
      );
      expect(result.value, '1 декабря 2026');
      expect(result.tone, ExpiryTone.warning);
    });

    test('expired shows how long ago', () {
      final result = packageExpiry(
        package(expiry: today.subtract(const Duration(days: 10))),
        now,
      );
      expect(result.label, 'Срок истёк');
      expect(result.value, '10 дней назад');
      expect(result.tone, ExpiryTone.fail);
    });

    test('unknown, no expiry and used up', () {
      expect(packageExpiry(package(), now).value, 'Не указан');
      expect(
        packageExpiry(package(noExpiry: true), now).value,
        'Без срока годности',
      );
      final empty = packageExpiry(
        package(expiry: DateTime(2027, 11, 30), quantity: 0),
        now,
      );
      expect(empty.icon, 'status-empty-16');
      expect(empty.tone, ExpiryTone.muted);
      expect(empty.value, 'Ноябрь 2027');
    });

    test('opening shortens the term and notes the printed one', () {
      final result = packageExpiry(
        package(
          expiry: DateTime(2027, 5, 31),
          openedAt: DateTime(2026, 11, 1),
          afterOpening: 60,
        ),
        now,
      );
      expect(result.label, 'Использовать до');
      expect(result.value, '31 декабря 2026');
      expect(result.note, 'На упаковке — до мая 2027');
    });
  });

  group('opening (875:12468)', () {
    Medicine opened({
      required DateTime at,
      int? days,
      DateTime? expiry,
    }) => package(
      expiry: expiry ?? DateTime(2027, 5, 31),
      openedAt: at,
      afterOpening: days,
      level: StockLevel.moreThanHalf,
    );

    test('term runs: banner, hero and block', () {
      final item = opened(at: DateTime(2026, 11, 1), days: 30);
      final alert = packageAlert(item, now)!;
      expect(alert.tone, PackageAlertTone.warning);
      expect(alert.title, 'После вскрытия осталось 14 дней');
      expect(
        alert.text,
        'Открытый флакон хранится меньше, чем указано на упаковке',
      );
      expect(alert.action, isNull);
      final hero = packageExpiry(item, now);
      expect(hero.label, 'Использовать до');
      expect(hero.value, '1 декабря 2026');
      expect(hero.note, 'На упаковке — до мая 2027');
      final block = openedSummary(item, now)!;
      expect(block.openedAt, '1 ноября 2026');
      expect(block.term, '30 дней');
      expect(block.tone, OpenedTone.warning);
      expect(block.text, 'Осталось 14 из 30 дней');
      expect(block.progress, closeTo(16 / 30, 1e-9));
    });

    test('long term is calm and has no banner', () {
      final item = opened(at: DateTime(2026, 11, 1), days: 90);
      expect(packageAlert(item, now), isNull);
      final block = openedSummary(item, now)!;
      expect(block.tone, OpenedTone.ok);
      expect(block.text, 'Осталось 74 из 90 дней');
      expect(openedSummary(package(expiry: later), now), isNull);
    });

    test('term after opening is over', () {
      final item = opened(at: DateTime(2026, 8, 2), days: 28);
      final alert = packageAlert(item, now)!;
      expect(alert.tone, PackageAlertTone.fail);
      expect(alert.title, 'Срок после вскрытия истёк');
      expect(
        alert.text,
        'Флакон открыт 2 августа, его хранят 28 дней. Срок на упаковке ещё '
        'идёт, но открытым флаконом пользоваться не стоит',
      );
      expect(alert.action, PackageAlertAction.remove);
      final hero = packageExpiry(item, now);
      expect(hero.label, 'Срок после вскрытия истёк');
      expect(hero.value, '2 месяца назад');
      expect(hero.note, 'На упаковке — до мая 2027');
      final block = openedSummary(item, now)!;
      expect(block.tone, OpenedTone.fail);
      expect(block.progress, 1);
      expect(block.text, 'Срок после вскрытия истёк 2 месяца назад');
    });

    test('printed term over too: the usual expired banner', () {
      final item = opened(
        at: DateTime(2026, 8, 2),
        days: 28,
        expiry: DateTime(2026, 10, 31),
      );
      expect(packageAlert(item, now)!.title, 'Срок истёк — не используйте');
      expect(packageExpiry(item, now).label, 'Срок истёк');
    });

    test('term after opening not known', () {
      final item = opened(at: DateTime(2026, 11, 1), expiry: DateTime(2027, 4, 30));
      final alert = packageAlert(item, now)!;
      expect(alert.tone, PackageAlertTone.info);
      expect(alert.title, 'Нужен срок после вскрытия');
      expect(alert.action, PackageAlertAction.setAfterOpening);
      final hero = packageExpiry(item, now);
      expect(hero.label, 'Использовать до');
      expect(hero.value, 'Неизвестно');
      expect(hero.icon, 'status-unknown-16');
      expect(hero.note, 'На упаковке — до апреля 2027');
      final block = openedSummary(item, now)!;
      expect(block.tone, OpenedTone.unknown);
      expect(block.term, 'Не указан');
      expect(block.progress, isNull);
    });

    test('time ago in days, months and years', () {
      expect(timeAgo(today, today), 'Сегодня');
      expect(timeAgo(DateTime(2026, 11, 7), today), '10 дней назад');
      expect(timeAgo(DateTime(2026, 10, 1), today), '1 месяц назад');
      expect(timeAgo(DateTime(2026, 8, 30), today), '2 месяца назад');
      expect(timeAgo(DateTime(2024, 11, 1), today), '2 года назад');
    });
  });

  group('packages, course (875:12469)', () {
    const kits = [
      Pharmacy(
        id: 'home',
        name: 'Дом',
        ownerLabel: 'Вы',
        isShared: false,
        canEdit: true,
      ),
      Pharmacy(
        id: 'mother',
        name: 'Аптечка мамы',
        ownerLabel: 'Мама',
        isShared: false,
        canEdit: true,
      ),
    ];
    MedicationReminder dose(String id, int hour, {String course = 'cold'}) =>
        MedicationReminder(
          id: id,
          medicineId: 'p',
          hour: hour,
          minute: 0,
          dose: '1 таблетка',
          enabled: true,
          courseId: course,
          unit: 'таблетка',
        );
    AppState withCourse(int quantity, {int days = 7}) => AppState(
      pharmacies: kits,
      selectedPharmacyId: 'home',
      medicines: [package(expiry: later, quantity: quantity)],
      reminders: [dose('r1', 8), dose('r2', 14), dose('r3', 20)],
      intakeRecords: const [],
      courses: [
        TreatmentCourse(
          id: 'cold',
          name: 'Простуда',
          person: 'Я',
          startsAt: today,
          durationDays: days,
        ),
      ],
    );

    test('other packages name their kit and the month', () {
      final state = AppState(
        pharmacies: kits,
        selectedPharmacyId: 'home',
        medicines: [
          package(expiry: later),
          package(
            id: 'a',
            place: 'Сумка в прихожей',
            quantity: 4,
            expiry: DateTime(2026, 12, 1),
          ),
          package(
            id: 'b',
            kit: 'mother',
            place: 'Кухонный шкаф',
            quantity: 10,
            expiry: DateTime(2027, 11, 30),
          ),
        ],
        reminders: const [],
        intakeRecords: const [],
      );
      final current = state.medicines.first;
      final others = otherPackages(state, current);
      expect(otherPackageTitle(state, others.first), 'Дом · Сумка в прихожей');
      expect(
        otherPackageSubtitle(others.first, now),
        '4 таблетки · срок до 1 декабря 2026',
      );
      expect(
        otherPackageSubtitle(others.last, now),
        '10 таблеток · срок до ноября 2027',
      );
      expect(
        packagesTotal(current, others),
        'Всего у вас 28 таблеток в 2 аптечках',
      );
      expect(packagesTotal(current, [others.first]), 'Всего у вас 18 таблеток');
      expect(
        packagesTotal(current, [package(id: 'c', level: StockLevel.full)]),
        isNull,
      );
    });

    test('course banner counts the days the remainder lasts', () {
      final state = withCourse(2);
      final course = packageCourse(state, state.medicines.first, now)!;
      expect(course.dose, 'По 1 таблетке 3 раза в день');
      expect(course.deducts, isTrue);
      expect(course.daysLeft, 1);
      final alert = packageAlert(state.medicines.first, now, course: course)!;
      expect(alert.tone, PackageAlertTone.warning);
      expect(alert.title, 'В курсе «Простуда» · хватит на 1 день');
      expect(
        alert.text,
        'По 1 таблетке 3 раза в день. Остаток уменьшается, когда вы '
        'отмечаете «Принял»',
      );
      expect(alert.action, PackageAlertAction.openCourse);
      expect(alert.courseId, 'cold');
    });

    test('enough for the course: calm banner without days', () {
      final state = withCourse(30);
      final course = packageCourse(state, state.medicines.first, now)!;
      expect(course.daysLeft, isNull);
      final alert = packageAlert(state.medicines.first, now, course: course)!;
      expect(alert.tone, PackageAlertTone.info);
      expect(alert.title, 'В курсе «Простуда»');
    });

    test('intakes marked today are already taken from the remainder', () {
      final state = withCourse(4).copyWith(
        intakeRecords: [
          IntakeRecord(
            reminderId: 'r1',
            occurredAt: now,
            status: IntakeStatus.taken,
          ),
        ],
      );
      // Today 2 more, tomorrow 3: four last two days.
      expect(packageCourse(state, state.medicines.first, now)!.daysLeft, 2);
    });

    test('no course, finished course or another medicine', () {
      final state = withCourse(2);
      expect(
        packageCourse(state.copyWith(courses: const []), state.medicines.first, now),
        isNull,
      );
      final done = state.copyWith(
        courses: [
          state.courses.first.copyWith(status: CourseStatus.completed),
        ],
      );
      expect(packageCourse(done, state.medicines.first, now), isNull);
    });

    test('dose wording and stock units', () {
      MedicationReminder r(int amount, String unit, [IntakeFrequency f =
          IntakeFrequency.daily]) => MedicationReminder(
        id: 'x',
        medicineId: 'p',
        hour: 9,
        minute: 0,
        dose: '',
        enabled: true,
        courseId: 'c',
        amount: amount,
        unit: unit,
        frequency: f,
      );
      expect(courseDose([r(2, 'капсула')]), 'По 2 капсулы 1 раз в день');
      expect(courseDose([r(5, 'капля'), r(5, 'капля')]), 'По 5 капель 2 раза в день');
      expect(
        courseDose([r(1, 'таблетка', IntakeFrequency.alternate)]),
        'По 1 таблетке 1 раз в день через день',
      );
      expect(intakeDeductsStock(r(1, 'таблетка'), package()), isTrue);
      expect(intakeDeductsStock(r(5, 'капля'), package()), isFalse);
    });
  });

  group('actions (875:12470)', () {
    test('package size from the catalog description', () {
      Medicine pills(String description, {String unit = 'таблеток'}) =>
          package().withPackage(description, unit);
      expect(packagePieces(pills('2 x БЛИСТЕР по 10 шт')), 20);
      expect(packagePieces(pills('БЛИСТЕР по 10 шт', unit: 'шт.')), isNull);
      expect(packagePieces(pills('ФЛАКОН по 100.000 мл')), isNull);
      expect(packagePieces(package()), isNull);
    });

    test('removal reason fits the package', () {
      expect(
        suggestedRemovalReason(
          package(expiry: today.subtract(const Duration(days: 1))),
          now,
        ),
        RemovalReason.expired,
      );
      expect(
        suggestedRemovalReason(package(expiry: later, quantity: 0), now),
        RemovalReason.finished,
      );
      expect(suggestedRemovalReason(package(expiry: later), now), isNull);
    });
  });

  group('card texts', () {
    final state = AppState(
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
      medicines: [
        package(expiry: later),
        package(
          id: 'q',
          kit: 'dacha',
          place: 'ящик в прихожей',
          quantity: 4,
          expiry: DateTime(2026, 9, 22),
        ),
      ],
      reminders: const [],
      intakeRecords: const [],
    );

    test('title, place and other packages', () {
      expect(packageTitle(state.medicines.first), 'Ибупрофен, 200 мг');
      expect(placeLabel(state, state.medicines.first), 'Верхняя полка');
      final others = otherPackages(state, state.medicines.first);
      expect(others.map((m) => m.id), ['q']);
      expect(placeLabel(state, others.single), 'Дача · ящик в прихожей');
      expect(
        otherPackageSubtitle(others.single, DateTime(2026, 9, 1)),
        '4 таблетки · срок до 22 сентября 2026',
      );
    });

    test('specs keep only known values and group the barcode', () {
      final specs = packageSpecs(package(gtin: '04601234567890'));
      expect(specs.map((row) => row.$1), [
        'Форма выпуска',
        'Дозировка',
        'Штрихкод',
      ]);
      expect(specs.last.$2, '4 601234 567890');
    });

    test('dates: stock caption and meta line', () {
      final item = package().copyWith(
        addedAt: DateTime(2026, 10, 12),
        updatedAt: DateTime(2026, 10, 20, 9),
        stockUpdatedAt: DateTime(2026, 9, 1),
      );
      expect(stockCaption(item, now), 'обновлено 1 сентября');
      expect(
        packageMetaLine(item, now),
        'Добавлено 12 октября 2026 · изменено 20 октября',
      );
      expect(packageMetaLine(package(), now), isNull);
    });

    test('editPackage stamps the change and the remainder', () {
      final edited = state.editPackage(
        'p',
        (item) => item.copyWith(quantity: 13),
        now,
        stock: true,
      );
      final item = edited.medicines.first;
      expect(item.quantity, 13);
      expect(item.updatedAt, now);
      expect(item.stockUpdatedAt, now);
      expect(edited.kitById('home')!.checkedAt, now);
      final moved = state.movePackage('p', kitId: 'home', place: 'Ящик', now: now);
      expect(moved.medicines.first.updatedAt, now);
      expect(moved.medicines.first.stockUpdatedAt, isNull);
    });

    test('new fields survive JSON', () {
      final item = package(storage: '2–8 °C').copyWith(
        addedAt: DateTime(2026, 10, 12),
      );
      final restored = Medicine.fromJson(item.toJson());
      expect(restored.storage, '2–8 °C');
      expect(restored.addedAt, DateTime(2026, 10, 12));
      expect(restored.updatedAt, isNull);
    });
  });
}

extension on Medicine {
  Medicine withPackage(String description, String unit) => Medicine.fromJson({
    ...toJson(),
    'packageDescription': description,
    'unit': unit,
    'form': 'Таблетки',
  });
}
