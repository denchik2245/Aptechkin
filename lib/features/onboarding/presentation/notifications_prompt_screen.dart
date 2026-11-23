import 'dart:math' as math;

import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/utils/date_labels.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/onboarding/data/onboarding_store.dart';
import 'package:aptechka/features/onboarding/presentation/onboarding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Figma 685:1080 «Запрос уведомлений — после первого лекарства».
/// Shown once, before the system permission request. System notifications
/// are not connected yet, so «Включить» turns on the in-app expiry alerts.
class NotificationsPromptScreen extends ConsumerWidget {
  const NotificationsPromptScreen({super.key});

  Future<void> _close(BuildContext context, WidgetRef ref, bool enable) async {
    await OnboardingStore.markNotificationPromptShown();
    if (enable) {
      final controller = ref.read(appControllerProvider.notifier);
      final settings = ref.read(appControllerProvider).requireValue.settings;
      await controller.updateSettings(settings.copyWith(expiryAlerts: true));
    }
    if (!context.mounted) return;
    context.canPop() ? context.pop() : context.go(AppRoutes.inventory);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(appControllerProvider).asData?.value;
    final latest = state?.medicines.lastOrNull;
    final name = latest?.name ?? 'Нурофен';
    final expiry = latest?.effectiveExpiryDate;
    final kit = state?.selectedPharmacyOrNull?.name ?? 'Дом';
    final bottomInset = math.max(34.0, MediaQuery.viewPaddingOf(context).bottom);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) OnboardingStore.markNotificationPromptShown();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.navBar),
              Expanded(
                child: OnboardingHero(
                  height: 388,
                  children: [
                    const HeroItem(
                      0,
                      -3,
                      HeroImage('notifications', size: 330),
                    ),
                    HeroItem(
                      0,
                      -147,
                      PushPreview(
                        title: '$name скоро истечёт',
                        body: expiry == null
                            ? 'Срок годности — до 12 декабря. Проверьте упаковку'
                            : 'Срок годности — до ${shortDate(expiry)}. '
                                  'Проверьте упаковку',
                      ),
                    ),
                    HeroItem(
                      0,
                      136.5,
                      PushPreview(
                        title: 'Проверьте аптечку «$kit»',
                        body: '2 лекарства просрочены',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
                child: Column(
                  children: [
                    OnboardingText(
                      title: 'Не пропустите важное',
                      text:
                          'Подскажем, когда у «$name» будет подходить к концу '
                          'срок годности. Частоту можно настроить',
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: 'Включить уведомления',
                        onPressed: () => _close(context, ref, true),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton.secondary(
                        label: 'Не сейчас',
                        onPressed: () => _close(context, ref, false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
