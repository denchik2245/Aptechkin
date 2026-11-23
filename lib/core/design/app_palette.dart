import 'package:flutter/material.dart';

/// Semantic colours named after the variables of the Figma file
/// «Аптечка», page «Дизайн» (671:828). Widgets read them through
/// `context.palette` instead of branching on brightness themselves.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brandPrimary,
    required this.background,
    required this.surfaceCard,
    required this.surfacePlate,
    required this.surfaceChoice,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnAccent,
    required this.textHeading,
    required this.divider,
    required this.buttonSecondary,
    required this.success,
    required this.warning,
    required this.fail,
    required this.tabSelection,
    required this.tabActive,
    required this.toastLink,
    required this.shadow,
    required this.scrim,
    required this.placeholder,
    required this.photoBackdrop,
    required this.iconTileNeutral,
  });

  /// `brand/primary`
  final Color brandPrimary;

  /// `background/primary`
  final Color background;

  /// `surface/card`
  final Color surfaceCard;

  /// `surface/plate`
  final Color surfacePlate;

  /// `surface/choice` — selected chips and toasts.
  final Color surfaceChoice;

  /// `text/primary`
  final Color textPrimary;

  /// `text/secondary` (#66647C) — the current secondary text colour.
  final Color textSecondary;

  /// Older `text/secondary` binding (#807E96) kept by the «Expiration date»
  /// component.
  final Color textMuted;

  /// `text/white`
  final Color textOnAccent;

  /// `Labels - Vibrant/Primary` — large screen titles.
  final Color textHeading;

  /// `divider/on white`
  final Color divider;

  /// `button/secondary`
  final Color buttonSecondary;

  /// `system/success`
  final Color success;

  /// `system/warning`
  final Color warning;

  /// `system/fail`
  final Color fail;

  /// `Fills - Vibrant/Tertiary` — selected tab capsule.
  final Color tabSelection;

  /// `Accents/Blue` — selected tab icon and label.
  final Color tabActive;

  /// Action text inside a toast.
  final Color toastLink;

  /// Card shadow, rgba(28, 26, 51, 0.08) in the light theme.
  final Color shadow;

  /// Dim layer behind sheets and alerts.
  final Color scrim;

  /// Placeholder of an empty «field» / «select» label (#B2B0C8).
  final Color placeholder;

  /// Backdrop of the full-screen package photo (879:14917), dark in both
  /// themes.
  final Color photoBackdrop;

  /// Grey tile behind a white settings icon («Помощь», «О приложении»):
  /// `text/secondary` in the light theme, darker in the dark one so the
  /// white icon stays readable.
  final Color iconTileNeutral;

  static const light = AppPalette(
    brandPrimary: Color(0xFF0075FF),
    background: Color(0xFFEAEEF7),
    surfaceCard: Color(0xFFFFFFFF),
    surfacePlate: Color(0xFFEAEEF7),
    surfaceChoice: Color(0xFF1C1A32),
    textPrimary: Color(0xFF1C1A32),
    textSecondary: Color(0xFF66647C),
    textMuted: Color(0xFF807E96),
    textOnAccent: Color(0xFFFFFFFF),
    textHeading: Color(0xFF1A1A1A),
    divider: Color(0xFFCCD0D9),
    buttonSecondary: Color(0xFFD6DAE3),
    success: Color(0xFF00BC00),
    warning: Color(0xFFFF9500),
    fail: Color(0xFFD62D30),
    tabSelection: Color(0xFFEDEDED),
    tabActive: Color(0xFF0088FF),
    toastLink: Color(0xFF6BB2FF),
    shadow: Color(0x141C1A33),
    scrim: Color(0x661C1A32),
    placeholder: Color(0xFFB2B0C8),
    photoBackdrop: Color(0xFF0D0D14),
    iconTileNeutral: Color(0xFF66647C),
  );

  static const dark = AppPalette(
    brandPrimary: Color(0xFF3D95FF),
    background: Color(0xFF13131C),
    surfaceCard: Color(0xFF20202D),
    surfacePlate: Color(0xFF2B2B3B),
    surfaceChoice: Color(0xFF3A3A4E),
    textPrimary: Color(0xFFF4F3FC),
    textSecondary: Color(0xFFB2B0C8),
    textMuted: Color(0xFFB2B0C8),
    textOnAccent: Color(0xFFFFFFFF),
    textHeading: Color(0xFFF4F3FC),
    divider: Color(0xFF3A3A4E),
    buttonSecondary: Color(0xFF3A3A4E),
    success: Color(0xFF2FD13A),
    warning: Color(0xFFFFA733),
    fail: Color(0xFFFF6B6E),
    tabSelection: Color(0xFF393A49),
    tabActive: Color(0xFF4DA8FF),
    toastLink: Color(0xFF8CC4FF),
    shadow: Color(0x40000000),
    scrim: Color(0x99000000),
    placeholder: Color(0xFF6E6C84),
    photoBackdrop: Color(0xFF0D0D14),
    iconTileNeutral: Color(0xFF55536B),
  );

  @override
  AppPalette copyWith({Color? brandPrimary, Color? background}) => AppPalette(
    brandPrimary: brandPrimary ?? this.brandPrimary,
    background: background ?? this.background,
    surfaceCard: surfaceCard,
    surfacePlate: surfacePlate,
    surfaceChoice: surfaceChoice,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textMuted: textMuted,
    textOnAccent: textOnAccent,
    textHeading: textHeading,
    divider: divider,
    buttonSecondary: buttonSecondary,
    success: success,
    warning: warning,
    fail: fail,
    tabSelection: tabSelection,
    tabActive: tabActive,
    toastLink: toastLink,
    shadow: shadow,
    scrim: scrim,
    placeholder: placeholder,
    photoBackdrop: photoBackdrop,
    iconTileNeutral: iconTileNeutral,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brandPrimary: mix(brandPrimary, other.brandPrimary),
      background: mix(background, other.background),
      surfaceCard: mix(surfaceCard, other.surfaceCard),
      surfacePlate: mix(surfacePlate, other.surfacePlate),
      surfaceChoice: mix(surfaceChoice, other.surfaceChoice),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      textOnAccent: mix(textOnAccent, other.textOnAccent),
      textHeading: mix(textHeading, other.textHeading),
      divider: mix(divider, other.divider),
      buttonSecondary: mix(buttonSecondary, other.buttonSecondary),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      fail: mix(fail, other.fail),
      tabSelection: mix(tabSelection, other.tabSelection),
      tabActive: mix(tabActive, other.tabActive),
      toastLink: mix(toastLink, other.toastLink),
      shadow: mix(shadow, other.shadow),
      scrim: mix(scrim, other.scrim),
      placeholder: mix(placeholder, other.placeholder),
      photoBackdrop: mix(photoBackdrop, other.photoBackdrop),
      iconTileNeutral: mix(iconTileNeutral, other.iconTileNeutral),
    );
  }
}
