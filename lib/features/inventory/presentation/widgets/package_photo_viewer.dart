import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/data/drug_photo_catalog.dart';
import 'package:flutter/material.dart';

/// Figma «Фото / Во весь экран» (879:14917): the package photo on a dark
/// backdrop with a close button and the photo credit. «Заменить фото» and
/// «Удалить фото» need the user's own photos, which the app cannot take
/// yet, so the catalog photo is only shown.
Future<void> showPackagePhoto(
  BuildContext context, {
  required DrugPhoto photo,
  required String name,
}) => Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: true,
    fullscreenDialog: true,
    pageBuilder: (_, _, _) => _PhotoViewer(photo: photo, name: name),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  ),
);

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo, required this.name});
  final DrugPhoto photo;
  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.photoBackdrop,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: 'Закрыть',
                child: Tooltip(
                  message: 'Закрыть',
                  child: InkResponse(
                    onTap: () => Navigator.of(context).pop(),
                    radius: 24,
                    child: const DesignIcon('photo-close-44', size: 44),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ColoredBox(
                      color: Colors.white,
                      child: SizedBox.expand(
                        child: InteractiveViewer(
                          maxScale: 4,
                          child: Image.asset(
                            photo.asset,
                            fit: BoxFit.contain,
                            semanticLabel:
                                'Фото упаковки ${readableDrugName(name)}',
                            errorBuilder: (_, _, _) => const Center(
                              child: DesignIcon('form-bandage-24', size: 24),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Фото упаковки · ${photo.credit.replaceFirst('Фото: ', '')}',
                style: AppTypography.bodySmall.copyWith(
                  color: palette.textOnAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
