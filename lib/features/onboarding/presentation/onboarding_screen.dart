import 'dart:math' as math;

import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/expiry_summary.dart';
import 'package:aptechka/core/ui/page_dots.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/onboarding/data/onboarding_store.dart';
import 'package:aptechka/features/onboarding/presentation/onboarding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Figma section «Онбординг»: frames 685:924, 685:980, 685:1037.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  var _index = 0;
  var _busy = false;

  static const _count = 3;
  bool get _isLast => _index == _count - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Every exit creates the kit «Дом» (Figma annotations on Skip and the
  /// final button) and then opens its list or the scanner.
  Future<void> _finish({required bool scan}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(appControllerProvider.future);
      await ref.read(appControllerProvider.notifier).ensureHomeKit();
      await OnboardingStore.complete();
      if (!mounted) return;
      context.go(AppRoutes.inventory);
      if (scan) context.push(AppRoutes.scanner);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() => _pages.nextPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottomInset = math.max(34.0, MediaQuery.viewPaddingOf(context).bottom);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: AppSpacing.navBar,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppTextButton(
                    label: _isLast ? 'Позже' : 'Пропустить',
                    onPressed: _busy ? null : () => _finish(scan: false),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (value) => setState(() => _index = value),
                children: const [_KitsPage(), _ExpiryPage(), _ScanPage()],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 28, 16, bottomInset),
              child: Column(
                children: [
                  PageDots(count: _count, index: _index),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: _isLast ? 'Добавить лекарство' : 'Далее',
                      onPressed: _busy
                          ? null
                          : _isLast
                          ? () => _finish(scan: true)
                          : _next,
                    ),
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

/// Hero plus the text block; the text keeps the 8 pt top padding of
/// the Figma «Bottom» frame.
class _Page extends StatelessWidget {
  const _Page({required this.hero, required this.title, required this.text});
  final Widget hero;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: hero),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: OnboardingText(title: title, text: text),
      ),
    ],
  );
}

class _KitsPage extends StatelessWidget {
  const _KitsPage();

  @override
  Widget build(BuildContext context) => const _Page(
    title: 'Вся аптечка\nпод рукой',
    text: 'Что есть дома, где лежит и сколько осталось — по всем аптечкам сразу',
    hero: OnboardingHero(
      children: [
        HeroItem(0, 0, HeroImage('kits', size: 344)),
        HeroItem(
          -103,
          -123,
          KitChip(icon: 'kit-home', name: 'Дом', count: '24 лекарства'),
        ),
        HeroItem(
          104.5,
          -80,
          KitChip(icon: 'kit-dacha', name: 'Дача', count: '12 лекарств'),
        ),
        HeroItem(
          -93.5,
          121,
          KitChip(icon: 'kit-car', name: 'Машина', count: '5 лекарств'),
        ),
      ],
    ),
  );
}

class _ExpiryPage extends StatelessWidget {
  const _ExpiryPage();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _Page(
      title: 'Сроки и вскрытие\nпод контролем',
      text:
          'Покажем, что скоро истечёт, а что пора выбросить — с учётом вскрытия',
      hero: OnboardingHero(
        children: [
          const HeroItem(0, -1, HeroImage('expiry', size: 334)),
          HeroItem(
            31.5,
            137,
            const FloatingCard(
              child: ExpirySummary(
                expired: 2,
                soon: 12,
                expiredText: '2 просрочены',
                soonText: '12 скоро',
              ),
            ),
          ),
          HeroItem(
            0,
            -164.5,
            BadgeCard(
              badgeIcon: 'drops-20',
              badgeColor: const Color(0x24FF9500),
              lines: [
                Text(
                  'Називин, капли',
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  'Вскрыто 2 сентября',
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                Text(
                  'Использовать ещё 12 дней',
                  style: AppTypography.labelMedium.copyWith(
                    color: palette.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanPage extends StatelessWidget {
  const _ScanPage();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _Page(
      title: 'Добавить лекарство за пару секунд',
      text:
          'Отсканируйте штрихкод или найдите по названию — останется проверить срок',
      hero: OnboardingHero(
        children: [
          const HeroItem(0, -51, HeroImage('scan', size: 344)),
          HeroItem(
            0.5,
            100.5,
            BadgeCard(
              badgeIcon: 'check-mark-20',
              badgeColor: const Color(0x1F00BC00),
              lines: [
                Text(
                  'Штрихкод распознан',
                  style: AppTypography.labelMedium.copyWith(
                    color: palette.success,
                  ),
                ),
                Text(
                  'Нурофен, 200 мг',
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  'Таблетки · 20 шт.',
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
