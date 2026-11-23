import 'dart:math' as math;

import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_sheet.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/core/ui/nav_bars.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/drug_catalog_service.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_card.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/onboarding/data/onboarding_store.dart';
import 'package:aptechka/features/inventory/domain/kit_operations.dart';
import 'package:aptechka/features/inventory/domain/quick_add.dart';
import 'package:aptechka/features/scanner/application/add_batch.dart';
import 'package:aptechka/features/scanner/domain/scanned_code.dart';
import 'package:aptechka/features/scanner/presentation/quick_add_card.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Figma section «Добавление препарата / 1 · Вход и сканирование» (890:15546).
///
/// In the default mode a scan leads to the package form, to «Уже есть в
/// аптечке» or to «Не нашли препарат по коду». With [pickOnly] the screen just
/// returns the GTIN to the caller (form and catalog scan buttons).
///
/// With [batch] («3 · Несколько упаковок подряд», 890:15548) a found
/// package is added from a quick card under the camera; the counter and the
/// close button lead to the summary.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({
    this.pickOnly = false,
    this.batch = false,
    super.key,
  });
  final bool pickOnly;
  final bool batch;

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

enum _Stage { intro, camera }

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  late _Stage _stage = OnboardingStore.shouldExplainCamera
      ? _Stage.intro
      : _Stage.camera;
  bool _busy = false;
  bool _torch = false;

  /// The package on the quick card in [BarcodeScannerScreen.batch] mode.
  (ScannedCode, DrugCatalogEntry)? _pending;
  bool _adding = false;
  String? _lastPlace;

  static const _formats = [
    BarcodeFormat.dataMatrix,
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
  ];

  @override
  void initState() {
    super.initState();
    if (_stage == _Stage.camera) _startCamera();
  }

  void _startCamera() {
    _controller ??= MobileScannerController(formats: _formats);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _allowCamera() async {
    await OnboardingStore.markCameraIntroShown();
    if (!mounted) return;
    setState(() {
      _stage = _Stage.camera;
      _startCamera();
    });
  }

  void _searchByName() => context.pushReplacement(AppRoutes.medicineSelect);

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      final code = raw == null ? null : ScannedCode.parse(raw);
      if (code != null) {
        await _handle(code);
        return;
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Фото', extensions: ['jpg', 'jpeg', 'png', 'heic']),
      ],
    );
    if (file == null || !mounted) return;
    final capture = await _controller?.analyzeImage(
      file.path,
      formats: _formats,
    );
    final code = capture?.barcodes
        .map((item) => item.rawValue)
        .whereType<String>()
        .map(ScannedCode.parse)
        .whereType<ScannedCode>()
        .firstOrNull;
    if (!mounted) return;
    if (code == null) {
      showAppToast(
        context,
        'На фото не нашли код. Попробуйте другой снимок',
        bottomOffset: 24,
      );
      return;
    }
    await _handle(code);
  }

  /// Resolves a scanned code and continues the add flow.
  Future<void> _handle(ScannedCode code) async {
    if (widget.pickOnly) {
      _busy = true;
      context.pop(code.gtin);
      return;
    }
    setState(() => _busy = true);
    await _controller?.stop();
    try {
      final entry = await ref
          .read(drugCatalogServiceProvider)
          .findByGtin(code.gtin);
      if (!mounted) return;
      if (entry == null) {
        await _showNotFound(code);
        return;
      }
      if (widget.batch) {
        setState(() => _pending = (code, entry));
        return;
      }
      final state = await ref.read(appControllerProvider.future);
      final kit = state.selectedPharmacyOrNull;
      final existing = kit == null
          ? null
          : state
                .medicinesIn(kit.id)
                .where(
                  (item) =>
                      item.gtin == code.gtin ||
                      item.catalogEntryId == 'mdlp:${code.gtin}',
                )
                .firstOrNull;
      if (!mounted) return;
      if (existing != null && kit != null) {
        await _showAlreadyThere(
          code,
          existing,
          kit.name,
          state.settings.expiryWarningDays,
        );
        return;
      }
      _openForm(code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openForm(ScannedCode code) {
    final expiry = code.expiry?.toIso8601String().substring(0, 10);
    final location = Uri(
      path: AppRoutes.medicineNew,
      queryParameters: {
        'scanned': code.gtin,
        'source': code.kind.name,
        'expiry': ?expiry,
        if (widget.batch) 'batch': '1',
      },
    ).toString();
    if (widget.batch) {
      // The form adds to the batch and comes back to the camera.
      _openBatchForm(location);
      return;
    }
    context.pushReplacement(location);
  }

  Future<void> _openBatchForm(String location) async {
    setState(() => _pending = null);
    await context.push<bool>(location);
    if (mounted) await _resume();
  }

  void _skip() {
    setState(() => _pending = null);
    _resume();
  }

  Future<void> _quickAdd(QuickAddPick pick) async {
    final pending = _pending;
    if (pending == null || _adding) return;
    final (code, entry) = pending;
    final stock = quickStockFor(entry);
    String? value(String text) => text.trim().isEmpty ? null : text.trim();
    setState(() => _adding = true);
    try {
      final id = await ref
          .read(appControllerProvider.notifier)
          .addMedicine(
            name: entry.name,
            activeIngredient: value(entry.activeIngredient),
            form: entry.form,
            dosage: entry.dosage,
            quantity: stock.quantity,
            unit: stock.unit,
            stockLevel: stock.stockLevel,
            tracksStock: stock.tracksStock,
            expiryDate: pick.expiry,
            location: pick.place,
            gtin: code.gtin,
            catalogEntryId: entry.id,
            manufacturer: value(entry.manufacturer),
            packageDescription: value(entry.packageDescription),
            registrationId: value(entry.registrationId),
            registrationStatus: value(entry.registrationStatus),
            catalogVersion: value(entry.sourceVersion),
          );
      if (id != null) ref.read(addBatchProvider.notifier).add(id);
      if (!mounted) return;
      setState(() {
        _pending = null;
        _lastPlace = pick.place;
      });
      await _resume();
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          'Не удалось добавить упаковку. Повторите попытку.',
          bottomOffset: 24,
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// The close button and the counter: the summary once something was
  /// added, otherwise just back.
  void _finishBatch() {
    if (ref.read(addBatchProvider).isEmpty) {
      context.canPop() ? context.pop() : context.go(AppRoutes.inventory);
      return;
    }
    context.pushReplacement(AppRoutes.addSummary);
  }

  Future<void> _resume() async {
    if (mounted) setState(() => _busy = false);
    await _controller?.start();
  }

  /// «Сканирование / Код не распознан» (713:2275).
  Future<void> _showNotFound(ScannedCode code) async {
    final palette = context.palette;
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: palette.background,
      barrierColor: palette.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 34),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Не нашли препарат по коду',
                textAlign: TextAlign.center,
                style: AppTypography.h3.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Код считан, но такого препарата нет в справочнике. Найдите '
                'его по названию или заполните карточку вручную — это займёт '
                'минуту',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Найти по названию',
                onPressed: () => Navigator.pop(sheetContext, 'search'),
              ),
              const SizedBox(height: 8),
              AppButton.secondary(
                label: 'Заполнить вручную',
                onPressed: () => Navigator.pop(sheetContext, 'manual'),
              ),
              const SizedBox(height: 8),
              AppTextButton(
                label: 'Сканировать ещё раз',
                color: palette.brandPrimary,
                onPressed: () => Navigator.pop(sheetContext, 'retry'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'search':
        _searchByName();
      case 'manual':
        _openForm(code);
      default:
        await _resume();
    }
  }

  /// «Сканирование / Уже есть в аптечке» (891:16912).
  Future<void> _showAlreadyThere(
    ScannedCode code,
    Medicine existing,
    String kitName,
    int warningDays,
  ) async {
    final action = await showAppSheet<String>(
      context: context,
      title: '${readableDrugName(existing.name)} уже есть',
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'В «$kitName» лежит другая упаковка. Это новая или та же самая?',
              style: AppTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: IgnorePointer(
                child: PackageCard(
                  package: existing,
                  now: DateTime.now(),
                  warningDays: warningDays,
                  onTap: () {},
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Добавить как новую упаковку',
              onPressed: () => Navigator.pop(sheetContext, 'new'),
            ),
            const SizedBox(height: 8),
            AppButton.secondary(
              label: 'Это та же упаковка — открыть',
              onPressed: () => Navigator.pop(sheetContext, 'open'),
            ),
            const SizedBox(height: 8),
            Text(
              'Упаковки одного препарата хранятся отдельно — у каждой свой '
              'срок, остаток и место',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    switch (action) {
      case 'new':
        _openForm(code);
      case 'open':
        context.pushReplacement(AppRoutes.medicine(existing.id));
      default:
        await _resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pending = _pending;
    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                TitleNavBar.modal(
                  title: 'Сканирование',
                  onBack: widget.batch ? _finishBatch : null,
                ),
                if (widget.batch) _BatchMode(onCounter: _finishBatch),
                Expanded(
                  child: _stage == _Stage.intro
                      ? _InfoCard(
                          title: 'Сканируйте упаковку',
                          text:
                              'Камера нужна, чтобы прочитать штрихкод или '
                              'DataMatrix-код. Снимки никуда не отправляем',
                          primaryLabel: 'Продолжить',
                          onPrimary: _allowCamera,
                          onSecondary: _searchByName,
                        )
                      : _camera(context),
                ),
              ],
            ),
          ),
          if (pending != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _quickCard(pending),
            ),
        ],
      ),
    );
  }

  Widget _quickCard((ScannedCode, DrugCatalogEntry) pending) {
    final (code, entry) = pending;
    final state = ref.watch(appControllerProvider).asData?.value;
    final kit = state?.selectedPharmacyOrNull;
    final places = kit == null ? const <String>[] : state!.placesOf(kit.id);
    return QuickAddCard(
      key: ValueKey(code),
      entry: entry,
      code: code,
      kitName: kit?.name ?? '',
      places: places,
      initialPlace: quickDefaultPlace(places, _lastPlace),
      busy: _adding,
      onDetails: () => _openForm(code),
      onSkip: _skip,
      onAdd: _quickAdd,
    );
  }

  Widget _camera(BuildContext context) {
    final controller = _controller!;
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final error = state.error;
        if (error == null) return _viewfinder(context, controller);
        final denied =
            error.errorCode == MobileScannerErrorCode.permissionDenied;
        return _InfoCard(
          title: denied ? 'Нет доступа к камере' : 'Камера недоступна',
          text: denied
              ? 'Разрешите доступ в настройках, чтобы сканировать коды на '
                    'упаковках. Или найдите лекарство по названию'
              : 'Не удалось включить камеру. Попробуйте ещё раз или найдите '
                    'лекарство по названию',
          primaryLabel: denied ? 'Открыть настройки' : 'Попробовать ещё раз',
          // Re-requests access; where the system remembers a refusal the
          // user changes it in the system settings.
          onPrimary: controller.start,
          onSecondary: _searchByName,
        );
      },
    );
  }

  Widget _viewfinder(BuildContext context, MobileScannerController controller) {
    final palette = context.palette;
    final bottom = math.max(16.0, MediaQuery.viewPaddingOf(context).bottom);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fixed parts of «Сканирование / Камера»: hint, code kinds, buttons.
        final buttons = kIsWeb ? 60.0 : 128.0;
        final fixed = 20 + 35 + 25 + 16 + 94 + 24 + buttons + bottom;
        final side = math.max(
          160.0,
          math.min(
            math.min(constraints.maxWidth - 32, 358.0),
            constraints.maxHeight - fixed,
          ),
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, bottom),
                child: Column(
                  children: [
                    SizedBox.square(
                      dimension: side,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: palette.buttonSecondary),
                            MobileScanner(
                              controller: controller,
                              onDetect: _onDetect,
                              errorBuilder: (context, error) =>
                                  const SizedBox.shrink(),
                            ),
                            const _Corners(),
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: Semantics(
                                button: true,
                                label: _torch
                                    ? 'Выключить фонарик'
                                    : 'Включить фонарик',
                                excludeSemantics: true,
                                child: GestureDetector(
                                  onTap: () async {
                                    await controller.toggleTorch();
                                    setState(() => _torch = !_torch);
                                  },
                                  child: const DesignIcon(
                                    'scan/torch',
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                            if (_busy) const Center(child: _Recognising()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                    Text(
                      'Наведите камеру на одно из:',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLarge.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 358),
                      child: const _CodeKinds(),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 358),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppButton(
                            label: 'Найти по названию',
                            icon: const DesignIcon(
                              'scan/search-white',
                              size: 20,
                            ),
                            onPressed: _searchByName,
                          ),
                          if (!kIsWeb) ...[
                            const SizedBox(height: 8),
                            AppButton.secondary(
                              label: 'Выбрать из галереи',
                              icon: const DesignIcon('scan/gallery', size: 20),
                              onPressed: _busy ? null : _pickFromGallery,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Card from «Перед доступом к камере» (891:16411) and «Нет доступа к
/// камере» (713:2225).
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.text,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  final String title;
  final String text;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 358),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              color: palette.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/illustrations/onboarding/scan.png',
                    width: 200,
                    height: 200,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.h3.copyWith(color: palette.textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(label: primaryLabel, onPressed: onPrimary),
                const SizedBox(height: 8),
                AppButton.secondary(
                  label: 'Найти по названию',
                  onPressed: onSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Viewfinder corners from the Figma «Group 11»: 80 pt, inset 10 pt.
class _Corners extends StatelessWidget {
  const _Corners();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(10),
    child: Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: DesignIcon('scan/corner', size: 80),
        ),
        Align(
          alignment: Alignment.topRight,
          child: _Flip(x: true, child: DesignIcon('scan/corner', size: 80)),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: _Flip(y: true, child: DesignIcon('scan/corner', size: 80)),
        ),
      ],
    ),
  );
}

class _Flip extends StatelessWidget {
  const _Flip({required this.child, this.x = false, this.y = false});
  final Widget child;
  final bool x;
  final bool y;

  @override
  Widget build(BuildContext context) =>
      Transform.flip(flipX: x, flipY: y, child: child);
}

/// «recognising» chip (891:16607).
class _Recognising extends StatefulWidget {
  const _Recognising();

  @override
  State<_Recognising> createState() => _RecognisingState();
}

class _RecognisingState extends State<_Recognising>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xD91C1A32),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _spin,
            child: const DesignIcon('scan/spinner', size: 18),
          ),
          const SizedBox(width: 8),
          Text(
            'Распознаём код…',
            style: AppTypography.bodySmall.copyWith(
              color: context.palette.textOnAccent,
            ),
          ),
        ],
      ),
    ),
  );
}

/// «Наведите камеру на одно из:» card: DataMatrix-код | Штрих-код.
class _CodeKinds extends StatelessWidget {
  const _CodeKinds();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget kind(String icon, String label) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignIcon(icon, size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            kind('scan/datamatrix', 'DataMatrix-код'),
            Container(width: 1, color: palette.divider),
            kind('scan/barcode', 'Штрих-код'),
          ],
        ),
      ),
    );
  }
}

/// «mode» (892:16942): «Несколько подряд» and «Добавлено N».
class _BatchMode extends ConsumerWidget {
  const _BatchMode({required this.onCounter});
  final VoidCallback onCounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final count = ref.watch(addBatchProvider).length;
    final style = AppTypography.labelLarge;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              decoration: BoxDecoration(
                color: palette.surfaceChoice,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Text(
                'Несколько подряд',
                style: style.copyWith(color: palette.textOnAccent),
              ),
            ),
            Semantics(
              button: true,
              hint: 'Показать добавленные',
              child: Material(
                color: palette.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: count == 0 ? null : onCounter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      'Добавлено $count',
                      style: style.copyWith(color: palette.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
