import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_toast.dart';
import 'package:aptechka/core/ui/nav_bars.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A sub-screen of «Настройки»: «nav bar / title» and blocks 24 pt apart,
/// starting 20 pt below the bar. The tab bar comes from the shell.
class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.background,
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          TitleNavBar(title: title),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 132),
                  children: spacedBlocks(children),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// [blocks] with the 24 pt gap of the settings screens between them.
List<Widget> spacedBlocks(List<Widget> blocks) => [
  for (final (i, block) in blocks.indexed) ...[
    if (i > 0) const SizedBox(height: 24),
    block,
  ],
];

/// Saves `update(current settings)`; a toast tells when saving failed.
Future<void> saveSettings(
  BuildContext context,
  WidgetRef ref,
  AppSettings Function(AppSettings settings) update,
) async {
  final controller = ref.read(appControllerProvider.notifier);
  final current = ref.read(appControllerProvider).requireValue.settings;
  try {
    await controller.updateSettings(update(current));
  } catch (_) {
    if (context.mounted) {
      showAppToast(context, 'Не удалось сохранить. Попробуйте ещё раз.');
    }
  }
}
