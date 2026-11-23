import 'package:aptechka/features/accounts/application/account_controller.dart';
import 'package:aptechka/features/accounts/data/local_profile_import.dart';
import 'package:aptechka/features/inventory/data/medicine_repository.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/kit_icon.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/package_detail.dart';
import 'package:aptechka/features/inventory/domain/pharmacy.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/reminders/domain/intake_marks.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends AsyncNotifier<AppState> {
  MedicineRepository? _repository;
  final _uuid = const Uuid();

  @override
  Future<AppState> build() async {
    final scopeId = ref.watch(activeProfileIdProvider);
    final preferences = await SharedPreferences.getInstance();
    _repository = LocalMedicineRepository(preferences, profileScopeId: scopeId);
    return _repository!.load();
  }

  /// Adds a package; returns its id, or `null` when the kit is read-only.
  Future<String?> addMedicine({
    required String name,
    required String form,
    required String dosage,
    required int quantity,
    required String unit,
    DateTime? expiryDate,
    required String location,
    DateTime? openedAt,
    int? afterOpeningDays,
    String? activeIngredient,
    String? gtin,
    String? catalogEntryId,
    String? manufacturer,
    String? packageDescription,
    String? registrationId,
    String? registrationStatus,
    String? catalogVersion,
    bool createReminder = false,
    int reminderHour = 9,
    int reminderMinute = 0,
    String reminderDose = '1 доза',
    String? pharmacyId,
    StockLevel? stockLevel,
    bool tracksStock = true,
    bool noExpiry = false,
    String? notes,
    List<MedicinePurpose> purposes = const [],
    String? customPurpose,
  }) async {
    final current = state.requireValue;
    final kitId = pharmacyId ?? current.selectedPharmacyId;
    if (current.kitById(kitId)?.canEdit != true) return null;
    final medicineId = _uuid.v4();
    final addedAt = DateTime.now();
    final medicine = Medicine(
      id: medicineId,
      pharmacyId: kitId,
      addedAt: addedAt,
      updatedAt: addedAt,
      stockUpdatedAt: addedAt,
      stockLevel: stockLevel,
      tracksStock: tracksStock,
      noExpiry: noExpiry,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      purposes: purposes,
      customPurpose: customPurpose?.trim().isEmpty == true
          ? null
          : customPurpose?.trim(),
      name: name.trim(),
      activeIngredient: activeIngredient?.trim().isEmpty == true
          ? null
          : activeIngredient?.trim(),
      form: form.trim(),
      dosage: dosage.trim(),
      quantity: quantity,
      unit: unit.trim(),
      expiryDate: expiryDate,
      openedAt: openedAt,
      afterOpeningDays: afterOpeningDays,
      location: location.trim(),
      gtin: gtin?.trim().isEmpty == true ? null : gtin?.trim(),
      catalogEntryId: catalogEntryId,
      manufacturer: manufacturer,
      packageDescription: packageDescription,
      registrationId: registrationId,
      registrationStatus: registrationStatus,
      catalogVersion: catalogVersion,
    );
    final updatedReminders = [...current.reminders];
    if (createReminder) {
      updatedReminders.add(
        MedicationReminder(
          id: _uuid.v4(),
          medicineId: medicineId,
          hour: reminderHour,
          minute: reminderMinute,
          dose: reminderDose.trim(),
          enabled: true,
        ),
      );
    }
    final updated = current
        .copyWith(
          medicines: [...current.medicines, medicine],
          reminders: updatedReminders,
        )
        .touchKit(medicine.pharmacyId, DateTime.now());
    await _commit(updated);
    return medicineId;
  }

  Future<void> selectPharmacy(String pharmacyId) async {
    final current = state.requireValue;
    if (!current.pharmacies.any((item) => item.id == pharmacyId)) return;
    final updated = current.copyWith(selectedPharmacyId: pharmacyId);
    await _commit(updated);
  }

  /// Creates a kit and selects it. Returns the new kit id.
  Future<String> createPharmacy(String name, {KitIcon? icon}) async {
    final current = state.requireValue;
    if (current.isKitNameTaken(name)) {
      throw StateError('Аптечка «${name.trim()}» уже есть');
    }
    final pharmacy = Pharmacy(
      id: _uuid.v4(),
      name: name.trim(),
      ownerLabel: 'Вы',
      isShared: false,
      canEdit: true,
      icon: icon ?? KitIcon.suggest(name),
      checkedAt: DateTime.now(),
      ownerAccountId: current.profileScopeId == 'guest'
          ? null
          : current.profileScopeId,
    );
    await _commit(current.addKit(pharmacy));
    return pharmacy.id;
  }

  /// Ensures a kit «Дом» exists and is selected (onboarding entry points).
  Future<void> ensureHomeKit() async {
    final current = state.requireValue;
    final home = current.pharmacies
        .where((item) => item.name.trim().toLowerCase() == 'дом')
        .firstOrNull;
    if (home != null) {
      if (current.selectedPharmacyId != home.id) {
        await selectPharmacy(home.id);
      }
      return;
    }
    await createPharmacy('Дом', icon: KitIcon.home);
  }

  Future<void> updatePharmacy(String id, {String? name, KitIcon? icon}) async {
    final current = state.requireValue;
    final kit = current.kitById(id);
    if (kit == null || !kit.canEdit) return;
    if (name != null && current.isKitNameTaken(name, exceptId: id)) {
      throw StateError('Аптечка «${name.trim()}» уже есть');
    }
    await _commit(
      current.updateKit(kit.copyWith(name: name?.trim(), icon: icon)),
    );
  }

  /// Deletes a kit; packages move to [moveTo] or are removed with it.
  /// Returns the previous state so the caller can offer «Отменить».
  Future<AppState> deletePharmacy(String id, {String? moveTo}) async {
    final current = state.requireValue;
    final kit = current.kitById(id);
    if (kit == null || !kit.isOwn) {
      throw StateError('Удалить можно только свою аптечку');
    }
    if (moveTo != null && current.kitById(moveTo)?.canEdit != true) {
      throw StateError('Выберите аптечку, куда перенести лекарства');
    }
    await _commit(current.deleteKit(id, moveTo: moveTo, now: DateTime.now()));
    return current;
  }

  bool _canEdit(AppState state, String kitId) =>
      state.kitById(kitId)?.canEdit == true;

  /// Sets the remaining amount of one package, keeping its dates.
  Future<void> setQuantity(String medicineId, int quantity) async {
    final current = state.requireValue;
    final package = current.medicines
        .where((item) => item.id == medicineId)
        .firstOrNull;
    if (package == null || !_canEdit(current, package.pharmacyId)) return;
    await _commit(
      current.editPackage(
        medicineId,
        (item) => item.copyWith(quantity: quantity < 0 ? 0 : quantity),
        DateTime.now(),
        stock: true,
      ),
    );
  }

  /// «Осталось примерно» for drops, syrups and creams.
  Future<void> setStockLevel(String medicineId, StockLevel level) =>
      _editPackage(
        medicineId,
        (item) => item.copyWith(stockLevel: level),
        stock: true,
      );

  /// «Для чего» from the package card.
  /// «Для чего»: several marks and «Свой вариант» ('' clears it).
  Future<void> setPurposes(
    String medicineId,
    List<MedicinePurpose> purposes, {
    String custom = '',
  }) => _editPackage(
    medicineId,
    (item) => item.copyWith(purposes: purposes, customPurpose: custom),
  );

  /// «Добавить заметку» from the package card; an empty note removes it.
  Future<void> setNotes(String medicineId, String notes) => _editPackage(
    medicineId,
    (item) => item.copyWith(notes: notes.trim()),
  );

  /// «Отметить вскрытие»: opened on [openedAt] (today by default), usable
  /// for [afterOpeningDays] days after that.
  Future<void> openPackage(
    String medicineId,
    int? afterOpeningDays, {
    DateTime? openedAt,
  }) {
    final day = openedAt ?? DateTime.now();
    return _editPackage(
      medicineId,
      (item) => item.copyWith(
        openedAt: DateTime(day.year, day.month, day.day),
        afterOpeningDays: afterOpeningDays,
        // «Не знаю»: opened, the term after opening is not known.
        clearAfterOpeningDays: afterOpeningDays == null,
      ),
    );
  }

  /// «Указать срок» after opening.
  Future<void> setAfterOpeningDays(String medicineId, int afterOpeningDays) =>
      _editPackage(
        medicineId,
        (item) => item.copyWith(afterOpeningDays: afterOpeningDays),
      );

  /// «Указать срок» from the package card.
  Future<void> setExpiry(String medicineId, DateTime expiryDate) =>
      _editPackage(
        medicineId,
        (item) => item.copyWith(expiryDate: expiryDate, noExpiry: false),
      );

  Future<void> _editPackage(
    String medicineId,
    Medicine Function(Medicine package) edit, {
    bool stock = false,
  }) async {
    final current = state.requireValue;
    final package = current.medicines
        .where((item) => item.id == medicineId)
        .firstOrNull;
    if (package == null || !_canEdit(current, package.pharmacyId)) return;
    await _commit(
      current.editPackage(medicineId, edit, DateTime.now(), stock: stock),
    );
  }

  Future<void> movePackage(
    String medicineId, {
    required String kitId,
    required String place,
  }) async {
    final current = state.requireValue;
    final package = current.medicines
        .where((item) => item.id == medicineId)
        .firstOrNull;
    if (package == null ||
        !_canEdit(current, package.pharmacyId) ||
        !_canEdit(current, kitId)) {
      throw StateError('В эту аптечку нельзя переложить упаковку');
    }
    await _commit(
      current.movePackage(
        medicineId,
        kitId: kitId,
        place: place,
        now: DateTime.now(),
      ),
    );
  }

  Future<void> addPlace(String kitId, String name) async {
    final current = state.requireValue;
    if (!_canEdit(current, kitId) || name.trim().isEmpty) return;
    if (current.isPlaceTaken(kitId, name)) {
      throw StateError('Место «${name.trim()}» уже есть');
    }
    await _commit(current.addPlace(kitId, name));
  }

  Future<void> renamePlace(String kitId, String from, String to) async {
    final current = state.requireValue;
    if (!_canEdit(current, kitId) || to.trim().isEmpty) return;
    if (current.isPlaceTaken(kitId, to, except: from)) {
      throw StateError('Место «${to.trim()}» уже есть');
    }
    await _commit(current.renamePlace(kitId, from, to));
  }

  Future<void> deletePlace(String kitId, String place) async {
    final current = state.requireValue;
    if (!_canEdit(current, kitId)) return;
    await _commit(current.deletePlace(kitId, place));
  }

  Future<void> reorderPlaces(String kitId, List<String> ordered) async {
    final current = state.requireValue;
    if (!_canEdit(current, kitId)) return;
    await _commit(current.reorderPlaces(kitId, ordered));
  }

  /// Restores a snapshot returned by a destructive action (undo).
  Future<void> restoreSnapshot(AppState snapshot) => _commit(
    snapshot.copyWith(settings: state.requireValue.settings),
  );

  Future<void> updatePackage({
    required String medicineId,
    int? quantity,
    String? location,
    DateTime? expiryDate,
    DateTime? openedAt,
    int? afterOpeningDays,
  }) async {
    final current = state.requireValue;
    final package = current.medicines
        .where((item) => item.id == medicineId)
        .firstOrNull;
    if (package == null) return;
    final pharmacy = current.pharmacies
        .where((item) => item.id == package.pharmacyId)
        .firstOrNull;
    if (pharmacy?.canEdit != true) return;
    await _commit(
      current.editPackage(
        medicineId,
        (item) => item.copyWith(
          quantity: quantity,
          location: location,
          expiryDate: expiryDate,
          clearExpiryDate: expiryDate == null,
          openedAt: openedAt,
          clearOpenedAt: openedAt == null,
          afterOpeningDays: afterOpeningDays,
          clearAfterOpeningDays: afterOpeningDays == null,
        ),
        DateTime.now(),
        stock: quantity != null && quantity != package.quantity,
      ),
    );
  }

  /// «Изменить упаковку» (894:18072): every field of the form at once,
  /// including another kit.
  Future<void> replacePackage(Medicine updated) async {
    final current = state.requireValue;
    final package = current.medicines
        .where((item) => item.id == updated.id)
        .firstOrNull;
    if (package == null) return;
    if (!_canEdit(current, package.pharmacyId) ||
        !_canEdit(current, updated.pharmacyId)) {
      throw StateError('Эту упаковку нельзя изменить');
    }
    final now = DateTime.now();
    final stock =
        package.quantity != updated.quantity ||
        package.stockLevel != updated.stockLevel ||
        package.tracksStock != updated.tracksStock;
    var next = current.editPackage(
      updated.id,
      (_) => updated,
      now,
      stock: stock,
    );
    if (package.pharmacyId != updated.pharmacyId) {
      next = next.touchKit(updated.pharmacyId, now);
    }
    await _commit(next);
  }

  Future<void> setTreatmentShopping(Set<String> ids) =>
      _commit(state.requireValue.copyWith(treatmentShoppingIds: ids.toList()));

  Future<void> saveCourse(
    TreatmentCourse course,
    List<MedicationReminder> reminders,
  ) async {
    final current = state.requireValue;
    if (course.name.trim().isEmpty || reminders.isEmpty) {
      throw StateError('Добавьте название и препарат');
    }
    for (final reminder in reminders) {
      if (!current.medicines.any((m) => m.id == reminder.medicineId)) {
        throw StateError('Препарат больше не находится в аптечке');
      }
    }
    final keptIds = reminders.map((r) => r.id).toSet();
    final removedIds = current.reminders
        .where((r) => r.courseId == course.id && !keptIds.contains(r.id))
        .map((r) => r.id)
        .toSet();
    // Preserve older schedules with history, but disable them when editing a course.
    final historical = current.reminders
        .where(
          (r) =>
              removedIds.contains(r.id) &&
              current.intakeRecords.any((i) => i.reminderId == r.id),
        )
        .map((r) => r.copyWith(enabled: false));
    await _commit(
      current.copyWith(
        courses: [...current.courses.where((c) => c.id != course.id), course],
        reminders: [
          ...current.reminders.where((r) => r.courseId != course.id),
          ...historical,
          ...reminders,
        ],
      ),
    );
  }

  Future<void> updateCourse(TreatmentCourse course) => _commit(
    state.requireValue.copyWith(
      courses: state.requireValue.courses
          .map((c) => c.id == course.id ? course : c)
          .toList(),
    ),
  );

  Future<void> deleteCourse(String id) async {
    final current = state.requireValue;
    final ids = current.reminders
        .where((r) => r.courseId == id)
        .map((r) => r.id)
        .toSet();
    await _commit(
      current.copyWith(
        courses: current.courses.where((c) => c.id != id).toList(),
        reminders: current.reminders.where((r) => !ids.contains(r.id)).toList(),
        intakeRecords: current.intakeRecords
            .where((r) => !ids.contains(r.reminderId))
            .toList(),
      ),
    );
  }

  Future<void> recordIntake(
    String reminderId,
    IntakeStatus status, {
    DateTime? scheduledDate,
    DateTime? occurredAt,
    DateTime? deferredUntil,
    String reason = '',
  }) async {
    final current = state.requireValue;
    final reminder = current.reminders
        .where((r) => r.id == reminderId)
        .firstOrNull;
    if (reminder == null) return;
    final day = treatmentDay(scheduledDate ?? DateTime.now());
    if (day.isAfter(treatmentDay(DateTime.now()))) {
      throw StateError('Будущий приём пока нельзя отметить');
    }
    final old = current.intakeRecords
        .where((r) => r.reminderId == reminderId && r.day == day)
        .firstOrNull;
    final medicine = current.medicines
        .where((m) => m.id == reminder.medicineId)
        .firstOrNull;
    final available = (medicine?.quantity ?? 0) + (old?.stockDelta ?? 0);
    // Only identical stock/dose units; drops cannot be subtracted from a bottle.
    final canDeduct =
        medicine != null && intakeDeductsStock(reminder, medicine);
    final delta = status == IntakeStatus.taken && canDeduct
        ? reminder.amount.clamp(0, available)
        : 0;
    await _commit(
      current.copyWith(
        medicines: current.medicines
            .map(
              (m) => m.id == reminder.medicineId
                  ? m.copyWith(quantity: available - delta)
                  : m,
            )
            .toList(),
        intakeRecords: [
          ...current.intakeRecords.where(
            (r) => r.reminderId != reminderId || r.day != day,
          ),
          IntakeRecord(
            reminderId: reminderId,
            scheduledDate: day,
            occurredAt: occurredAt ?? DateTime.now(),
            status: status,
            deferredUntil: deferredUntil,
            reason: reason,
            stockDelta: delta,
          ),
        ],
      ),
    );
  }

  /// «Отменить факт приёма»: removes the mark and returns deducted units.
  Future<void> undoIntake(String reminderId, DateTime day) =>
      _commit(withoutIntake(state.requireValue, reminderId, day));

  /// Removes a package; returns the previous state for «Отменить».
  Future<AppState> removePackage(String medicineId) async {
    final current = state.requireValue;
    final package = current.medicines
        .where((item) => item.id == medicineId)
        .firstOrNull;
    if (package == null) return current;
    final pharmacy = current.pharmacies
        .where((item) => item.id == package.pharmacyId)
        .firstOrNull;
    if (pharmacy?.canEdit != true) return current;
    await _commit(current.removePackages({medicineId}, DateTime.now()));
    return current;
  }

  /// «Убрать все просроченные»: removes the packages the user may edit and
  /// returns the previous state for «Отменить».
  Future<AppState> removePackages(Iterable<String> ids) async {
    final current = state.requireValue;
    final editable = {
      for (final item in current.medicines)
        if (ids.contains(item.id) && _canEdit(current, item.pharmacyId))
          item.id,
    };
    if (editable.isEmpty) return current;
    await _commit(current.removePackages(editable, DateTime.now()));
    return current;
  }

  Future<void> _commit(AppState updated) async {
    final scopeId = updated.profileScopeId;
    if (scopeId != ref.read(activeProfileIdProvider)) {
      throw StateError('Профиль изменился. Повторите действие.');
    }
    final repository = _repository!;
    await repository.save(updated);
    if (ref.read(activeProfileIdProvider) == scopeId) {
      state = AsyncData(updated);
    }
  }

  Future<void> updateSettings(AppSettings settings) =>
      _commit(state.requireValue.copyWith(settings: settings));

  Future<void> restoreBackup(AppState backup) {
    final scopeId = state.requireValue.profileScopeId;
    return _commit(
      backup.copyWith(
        profileScopeId: scopeId,
        pharmacies: backup.pharmacies
            .map((item) => scopeId == 'guest' ? item : item.withOwner(scopeId))
            .toList(),
      ),
    );
  }

  Future<AppState> guestData() async =>
      LocalMedicineRepository(await SharedPreferences.getInstance()).load();

  Future<void> copyGuestPharmacies(Set<String> ids) async {
    final current = state.requireValue;
    if (current.profileScopeId == 'guest') {
      throw StateError('Сначала войдите в демо-профиль');
    }
    final guest = await guestData();
    await _commit(
      LocalProfileImport.copy(guest: guest, target: current, pharmacyIds: ids),
    );
  }

  Future<void> clearInventory() => _commit(
    state.requireValue.copyWith(
      medicines: const [],
      courses: const [],
      treatmentShoppingIds: const [],
      reminders: const [],
      intakeRecords: const [],
    ),
  );

  Future<void> setReminderEnabled(String id, bool enabled) {
    final current = state.requireValue;
    return _commit(
      current.copyWith(
        reminders: current.reminders
            .map(
              (item) => item.id != id ? item : item.copyWith(enabled: enabled),
            )
            .toList(),
      ),
    );
  }
}
