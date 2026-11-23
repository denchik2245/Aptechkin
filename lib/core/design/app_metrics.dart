
/// Corner radii from the Figma variables `SM`, `MD`, `LG`, `XL`.
abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 100.0;

  /// Top corners of a bottom sheet.
  static const sheet = 28.0;

  /// Centered alert.
  static const alert = 28.0;
}

/// Layout constants shared by every screen of the 390 pt wide Figma frames.
abstract final class AppSpacing {
  /// Horizontal page padding.
  static const page = 16.0;

  /// Height of the navigation bar row below the status bar.
  static const navBar = 44.0;

  /// Gap between stacked cards.
  static const cardGap = 8.0;

  /// Widest content column on tablets and desktop web.
  static const maxContentWidth = 560.0;
}
