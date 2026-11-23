import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/action_group.dart';
import 'package:aptechka/core/ui/app_alert.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_chip.dart';
import 'package:aptechka/core/ui/app_field.dart';
import 'package:aptechka/core/ui/app_segmented.dart';
import 'package:aptechka/core/ui/app_select.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/core/ui/form_section.dart';
import 'package:aptechka/core/ui/nav_bars.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/core/ui/stock_control.dart';
import 'package:aptechka/core/ui/switch_row.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/data/drug_photo_catalog.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/drug_catalog_variant.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/package_form.dart';
import 'package:aptechka/features/inventory/domain/package_status.dart';
import 'package:aptechka/features/inventory/presentation/add_medicine_sheets.dart';
import 'package:aptechka/features/inventory/presentation/drug_name_field.dart';
import 'package:aptechka/features/inventory/presentation/inventory_sheets.dart';
import 'package:aptechka/features/inventory/presentation/widgets/catalog_item.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/medicines/domain/medicine_purpose.dart';
import 'package:aptechka/features/medicines/domain/stock_level.dart';
import 'package:aptechka/features/onboarding/data/onboarding_store.dart';
import 'package:aptechka/features/scanner/application/add_batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What «Изменить упаковку» returns besides `true` (saved).
enum PackageEditResult {
  /// «Убрать из аптечки»: the card runs its removal sheet.
  remove,
}

/// «Добавление препарата · 2 · Форма упаковки» (890:15547); with [editId]
/// it is «Изменение / Изменить упаковку» (894:18072).
class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({
    this.editId,
    this.initialEntry,
    this.initialVariant,
    this.catalogGtin,
    this.catalogGtins,
    this.scannedGtin,
    this.initialName,
    this.scannedExpiry,
    this.scanSource,
    this.batch = false,
    super.key,
  });

  /// The package to edit; `null` adds a new one.
  final String? editId;

  /// Opened by «Подробнее» on the scanner's quick card (890:15548): saving
  /// adds the package to the batch and goes back to the camera.
  final bool batch;

  /// Expiry read from a DataMatrix code (GS1 AI 17).
  final DateTime? scannedExpiry;

  /// `dataMatrix` or `barcode` when the form opens after a scan.
  final String? scanSource;

  final DrugCatalogEntry? initialEntry;
  final String? catalogGtin;
  final DrugCatalogVariant? initialVariant;
  final List<String>? catalogGtins;
  final String? scannedGtin;
  final String? initialName;

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _name = TextEditingController();
  final _dosage = TextEditingController();
  DrugCatalogEntry? _selectedEntry;
  DrugCatalogVariant? _selectedVariant;

  /// «Изменить» on the catalog item: name, dosage and form become editable.
  bool _editingDrug = false;
  String _form = '';
  String _unit = '';
  String? _gtin;

  /// Pieces in a whole package, when the catalog says so.
  int? _packageSize;
  bool _started = false;
  int _quantity = 1;
  bool _quantityEdited = false;
  StockLevel _level = StockLevel.full;
  bool _countDevice = false;

  ExpiryChoice _expiryChoice = ExpiryChoice.date;
  DateTime? _expiry;

  bool _opened = false;
  DateTime? _openedAt;
  int? _afterOpeningDays;

  String? _kitId;

  /// `null` until the kit is known: then the first place is suggested.
  String? _place;

  List<MedicinePurpose> _purposes = const [];
  String _customPurpose = '';
  String _notes = '';

  bool _submitted = false;
  bool _saving = false;
  int _catalogRevision = 0;

  /// The package being edited.
  Medicine? _original;

  /// [_signature] when the edit form opened: «Выйти без сохранения?» is
  /// asked only after a change.
  String? _initialSignature;

  bool get _editing => widget.editId != null;

  /// The edit form waits for the saved package (a cold start on its URL).
  bool _loading = false;

  StockMode get _mode => stockModeFor(_form, unit: _unit);

  bool get _catalogMode => _selectedEntry != null && !_editingDrug;

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) {
      Medicine? find(AppState state) => state.medicines
          .where((item) => item.id == widget.editId)
          .firstOrNull;
      final loaded = ref.read(appControllerProvider).asData?.value;
      if (loaded != null) {
        if (find(loaded) case final package?) _fillFromPackage(package);
        return;
      }
      _loading = true;
      ref.read(appControllerProvider.future).then((state) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          if (find(state) case final package?) _fillFromPackage(package);
        });
      });
      return;
    }
    _name.text = readableDrugName(widget.initialName ?? '');
    final entry = widget.initialEntry;
    final variant = widget.initialVariant;
    _expiry = widget.scannedExpiry;
    if (widget.scannedGtin != null) {
      _gtin = widget.scannedGtin;
      _resolveScannedGtin(widget.scannedGtin!, _catalogRevision);
    } else if (variant != null) {
      _fillEntry(variant.entry, variant: variant);
    } else if (entry != null) {
      _fillEntry(entry);
    } else if (widget.catalogGtin != null ||
        widget.catalogGtins?.isNotEmpty == true) {
      _restoreCatalogSelection();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    super.dispose();
  }

  /// «Изменить упаковку»: every field from the saved package.
  void _fillFromPackage(Medicine package) {
    _original = package;
    _name.text = readableDrugName(package.name);
    _dosage.text = package.dosage;
    _form = package.form;
    _unit = package.unit;
    _gtin = package.gtin;
    final entryId = package.catalogEntryId;
    if (entryId != null) {
      final entry = DrugCatalogEntry(
        id: entryId,
        gtin: entryId.startsWith('mdlp:') ? entryId.substring(5) : package.gtin,
        name: package.name,
        activeIngredient: package.activeIngredient ?? '',
        form: package.form,
        dosage: package.dosage,
        unit: package.unit,
        manufacturer: package.manufacturer ?? '',
        packageDescription: package.packageDescription ?? '',
        registrationId: package.registrationId ?? '',
        registrationStatus: package.registrationStatus ?? '',
        sourceVersion: package.catalogVersion ?? '',
      );
      _selectedEntry = entry;
      _selectedVariant = DrugCatalogVariant([entry]);
      _name.text = entry.displayName;
      final described = describeDrugPackage(entry);
      final unit = entry.unit.trim().toLowerCase();
      _packageSize =
          described.quantity != null &&
              (unit == described.quantityUnit || unit == 'шт.')
          ? described.quantity
          : null;
    }
    _quantity = package.quantity;
    _quantityEdited = true;
    _level = package.stockLevel ?? StockLevel.full;
    _countDevice = package.tracksStock;
    _started =
        _level != StockLevel.full ||
        (_packageSize != null && _quantity < _packageSize!);
    _expiryChoice = package.noExpiry
        ? ExpiryChoice.none
        : package.expiryDate == null
        ? ExpiryChoice.later
        : ExpiryChoice.date;
    _expiry = package.expiryDate;
    _opened = package.openedAt != null;
    _openedAt = package.openedAt;
    _afterOpeningDays = package.afterOpeningDays;
    _kitId = package.pharmacyId;
    _place = package.location.trim();
    _purposes = package.purposes;
    _customPurpose = package.customPurpose ?? '';
    _notes = package.notes ?? '';
    _initialSignature = _signature;
  }

  String get _signature => [
    _name.text,
    _dosage.text,
    _form,
    _unit,
    _quantity,
    _level,
    _countDevice,
    _expiryChoice,
    _expiry,
    _opened,
    _openedAt,
    _afterOpeningDays,
    _kitId,
    _place,
    _purposes.join(','),
    _customPurpose,
    _notes,
  ].join('|');

  void _fillEntry(DrugCatalogEntry entry, {DrugCatalogVariant? variant}) {
    _selectedEntry = entry;
    _selectedVariant = variant ?? DrugCatalogVariant([entry]);
    _editingDrug = false;
    _name.text = entry.displayName;
    _dosage.text = entry.dosage;
    _form = entry.form;
    _unit = entry.unit;
    _fillPackage(entry);
  }

  /// A new package: the whole amount from the catalog, a full bottle.
  /// An amount the user already set stays.
  void _fillPackage(DrugCatalogEntry? entry) {
    final package = entry == null ? null : describeDrugPackage(entry);
    final unit = entry?.unit.trim().toLowerCase();
    _packageSize =
        package?.quantity != null &&
            (unit == package!.quantityUnit || unit == 'шт.')
        ? package.quantity
        : null;
    _level = StockLevel.full;
    if (_quantityEdited) {
      _started = _packageSize != null && _quantity < _packageSize!;
      return;
    }
    _started = false;
    _quantity = _packageSize ?? 1;
  }

  Future<void> _restoreCatalogSelection() async {
    final revision = _catalogRevision;
    try {
      final codes = widget.catalogGtins ?? [widget.catalogGtin!];
      final service = ref.read(drugCatalogServiceProvider);
      final records = await Future.wait(codes.map(service.findByGtin));
      if (!mounted || revision != _catalogRevision) return;
      final variants = groupDrugCatalogVariants(
        records.whereType<DrugCatalogEntry>(),
      );
      if (records.every((entry) => entry != null) && variants.length == 1) {
        final variant = variants.single;
        setState(() => _fillEntry(variant.entry, variant: variant));
        return;
      }
    } catch (_) {
      if (!mounted || revision != _catalogRevision) return;
    }
    if (!mounted) return;
    showAppToast(
      context,
      'Не удалось загрузить препарат. Заполните его сами',
      bottomOffset: 24,
    );
  }

  Future<void> _resolveScannedGtin(String gtin, int revision) async {
    DrugCatalogEntry? entry;
    try {
      entry = await ref.read(drugCatalogServiceProvider).findByGtin(gtin);
    } catch (_) {
      entry = null;
    }
    if (!mounted || revision != _catalogRevision) return;
    setState(() {
      _gtin = gtin;
      if (entry != null) {
        _fillEntry(entry);
        _gtin = gtin;
      } else {
        _selectedEntry = null;
        _selectedVariant = null;
      }
    });
  }

  void _selectEntry(DrugCatalogEntry entry) {
    _catalogRevision++;
    // A name match does not identify the physical package's barcode.
    setState(() {
      _fillEntry(entry);
      _gtin = null;
    });
  }

  /// A different name detaches the catalog entry and drops what it filled
  /// in; values the user corrected stay.
  void _nameChanged(String _) {
    _catalogRevision++;
    final previous = _selectedEntry;
    setState(() {
      _gtin = null;
      if (previous == null || previous.displayName == _name.text) return;
      _selectedEntry = null;
      _selectedVariant = null;
      if (_dosage.text == previous.dosage) _dosage.clear();
      if (_form == previous.form) {
        _form = '';
        _unit = '';
      }
      _packageSize = null;
      if (!_quantityEdited) _quantity = 1;
      _started = false;
    });
  }

  void _characteristicChanged(String _) {
    _catalogRevision++;
    setState(() => _gtin = null);
  }

  /// The catalog identity is kept while name, dosage and form match it.
  bool get _matchesCatalog {
    final entry = _selectedEntry;
    return entry != null &&
        entry.displayName == _name.text &&
        entry.dosage == _dosage.text &&
        entry.form == _form;
  }

  String get _countUnit {
    final unit = _unit.trim().toLowerCase();
    final countable =
        unit.isNotEmpty &&
        unit != 'мл' &&
        !unit.startsWith('флакон') &&
        !unit.startsWith('тюбик');
    return countable ? _unit.trim() : countUnitFor(_form);
  }

  String get _saveUnit => switch (_mode) {
    StockMode.level => containerFor(_form),
    StockMode.off => 'шт.',
    StockMode.count => _countUnit,
  };

  PackageFormErrors get _errors => _submitted
      ? validatePackageForm(
          name: _name.text,
          form: _form,
          expiryChoice: _expiryChoice,
          expiry: _expiry,
        )
      : const PackageFormErrors();

  bool get _dirty => _editing
      ? _original != null && _signature != _initialSignature
      : _name.text.trim().isNotEmpty ||
            _dosage.text.trim().isNotEmpty ||
            _form.isNotEmpty ||
            _expiry != null;

  /// «Выход / Выйти без сохранения» (894:18018).
  Future<void> _close() async {
    if (_dirty) {
      final name = _name.text.trim();
      final leave = await showAppAlert(
        context: context,
        title: 'Выйти без сохранения?',
        message: _editing
            ? 'Изменения не сохранятся'
            : name.isEmpty
            ? 'Упаковка не добавится в аптечку'
            : '$name не добавится в аптечку',
        confirmLabel: 'Выйти',
        cancelLabel: 'Остаться',
      );
      if (!leave || !mounted) return;
    }
    context.pop();
  }

  Future<void> _pickForm() async {
    final option = await showDrugFormSheet(context, current: _form);
    if (option == null || !mounted) return;
    _catalogRevision++;
    setState(() {
      _form = option.form;
      _unit = option.unit;
      _gtin = null;
      _packageSize = null;
      _started = false;
      _quantity = 1;
      _level = StockLevel.full;
    });
  }

  Future<void> _pickExpiry() async {
    final date = await showExpirySheet(context, current: _expiry);
    if (date != null && mounted) setState(() => _expiry = date);
  }

  void _toggleExpiryChoice(ExpiryChoice choice) => setState(
    () => _expiryChoice = _expiryChoice == choice ? ExpiryChoice.date : choice,
  );

  Future<void> _pickOpenedAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _openedAt ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Дата вскрытия',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (date != null && mounted) setState(() => _openedAt = date);
  }

  Future<void> _pickAfterOpening() async {
    final pick = await showAfterOpeningSheet(
      context,
      current: _afterOpeningDays,
    );
    if (pick != null && mounted) {
      setState(() => _afterOpeningDays = pick.days);
    }
  }

  Future<void> _pickKit(AppState state) async {
    final kitId = await showKitPickerSheet(
      context,
      state: state,
      current: _kitId ?? state.selectedPharmacyId,
    );
    if (kitId == null || !mounted) return;
    setState(() {
      _kitId = kitId;
      _place = null;
    });
  }

  Future<void> _addPlace(AppState state, String kitId) async {
    final name = await showPlaceEditor(context, state: state, kitId: kitId);
    if (name == null || !mounted) return;
    await ref.read(appControllerProvider.notifier).addPlace(kitId, name);
    if (mounted) setState(() => _place = name);
  }

  Future<void> _pickPurpose() async {
    final pick = await showPurposeSheet(
      context,
      purposes: _purposes,
      custom: _customPurpose,
    );
    if (pick == null || !mounted) return;
    setState(() {
      _purposes = pick.purposes;
      _customPurpose = pick.custom;
    });
  }

  Future<void> _editNote() async {
    final note = await showNoteSheet(context, current: _notes);
    if (note != null && mounted) setState(() => _notes = note);
  }

  Future<void> _save(AppState state, {bool addAnother = false}) async {
    setState(() => _submitted = true);
    final errors = _errors;
    if (!errors.isEmpty) {
      if (errors.name != null || errors.form != null) {
        setState(() => _editingDrug = true);
      }
      return;
    }
    final kitId = _kitId ?? state.selectedPharmacyId;
    final place = _place ?? state.placesOf(kitId).firstOrNull ?? '';
    final selected = _selectedEntry;
    final matched = _matchesCatalog;
    String? catalogValue(String? value) =>
        value == null || value.isEmpty ? null : value;
    final mode = _mode;
    final level = mode == StockMode.level;
    if (_original case final original?) {
      await _saveEdit(original, kitId: kitId, place: place);
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(appControllerProvider.notifier)
          .addMedicine(
            pharmacyId: kitId,
            name: matched ? selected!.name : _name.text,
            activeIngredient: matched ? selected!.activeIngredient : null,
            form: _form,
            dosage: _dosage.text,
            quantity: mode == StockMode.count || _countDevice ? _quantity : 1,
            unit: _saveUnit,
            stockLevel: level ? _level : null,
            tracksStock: mode != StockMode.off || _countDevice,
            expiryDate: _expiryChoice == ExpiryChoice.date ? _expiry : null,
            noExpiry: _expiryChoice == ExpiryChoice.none,
            location: place,
            openedAt: level && _opened ? _openedAt : null,
            afterOpeningDays: level && _opened ? _afterOpeningDays : null,
            gtin: _gtin,
            catalogEntryId: matched && _selectedVariant?.isAmbiguous != true
                ? selected!.id
                : null,
            manufacturer: matched ? catalogValue(selected!.manufacturer) : null,
            packageDescription: matched
                ? catalogValue(selected!.packageDescription)
                : null,
            registrationId: matched
                ? catalogValue(selected!.registrationId)
                : null,
            registrationStatus: matched
                ? catalogValue(selected!.registrationStatus)
                : null,
            catalogVersion: matched
                ? catalogValue(selected!.sourceVersion)
                : null,
            purposes: _purposes,
            customPurpose: _customPurpose,
            notes: _notes,
          );
      if (!mounted) return;
      final router = GoRouter.of(context);
      final batch = ref.read(addBatchProvider.notifier);
      if (widget.batch) {
        if (id != null) batch.add(id);
        context.pop(true);
        return;
      }
      if (addAnother) {
        // «Несколько упаковок подряд» (890:15548): this package starts the
        // batch, the next ones come from the scanner's quick card.
        batch.clear();
        if (id != null) batch.add(id);
        router.pushReplacement(AppRoutes.scannerBatch);
        return;
      }
      if (id == null) {
        context.pop(true);
        return;
      }
      // «После сохранения / Карточка новой упаковки» (894:18224): the new
      // package's card over its kit, toast «… добавлен в «Дом» · Ещё одно».
      final savedName = readableDrugName(
        matched ? selected!.name : _name.text.trim(),
      );
      final kitName = state.kitById(kitId)?.name ?? '';
      showAppToast(
        context,
        '$savedName добавлен в «$kitName»',
        actionLabel: 'Ещё одно',
        onAction: () => router.push(AppRoutes.scanner),
      );
      await ref.read(appControllerProvider.notifier).selectPharmacy(kitId);
      router.go(AppRoutes.inventory);
      router.push(AppRoutes.medicine(id));
      // Figma 685:1080: ask about notifications once, after the first save.
      if (OnboardingStore.shouldPromptNotifications) {
        router.push(AppRoutes.notificationsPrompt);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// «Сохранить изменения»: the package keeps its id, dates and reference
  /// texts; the drug, stock, expiry, place and «Ещё» come from the form.
  Future<void> _saveEdit(
    Medicine original, {
    required String kitId,
    required String place,
  }) async {
    final selected = _selectedEntry;
    final matched = _matchesCatalog;
    final sameDrug = readableDrugName(original.name) == _name.text.trim();
    String? keep(String? Function(DrugCatalogEntry) catalog, String? own) {
      if (matched) {
        final value = catalog(selected!);
        return value == null || value.isEmpty ? null : value;
      }
      return sameDrug ? own : null;
    }

    final mode = _mode;
    final level = mode == StockMode.level;
    final updated = Medicine(
      id: original.id,
      pharmacyId: kitId,
      name: matched
          ? selected!.name
          : sameDrug
          ? original.name
          : _name.text.trim(),
      activeIngredient: keep((e) => e.activeIngredient, original.activeIngredient),
      form: _form,
      dosage: _dosage.text.trim(),
      quantity: mode == StockMode.count || _countDevice ? _quantity : 1,
      unit: _saveUnit,
      stockLevel: level ? _level : null,
      tracksStock: mode != StockMode.off || _countDevice,
      expiryDate: _expiryChoice == ExpiryChoice.date ? _expiry : null,
      noExpiry: _expiryChoice == ExpiryChoice.none,
      location: place,
      openedAt: level ? (_opened ? _openedAt : null) : original.openedAt,
      afterOpeningDays: level
          ? (_opened ? _afterOpeningDays : null)
          : original.afterOpeningDays,
      gtin: _gtin,
      catalogEntryId: matched && _selectedVariant?.isAmbiguous != true
          ? selected!.id
          : null,
      manufacturer: keep((e) => e.manufacturer, original.manufacturer),
      packageDescription: keep(
        (e) => e.packageDescription,
        original.packageDescription,
      ),
      registrationId: keep((e) => e.registrationId, original.registrationId),
      registrationStatus: keep(
        (e) => e.registrationStatus,
        original.registrationStatus,
      ),
      catalogVersion: keep((e) => e.sourceVersion, original.catalogVersion),
      purposes: _purposes,
      customPurpose: _customPurpose.trim().isEmpty ? null : _customPurpose.trim(),
      notes: _notes.trim().isEmpty ? null : _notes.trim(),
      description: original.description,
      usage: original.usage,
      storage: original.storage,
      addedAt: original.addedAt,
      updatedAt: original.updatedAt,
      stockUpdatedAt: original.stockUpdatedAt,
    );
    setState(() => _saving = true);
    try {
      await ref.read(appControllerProvider.notifier).replacePackage(updated);
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          'Не удалось сохранить упаковку. Повторите попытку.',
          bottomOffset: 24,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(appControllerProvider).asData?.value;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleNavBar.modal(
              title: _editing ? 'Изменить упаковку' : 'Новая упаковка',
              onBack: _close,
            ),
            Expanded(
              child: state == null || _loading
                  ? const SizedBox.shrink()
                  : _editing && _original == null
                  ? Center(
                      child: Text(
                        'Упаковка не найдена',
                        style: AppTypography.bodyMedium.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSpacing.maxContentWidth,
                        ),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.page,
                            8,
                            AppSpacing.page,
                            34 + MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          // Keyed, so the name field keeps its state and
                          // focus when a banner or section appears above it.
                          children: [
                            for (final (i, (id, section)) in _sections(
                              state,
                            ).indexed)
                              KeyedSubtree(
                                key: ValueKey('section-$id'),
                                child: Padding(
                                  padding: EdgeInsets.only(top: i > 0 ? 24 : 0),
                                  child: section,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<(String, Widget)> _sections(AppState state) {
    final errors = _errors;
    final mode = _mode;
    return [
      if (_editing)
        ...[]
      else if (widget.scanSource != null)
        (
          'banner',
          _ScanBanner(
            fromDataMatrix: widget.scanSource == 'dataMatrix',
            expiryRead: widget.scannedExpiry != null,
            onRescan: () => context.pushReplacement(AppRoutes.scanner),
          ),
        )
      else if (_selectedEntry == null)
        (
          'banner',
          const StatusBanner(
            tone: StatusBannerTone.info,
            title: 'Заполните сами',
            text:
                'Препарата нет в справочнике. Хватит названия, формы и срока — '
                'остальное позже',
          ),
        ),
      ('drug', _drugSection(errors)),
      if (mode == StockMode.off)
        ('stock', _deviceStockSection())
      else if (_editing)
        ('package', _remainderSection())
      else
        ('package', _packageSection()),
      ('expiry', _expirySection(errors)),
      if (mode == StockMode.level) ('opening', _openingSection()),
      ('place', _placeSection(state)),
      ('more', _moreSection()),
      (
        'actions',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              key: const ValueKey('package-save'),
              label: _saving
                  ? 'Сохраняем…'
                  : _editing
                  ? 'Сохранить изменения'
                  : 'Сохранить',
              onPressed: _saving ? null : () => _save(state),
            ),
            if (_editing) ...[
              const SizedBox(height: 8),
              Center(
                child: AppTextButton(
                  label: 'Убрать из аптечки',
                  color: context.palette.fail,
                  onPressed: () => context.pop(PackageEditResult.remove),
                ),
              ),
            ] else if (!widget.batch) ...[
              const SizedBox(height: 8),
              AppButton.secondary(
                label: 'Сохранить и добавить ещё',
                onPressed: _saving
                    ? null
                    : () => _save(state, addAnother: true),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _drugSection(PackageFormErrors errors) {
    if (_catalogMode) {
      return FormSection(
        title: 'Препарат',
        children: [
          CatalogItemCard(
            entry: _selectedEntry!,
            showPhoto: _selectedVariant?.isAmbiguous != true,
            onChange: () => setState(() => _editingDrug = true),
          ),
        ],
      );
    }
    final formOption = drugFormOptions
        .where((option) => option.form == _form)
        .firstOrNull;
    return FormSection(
      title: 'Препарат',
      children: [
        DrugNameField(
          controller: _name,
          error: errors.name != null,
          onChanged: _nameChanged,
          onSelected: _selectEntry,
        ),
        if (errors.name != null) FieldCaption(errors.name!, error: true),
        AppField(
          fieldKey: const ValueKey('drug-dosage-input'),
          label: 'Дозировка, например 500 мг',
          controller: _dosage,
          placeholderWhenEmpty: true,
          onChanged: _characteristicChanged,
        ),
        AppSelect(
          key: const ValueKey('drug-form-input'),
          label: 'Форма',
          required: true,
          error: errors.form != null,
          value: _form.isEmpty
              ? null
              : formOption?.form ?? readableDrugText(_form),
          onTap: _pickForm,
        ),
        if (errors.form != null) FieldCaption(errors.form!, error: true),
      ],
    );
  }

  Widget _packageSection() {
    final size = _packageSize;
    final level = _mode == StockMode.level;
    return FormSection(
      title: 'Упаковка',
      children: [
        AppSegmented(
          labels: const ['Новая', 'Уже начата'],
          selected: _started ? 1 : 0,
          onChanged: (index) => setState(() {
            _started = index == 1;
            if (!_started) {
              _quantity = size ?? _quantity;
              _level = StockLevel.full;
            } else if (_level == StockLevel.full) {
              _level = StockLevel.moreThanHalf;
            }
          }),
        ),
        if (level)
          StockLevelBar(
            labels: [for (final item in StockLevel.values) item.label],
            level: _level.index,
            caption: _started ? '' : 'новый ${containerFor(_form)}',
            onChanged: (index) => setState(() {
              _level = StockLevel.values[index];
              _started = _level != StockLevel.full;
            }),
          )
        else
          _counter(
            caption: size == null
                ? ''
                : _started
                ? 'из $size в упаковке'
                : 'целая упаковка',
          ),
        if (_form.isEmpty)
          const FieldCaption(
            'Единица зависит от формы: таблетки, капсулы, свечи — штуками; '
            'капли, сиропы, мази — примерно',
          ),
      ],
    );
  }

  /// «Изменить упаковку» (894:18072): «Остаток» without «Новая / Уже
  /// начата» — «Осталось 14 таблеток из 20 в упаковке».
  Widget _remainderSection() {
    final size = _packageSize;
    return FormSection(
      title: 'Остаток',
      children: [
        if (_mode == StockMode.level)
          StockLevelBar(
            labels: [for (final item in StockLevel.values) item.label],
            level: _level.index,
            caption: '',
            onChanged: (index) =>
                setState(() => _level = StockLevel.values[index]),
          )
        else
          _counter(caption: size == null ? '' : 'из $size в упаковке'),
      ],
    );
  }

  Widget _counter({String caption = ''}) => StockCounter(
    key: const ValueKey('package-quantity'),
    value: quantityLabel(_quantity, _countUnit),
    caption: caption,
    // A saved package may be used up; a new one has at least one.
    onMinus: _quantity > (_editing ? 0 : 1)
        ? () => setState(() {
            _quantity--;
            _quantityEdited = true;
            if (_packageSize != null) _started = true;
          })
        : null,
    onPlus: () => setState(() {
      _quantity++;
      _quantityEdited = true;
    }),
  );

  /// «Форма / Без срока годности» (890:16408): devices are not counted.
  Widget _deviceStockSection() => FormSection(
    title: 'Остаток',
    children: [
      SwitchRow(
        title: 'Считать остаток',
        value: _countDevice,
        onChanged: (value) => setState(() => _countDevice = value),
      ),
      if (_countDevice) _counter(),
      if (!_countDevice) const FieldCaption('Для приборов количество не важно'),
    ],
  );

  Widget _expirySection(PackageFormErrors errors) => FormSection(
    title: 'Срок годности',
    children: [
      if (_expiryChoice == ExpiryChoice.date) ...[
        AppSelect(
          key: const ValueKey('package-expiry-input'),
          label: 'Месяц и год',
          required: true,
          error: errors.expiry != null,
          value: _expiry == null ? null : monthYearLabel(_expiry!),
          onTap: _pickExpiry,
        ),
        if (errors.expiry != null) FieldCaption(errors.expiry!, error: true),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AppChip(
            label: 'Укажу позже',
            selected: _expiryChoice == ExpiryChoice.later,
            onTap: () => _toggleExpiryChoice(ExpiryChoice.later),
          ),
          AppChip(
            label: 'Без срока годности',
            selected: _expiryChoice == ExpiryChoice.none,
            onTap: () => _toggleExpiryChoice(ExpiryChoice.none),
          ),
        ],
      ),
      if (_expiryChoice == ExpiryChoice.later)
        const FieldCaption(
          'Напомним указать срок. В карточке будет «Срок не указан»',
        ),
      if (_expiryChoice == ExpiryChoice.none)
        const FieldCaption(
          'Для приборов, бинтов и пластырей. Предупреждений о сроке не будет',
        ),
    ],
  );

  Widget _openingSection() => FormSection(
    title: 'Вскрытие',
    children: [
      SwitchRow(
        title: openedSwitchLabel(_form),
        value: _opened,
        onChanged: (value) => setState(() {
          _opened = value;
          if (value) {
            _openedAt ??= DateTime.now();
            _started = true;
            if (_level == StockLevel.full) _level = StockLevel.moreThanHalf;
          }
        }),
      ),
      if (_opened) ...[
        AppSelect(
          label: 'Дата вскрытия',
          required: true,
          value: _openedAt == null ? null : compactDate(_openedAt!),
          onTap: _pickOpenedAt,
        ),
        AppSelect(
          label: 'Срок после вскрытия',
          value: _afterOpeningDays == null
              ? null
              : afterOpeningLabel(_afterOpeningDays!),
          onTap: _pickAfterOpening,
        ),
        const FieldCaption(
          'Смотрите в инструкции: «после вскрытия хранить не более…»',
        ),
      ],
    ],
  );

  Widget _placeSection(AppState state) {
    final kitId = _kitId ?? state.selectedPharmacyId;
    final kit = state.kitById(kitId);
    final places = state.placesOf(kitId);
    final place = _place ?? places.firstOrNull ?? '';
    return FormSection(
      title: 'Где лежит',
      children: [
        AppSelect(
          key: const ValueKey('package-kit-input'),
          label: 'Аптечка',
          required: true,
          value: kit?.name,
          onTap: () => _pickKit(state),
        ),
        Wrap(
          key: const ValueKey('package-location-input'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in places)
              AppChip(
                label: item,
                icon: item == place ? 'pin-16-white' : 'pin-16-brand',
                selected: item == place,
                onTap: () => setState(() => _place = item == place ? '' : item),
              ),
            AppChip(
              label: '+ Новое место',
              selected: false,
              onTap: () => _addPlace(state, kitId),
            ),
          ],
        ),
      ],
    );
  }

  Widget _moreSection() {
    final entry = _selectedEntry;
    final catalogPhoto =
        entry != null &&
        _selectedVariant?.isAmbiguous != true &&
        ref.watch(drugPhotoProvider(entry.gtin)).asData?.value != null;
    return FormSection(
      title: 'Ещё',
      hint: 'Можно заполнить позже — в карточке упаковки',
      children: [
        ActionGroup(
          children: [
            ActionRow(
              title: 'Для чего',
              subtitle: purposesLabel(_purposes, _customPurpose),
              onTap: _pickPurpose,
            ),
            ActionRow(
              title: 'Фото упаковки',
              subtitle: catalogPhoto ? 'Из справочника' : null,
              onTap: () => showAppToast(
                context,
                catalogPhoto
                    ? 'Фото взяли из справочника'
                    : 'Своё фото можно будет добавить позже',
                bottomOffset: 24,
              ),
            ),
            ActionRow(
              title: 'Заметка',
              subtitle: _notes.isEmpty ? null : _notes,
              onTap: _editNote,
            ),
          ],
        ),
      ],
    );
  }
}

/// Banner of «DataMatrix — срок считан» (891:16634) and «Штрихкод — срок
/// укажите сами» (891:16803).
class _ScanBanner extends StatelessWidget {
  const _ScanBanner({
    required this.fromDataMatrix,
    required this.expiryRead,
    required this.onRescan,
  });

  final bool fromDataMatrix;
  final bool expiryRead;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) => fromDataMatrix && expiryRead
      ? StatusBanner(
          tone: StatusBannerTone.ok,
          title: 'Нашли по DataMatrix-коду',
          text: 'Срок считали с кода. Проверьте и укажите, где лежит',
          actionLabel: 'Сканировать заново',
          onAction: onRescan,
        )
      : const StatusBanner(
          tone: StatusBannerTone.warning,
          title: 'Срок укажите сами',
          text:
              'Обычный штрихкод знает только препарат. Срок найдите на '
              'упаковке: «Годен до» или «EXP»',
        );
}
