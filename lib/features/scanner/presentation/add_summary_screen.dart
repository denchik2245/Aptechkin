import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/nav_bars.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/quick_add.dart';
import 'package:aptechka/features/inventory/presentation/widgets/package_card.dart';
import 'package:aptechka/features/scanner/application/add_batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Figma «Несколько / Итог» (892:17128): what was added in a row — a green
/// banner, the packages, «Готово» and «Сканировать ещё».
class AddSummaryScreen extends ConsumerWidget {
  const AddSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(appControllerProvider).asData?.value;
    final ids = ref.watch(addBatchProvider);
    final summary = state == null ? null : batchSummary(state, ids);
    final count = summary?.packages.length ?? 0;
    void done() {
      ref.read(addBatchProvider.notifier).clear();
      context.go(AppRoutes.inventory);
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleNavBar.modal(title: 'Добавлено $count', onBack: done),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  8,
                  AppSpacing.page,
                  24 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  if (summary != null && count > 0) ...[
                    StatusBanner(
                      tone: StatusBannerTone.ok,
                      title: summary.title,
                      text: summary.text ?? '',
                    ),
                    for (final package in summary.packages) ...[
                      const SizedBox(height: 12),
                      PackageCard(
                        package: package,
                        now: DateTime.now(),
                        warningDays: state!.settings.expiryWarningDays,
                        onTap: () =>
                            context.push(AppRoutes.medicine(package.id)),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  AppButton(label: 'Готово', onPressed: done),
                  const SizedBox(height: 8),
                  AppButton.secondary(
                    label: 'Сканировать ещё',
                    onPressed: () =>
                        context.pushReplacement(AppRoutes.scannerBatch),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
