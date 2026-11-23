import 'package:aptechka/app/app_info.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/settings_list.dart';
import 'package:aptechka/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';

/// «Настройки / О приложении» (1161:25515). «Политика конфиденциальности» and
/// «Пользовательское соглашение» wait for the real documents.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final note = AppTypography.bodySmall.copyWith(color: palette.textSecondary);
    return SettingsPage(
      title: 'О приложении',
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              const _AppIcon(),
              const SizedBox(height: 8),
              Text(
                'Аптечка',
                style: AppTypography.h2.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 8),
              Text('Версия ${AppInfo.version} (${AppInfo.build})', style: note),
            ],
          ),
        ),
        SettingsCard(
          child: Text(
            'Помогает вести учёт лекарств дома и следовать назначенному '
            'расписанию. Не заменяет консультацию врача: схему лечения '
            'назначает специалист.',
            style: note,
          ),
        ),
        SettingsSection(
          title: 'Ваши данные',
          child: SettingsCard(
            child: Text(
              'Всё хранится только на этом телефоне и никуда не отправляется. '
              'Резервную копию вы сохраняете сами — в файл, который не '
              'зашифрован.',
              style: note,
            ),
          ),
        ),
        SettingsGroup.icons(
          children: [
            SettingsRow(
              icon: 'doc',
              iconColor: palette.iconTileNeutral,
              title: 'Лицензии',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Аптечка',
                applicationVersion: AppInfo.version,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// «app icon» (1161:25586): 72 pt brand square, radius 18, white cross.
class _AppIcon extends StatelessWidget {
  const _AppIcon();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget bar(double left, double top, double width, double height) =>
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.textOnAccent,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        );
    return ExcludeSemantics(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: palette.brandPrimary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(children: [bar(20, 31, 32, 10), bar(31, 20, 10, 32)]),
      ),
    );
  }
}
