import 'package:aptechka/core/design/app_palette.dart';
import 'package:flutter/material.dart';

export 'app_metrics.dart';
export 'app_palette.dart';
export 'app_typography.dart';

extension DesignContext on BuildContext {
  /// Semantic colours for the current theme.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
