enum AppAppearance { system, light, dark }

enum InventorySort { name, expiry }

/// «Как часто» of the kit digest (1157:24312).
enum DigestFrequency { daily, weekly, monthly }

class AppSettings {
  const AppSettings({
    this.appearance = AppAppearance.system,
    this.textScale = 1,
    this.expiryWarningDays = 30,
    this.expiryAlerts = true,
    this.stockAlerts = true,
    this.lowStockThreshold = 2,
    this.intakeSchedule = true,
    this.inventorySort = InventorySort.name,
    this.defaultPharmacyId,
    this.digestEnabled = true,
    this.digestFrequency = DigestFrequency.weekly,
    this.digestWeekday = DateTime.sunday,
    this.digestMinutes = 10 * 60,
  });

  /// Allowed values of the «Когда предупреждать» chips (1157:24437).
  static const expiryWarningChoices = [7, 14, 30, 60, 90];
  static const lowStockChoices = [1, 2, 3, 5, 10];

  /// «Размер текста» (1159:24373): как на устройстве, крупнее, ещё крупнее.
  static const textScaleChoices = [1.0, 1.15, 1.3];

  final AppAppearance appearance;
  final double textScale;
  final int expiryWarningDays;
  final bool expiryAlerts;
  final bool stockAlerts;
  final int lowStockThreshold;
  final bool intakeSchedule;
  final InventorySort inventorySort;
  final String? defaultPharmacyId;

  /// «Сводка по аптечкам» (1157:24014).
  final bool digestEnabled;
  final DigestFrequency digestFrequency;

  /// 1 = понедельник … 7 = воскресенье, as [DateTime.weekday].
  final int digestWeekday;

  /// Minutes after midnight.
  final int digestMinutes;

  AppSettings copyWith({
    AppAppearance? appearance,
    double? textScale,
    int? expiryWarningDays,
    bool? expiryAlerts,
    bool? stockAlerts,
    int? lowStockThreshold,
    bool? intakeSchedule,
    InventorySort? inventorySort,
    String? defaultPharmacyId,
    bool clearDefaultPharmacy = false,
    bool? digestEnabled,
    DigestFrequency? digestFrequency,
    int? digestWeekday,
    int? digestMinutes,
  }) => AppSettings(
    appearance: appearance ?? this.appearance,
    textScale: textScale ?? this.textScale,
    expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
    expiryAlerts: expiryAlerts ?? this.expiryAlerts,
    stockAlerts: stockAlerts ?? this.stockAlerts,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    intakeSchedule: intakeSchedule ?? this.intakeSchedule,
    inventorySort: inventorySort ?? this.inventorySort,
    defaultPharmacyId: clearDefaultPharmacy
        ? null
        : defaultPharmacyId ?? this.defaultPharmacyId,
    digestEnabled: digestEnabled ?? this.digestEnabled,
    digestFrequency: digestFrequency ?? this.digestFrequency,
    digestWeekday: digestWeekday ?? this.digestWeekday,
    digestMinutes: digestMinutes ?? this.digestMinutes,
  );

  Map<String, Object?> toJson() => {
    'appearance': appearance.name,
    'textScale': textScale,
    'expiryWarningDays': expiryWarningDays,
    'expiryAlerts': expiryAlerts,
    'stockAlerts': stockAlerts,
    'lowStockThreshold': lowStockThreshold,
    'intakeSchedule': intakeSchedule,
    'inventorySort': inventorySort.name,
    'defaultPharmacyId': defaultPharmacyId,
    'digestEnabled': digestEnabled,
    'digestFrequency': digestFrequency.name,
    'digestWeekday': digestWeekday,
    'digestMinutes': digestMinutes,
  };

  /// Keys added after backup version 1 was published. Older backups do not
  /// have them, and [AppSettings.fromJson] fills the defaults.
  static const optionalJsonKeys = {
    'digestEnabled',
    'digestFrequency',
    'digestWeekday',
    'digestMinutes',
  };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    appearance:
        AppAppearance.values
            .where((value) => value.name == json['appearance'])
            .firstOrNull ??
        AppAppearance.system,
    textScale: textScaleChoices.contains(json['textScale'])
        ? (json['textScale'] as num).toDouble()
        : 1,
    expiryWarningDays: expiryWarningChoices.contains(json['expiryWarningDays'])
        ? json['expiryWarningDays'] as int
        : 30,
    expiryAlerts: json['expiryAlerts'] is bool
        ? json['expiryAlerts'] as bool
        : true,
    stockAlerts: json['stockAlerts'] is bool
        ? json['stockAlerts'] as bool
        : true,
    lowStockThreshold: lowStockChoices.contains(json['lowStockThreshold'])
        ? json['lowStockThreshold'] as int
        : 2,
    intakeSchedule: json['intakeSchedule'] is bool
        ? json['intakeSchedule'] as bool
        : true,
    inventorySort:
        InventorySort.values
            .where((value) => value.name == json['inventorySort'])
            .firstOrNull ??
        InventorySort.name,
    defaultPharmacyId: json['defaultPharmacyId'] is String
        ? json['defaultPharmacyId'] as String
        : null,
    digestEnabled: json['digestEnabled'] is bool
        ? json['digestEnabled'] as bool
        : true,
    digestFrequency:
        DigestFrequency.values
            .where((value) => value.name == json['digestFrequency'])
            .firstOrNull ??
        DigestFrequency.weekly,
    digestWeekday:
        json['digestWeekday'] is int &&
            (json['digestWeekday'] as int) >= 1 &&
            (json['digestWeekday'] as int) <= 7
        ? json['digestWeekday'] as int
        : DateTime.sunday,
    digestMinutes:
        json['digestMinutes'] is int &&
            (json['digestMinutes'] as int) >= 0 &&
            (json['digestMinutes'] as int) < 24 * 60
        ? json['digestMinutes'] as int
        : 10 * 60,
  );
}
