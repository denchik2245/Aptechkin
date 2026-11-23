import 'dart:convert';

import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:aptechka/features/settings/domain/backup_codec.dart';
import 'package:aptechka/features/settings/domain/settings_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Thursday.
  final now = DateTime(2026, 11, 5, 12);

  Medicine package(
    String id, {
    int quantity = 10,
    DateTime? expiry,
    StockLevel? level,
    bool tracksStock = true,
  }) => Medicine(
    id: id,
    name: id,
    form: 'Таблетки',
    dosage: '',
    quantity: quantity,
    unit: 'таблетка',
    location: 'Полка',
    expiryDate: expiry,
    stockLevel: level,
    tracksStock: tracksStock,
  );

  AppState state(
    List<Medicine> medicines, {
    AppSettings settings = const AppSettings(),
    List<IntakeRecord> records = const [],
  }) => AppState(
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
    medicines: medicines,
    reminders: const [],
    intakeRecords: records,
    settings: settings,
  );

  test('row labels follow the Figma wording', () {
    expect(appearanceLabel(AppAppearance.system), 'Как в системе');
    expect(
      appearanceLabel(AppAppearance.system, onDevice: true),
      'Как на устройстве',
    );
    expect(textScaleLabel(1), 'Как на устройстве');
    expect(textScaleLabel(1.15), 'Крупнее');
    expect(textScaleLabel(1.3), 'Ещё крупнее');
    expect(
      thresholdsLabel(const AppSettings()),
      'Срок — за 30 дней · остаток — 2 ед.',
    );
    expect(
      thresholdsLabel(const AppSettings(expiryWarningDays: 14)),
      'Срок — за 14 дней · остаток — 2 ед.',
    );
    expect(switchLabel(true), 'Вкл.');
    expect(timeLabel(9 * 60 + 5), '9:05');
  });

  test('digest schedule label and the next digest', () {
    const weekly = AppSettings();
    expect(digestScheduleLabel(weekly), 'Вс, 10:00');
    expect(
      digestScheduleLabel(const AppSettings(digestEnabled: false)),
      'Выкл.',
    );
    expect(
      digestWhenLabel(const AppSettings(digestEnabled: false)),
      'Вс, 10:00',
    );
    expect(nextDigest(weekly, now), DateTime(2026, 11, 8, 10));
    expect(
      nextDigestLabel(nextDigest(weekly, now)),
      'Следующая — вс, 8 ноября, 10:00',
    );
    // Same weekday, time already passed → a week later.
    expect(
      nextDigest(const AppSettings(digestWeekday: DateTime.thursday), now),
      DateTime(2026, 11, 12, 10),
    );
    const daily = AppSettings(
      digestFrequency: DigestFrequency.daily,
      digestMinutes: 18 * 60,
    );
    expect(digestScheduleLabel(daily), 'Каждый день, 18:00');
    expect(nextDigest(daily, now), DateTime(2026, 11, 5, 18));
    const monthly = AppSettings(digestFrequency: DigestFrequency.monthly);
    expect(digestScheduleLabel(monthly), '1-го числа, 10:00');
    expect(nextDigest(monthly, now), DateTime(2026, 12, 1, 10));
    expect(
      nextDigest(monthly, DateTime(2026, 12, 1, 9)),
      DateTime(2026, 12, 1, 10),
    );
  });

  test('threshold matches count soon expiry and low stock once each', () {
    final matches = thresholdMatches(
      state([
        package('soon', expiry: DateTime(2026, 11, 20)),
        package('soon-and-low', quantity: 1, expiry: DateTime(2026, 11, 25)),
        package('low', quantity: 2, expiry: DateTime(2028)),
        package('empty', quantity: 0, expiry: DateTime(2028)),
        package('level', level: StockLevel.almostEmpty, expiry: DateTime(2028)),
        package('device', quantity: 1, tracksStock: false),
        package('fine', expiry: DateTime(2028)),
        package('expired', expiry: DateTime(2026, 10)),
      ]),
      now,
    );
    expect(matches.total, 4);
    expect(matches.soon, 2);
    expect(matches.low, 3);
    expect(matches.title, '4 упаковки');
    expect(matches.details, '2 — срок истекает · 3 — мало осталось');

    final stricter = thresholdMatches(
      state([
        package('low', quantity: 2, expiry: DateTime(2028)),
      ], settings: const AppSettings(lowStockThreshold: 1)),
      now,
    );
    expect(stricter.total, 0);
  });

  test('backup summary, file name and contents label', () {
    final summary = BackupSummary.of(
      state(
        [package('a'), package('b')],
        records: [
          IntakeRecord(
            reminderId: 'r',
            occurredAt: DateTime(2026, 9, 3),
            scheduledDate: DateTime(2026, 9, 1),
            status: IntakeStatus.taken,
          ),
          IntakeRecord(
            reminderId: 'r',
            occurredAt: DateTime(2026, 10, 1),
            status: IntakeStatus.taken,
          ),
        ],
      ),
    );
    expect(summary.kits, 1);
    expect(summary.packages, 2);
    expect(summary.historyLabel(now), 'с 1 сентября');
    expect(summary.historyLabel(DateTime(2027, 1, 1)), 'с 1 сентября 2026');
    expect(
      summary.contentsLabel,
      '1 аптечка, 2 упаковки, 0 курсов и история приёма',
    );
    expect(
      BackupSummary.of(state([])).contentsLabel,
      '1 аптечка, 0 упаковок и 0 курсов',
    );
    expect(BackupSummary.of(state([])).historyLabel(now), 'нет');
    expect(
      BackupCodec.fileName(DateTime(2026, 11, 6, 10, 30)),
      'aptechkin-2026-11-06.json',
    );
    expect(savedAtLabel(DateTime(2026, 11, 6, 10, 30)), '6 ноября, 10:30');
    expect(lastBackupLabel(null, now), 'Нет');
    expect(lastBackupLabel(DateTime(2026, 11, 5, 8), now), 'Сегодня');
    expect(lastBackupLabel(DateTime(2026, 11, 1), now), '1 ноября');
  });

  test('backup keeps digest settings and reads older copies without them', () {
    final original = state(
      [package('a', expiry: DateTime(2028))],
      settings: const AppSettings(
        digestEnabled: false,
        digestFrequency: DigestFrequency.daily,
        digestWeekday: DateTime.monday,
        digestMinutes: 8 * 60 + 30,
      ),
    );
    final created = DateTime(2026, 11, 6, 10, 30);
    final file = BackupCodec.decodeFile(
      BackupCodec.encode(original, createdAt: created),
    );
    expect(file.createdAt, created);
    expect(file.state.settings.toJson(), original.settings.toJson());

    // A copy made before the digest settings existed.
    String envelope(Map<String, Object?> data) => jsonEncode({
      'app': 'aptechka',
      'version': 1,
      'createdAt': created.toIso8601String(),
      'data': data,
    });
    final legacySettings = const AppSettings().toJson()
      ..removeWhere((key, _) => AppSettings.optionalJsonKeys.contains(key));
    final legacy = original.copyWith(settings: const AppSettings()).toJson()
      ..['settings'] = legacySettings;
    final restored = BackupCodec.decodeFile(envelope(legacy)).state.settings;
    expect(restored.digestEnabled, isTrue);
    expect(restored.digestFrequency, DigestFrequency.weekly);
    expect(restored.digestWeekday, DateTime.sunday);
    expect(restored.digestMinutes, 600);

    // An unknown value of a known key is still rejected.
    final broken = original.toJson()
      ..['settings'] = {...original.settings.toJson(), 'digestWeekday': 9};
    expect(() => BackupCodec.decode(envelope(broken)), throwsFormatException);
  });
}
