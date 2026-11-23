import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';

/// Expiry overview of one kit, as shown on the «kit card».
class KitSummary {
  const KitSummary({
    required this.total,
    required this.expired,
    required this.soon,
  });

  final int total;
  final int expired;
  final int soon;
}

/// Pure state transitions for kits. The controller only persists results,
/// so these rules are unit-testable without Riverpod or storage.
extension KitOperations on AppState {
  Pharmacy? kitById(String id) =>
      pharmacies.where((item) => item.id == id).firstOrNull;

  KitSummary summaryOf(String pharmacyId, DateTime now) {
    final items = medicinesIn(pharmacyId);
    var expired = 0;
    var soon = 0;
    for (final item in items) {
      switch (item.statusAt(now, warningDays: settings.expiryWarningDays)) {
        case MedicineStatus.expired:
          expired++;
        case MedicineStatus.expiringSoon:
          soon++;
        case MedicineStatus.okay || MedicineStatus.unknown:
          break;
      }
    }
    return KitSummary(total: items.length, expired: expired, soon: soon);
  }

  /// Kit names are unique per profile, compared without case and spaces.
  bool isKitNameTaken(String name, {String? exceptId}) {
    final normalized = name.trim().toLowerCase();
    return pharmacies.any(
      (item) => item.id != exceptId && item.name.trim().toLowerCase() == normalized,
    );
  }

  AppState addKit(Pharmacy kit) => copyWith(
    pharmacies: [...pharmacies, kit],
    selectedPharmacyId: kit.id,
  );

  AppState updateKit(Pharmacy kit) => copyWith(
    pharmacies: [
      for (final item in pharmacies) item.id == kit.id ? kit : item,
    ],
  );

  /// Marks a kit as changed «now» for the «Проверено …» line.
  AppState touchKit(String id, DateTime now) => copyWith(
    pharmacies: [
      for (final item in pharmacies)
        item.id == id ? item.copyWith(checkedAt: now) : item,
    ],
  );

  /// Deletes a kit. With [moveTo] its packages move to that kit; otherwise
  /// they are removed together with their schedules and intake history.
  AppState deleteKit(String id, {String? moveTo, DateTime? now}) {
    final remaining = pharmacies.where((item) => item.id != id).toList();
    final removedIds = moveTo == null
        ? medicines
              .where((item) => item.pharmacyId == id)
              .map((item) => item.id)
              .toSet()
        : const <String>{};
    final removedReminders = reminders
        .where((item) => removedIds.contains(item.medicineId))
        .map((item) => item.id)
        .toSet();
    final nextSelected = selectedPharmacyId == id
        ? (moveTo ?? remaining.firstOrNull?.id ?? '')
        : selectedPharmacyId;
    var result = AppState(
      pharmacies: remaining,
      selectedPharmacyId: nextSelected,
      medicines: [
        for (final item in medicines)
          if (item.pharmacyId != id)
            item
          else if (moveTo != null)
            item.copyWith(pharmacyId: moveTo),
      ],
      reminders: reminders
          .where((item) => !removedReminders.contains(item.id))
          .toList(),
      intakeRecords: intakeRecords
          .where((item) => !removedReminders.contains(item.reminderId))
          .toList(),
      courses: courses,
      treatmentShoppingIds: treatmentShoppingIds
          .where((item) => !removedIds.contains(item))
          .toList(),
      settings: settings.defaultPharmacyId == id
          ? settings.copyWith(clearDefaultPharmacy: true)
          : settings,
      profileScopeId: profileScopeId,
    );
    if (moveTo != null && now != null) result = result.touchKit(moveTo, now);
    return result;
  }
}

/// «Проверено …» wording from the «kit card» description: сегодня, вчера,
/// N дней / недель / месяцев назад, больше года назад.
String checkedAgoLabel(DateTime? checkedAt, DateTime now) {
  if (checkedAt == null) return 'Ещё не проверяли';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(checkedAt.year, checkedAt.month, checkedAt.day);
  final days = today.difference(day).inDays;
  String plural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return '$n $one';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$n $few';
    }
    return '$n $many';
  }

  final String ago;
  if (days <= 0) {
    ago = 'сегодня';
  } else if (days == 1) {
    ago = 'вчера';
  } else if (days < 7) {
    ago = '${plural(days, 'день', 'дня', 'дней')} назад';
  } else if (days < 31) {
    ago = '${plural(days ~/ 7, 'неделю', 'недели', 'недель')} назад';
  } else if (days < 365) {
    final months = (days / 30.44).floor().clamp(1, 11);
    ago = '${plural(months, 'месяц', 'месяца', 'месяцев')} назад';
  } else {
    ago = 'больше года назад';
  }
  return 'Проверено $ago';
}

/// Storage places and moving packages between kits.
extension PlaceOperations on AppState {
  /// Places of a kit in the user's order, followed by locations that are
  /// used by packages but not yet listed (records from older versions).
  List<String> placesOf(String kitId) {
    final listed = kitById(kitId)?.places ?? const <String>[];
    final used = medicinesIn(kitId)
        .map((item) => item.location.trim())
        .where((item) => item.isNotEmpty && !listed.contains(item))
        .toSet();
    return [...listed, ...used];
  }

  int countAt(String kitId, String place) => medicinesIn(
    kitId,
  ).where((item) => item.location.trim() == place.trim()).length;

  bool isPlaceTaken(String kitId, String name, {String? except}) {
    final normalized = name.trim().toLowerCase();
    return placesOf(kitId).any(
      (item) => item != except && item.toLowerCase() == normalized,
    );
  }

  AppState _withPlaces(String kitId, List<String> places) {
    final kit = kitById(kitId);
    return kit == null ? this : updateKit(kit.copyWith(places: places));
  }

  AppState addPlace(String kitId, String name) =>
      _withPlaces(kitId, [...placesOf(kitId), name.trim()]);

  AppState reorderPlaces(String kitId, List<String> ordered) =>
      _withPlaces(kitId, ordered);

  /// Renames a place and every package stored there.
  AppState renamePlace(String kitId, String from, String to) {
    final name = to.trim();
    return _withPlaces(kitId, [
      for (final item in placesOf(kitId)) item == from ? name : item,
    ]).copyWith(
      medicines: [
        for (final item in medicines)
          item.pharmacyId == kitId && item.location.trim() == from
              ? item.copyWith(location: name)
              : item,
      ],
    );
  }

  /// Removes a place; its packages stay in the kit with «Место не указано».
  AppState deletePlace(String kitId, String place) =>
      _withPlaces(kitId, [
        for (final item in placesOf(kitId))
          if (item != place) item,
      ]).copyWith(
        medicines: [
          for (final item in medicines)
            item.pharmacyId == kitId && item.location.trim() == place
                ? item.copyWith(location: '')
                : item,
        ],
      );

  /// Moves one package to another kit and/or place.
  AppState movePackage(
    String medicineId, {
    required String kitId,
    required String place,
    DateTime? now,
  }) {
    final package = medicines.where((item) => item.id == medicineId).firstOrNull;
    if (package == null || kitById(kitId) == null) return this;
    var result = copyWith(
      medicines: [
        for (final item in medicines)
          item.id == medicineId
              ? item.copyWith(
                  pharmacyId: kitId,
                  location: place.trim(),
                  updatedAt: now,
                )
              : item,
      ],
    );
    if (place.trim().isNotEmpty &&
        !result.placesOf(kitId).contains(place.trim())) {
      result = result.addPlace(kitId, place);
    }
    if (now != null) {
      result = result.touchKit(package.pharmacyId, now).touchKit(kitId, now);
    }
    return result;
  }
}

/// Edits of one package. Every edit stamps «изменено» and touches the kit.
extension PackageOperations on AppState {
  /// Applies [edit] to the package [id]. [stock] also stamps the
  /// remainder's «обновлено».
  AppState editPackage(
    String id,
    Medicine Function(Medicine package) edit,
    DateTime now, {
    bool stock = false,
  }) {
    final package = medicines.where((item) => item.id == id).firstOrNull;
    if (package == null) return this;
    return copyWith(
      medicines: [
        for (final item in medicines)
          item.id == id
              ? edit(item).copyWith(
                  updatedAt: now,
                  stockUpdatedAt: stock ? now : null,
                )
              : item,
      ],
    ).touchKit(package.pharmacyId, now);
  }

  /// Removes the packages [ids] with their reminders, intake history and
  /// shopping marks; their kits count as checked. «Убрать все
  /// просроченные» (833:7440) removes several at once.
  AppState removePackages(Set<String> ids, DateTime now) {
    final removed = medicines.where((item) => ids.contains(item.id)).toList();
    if (removed.isEmpty) return this;
    final reminderIds = {
      for (final reminder in reminders)
        if (ids.contains(reminder.medicineId)) reminder.id,
    };
    var result = copyWith(
      treatmentShoppingIds: [
        for (final id in treatmentShoppingIds)
          if (!ids.contains(id)) id,
      ],
      medicines: [
        for (final item in medicines)
          if (!ids.contains(item.id)) item,
      ],
      reminders: [
        for (final reminder in reminders)
          if (!ids.contains(reminder.medicineId)) reminder,
      ],
      intakeRecords: [
        for (final record in intakeRecords)
          if (!reminderIds.contains(record.reminderId)) record,
      ],
    );
    for (final kitId in {for (final item in removed) item.pharmacyId}) {
      result = result.touchKit(kitId, now);
    }
    return result;
  }
}

/// The status chips of «Содержимое аптечки» and «3 · Фильтры» (825:4879).
enum InventoryFilter { all, expired, soon, noDate, empty }

/// Whether [package] belongs under [filter].
bool matchesInventoryFilter(
  Medicine package,
  InventoryFilter filter,
  DateTime now, {
  int warningDays = 30,
}) {
  final status = package.statusAt(now, warningDays: warningDays);
  return switch (filter) {
    InventoryFilter.all => true,
    InventoryFilter.expired => status == MedicineStatus.expired,
    InventoryFilter.soon => status == MedicineStatus.expiringSoon,
    InventoryFilter.noDate => status == MedicineStatus.unknown,
    InventoryFilter.empty => package.quantity <= 0,
  };
}
