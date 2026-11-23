import 'package:flutter/material.dart';

/// Text styles from the Figma file. Names follow the Figma style names;
/// colour is applied by the caller (usually from [AppPalette]).
///
/// Figma «line height 100» is rendered as the font's natural line height,
/// which matches `leading-[normal]` in the exported reference code.
abstract final class AppTypography {
  static const family = 'Manrope';

  /// Heading/H1 — 32/800, screen titles.
  static const h1 = TextStyle(
    fontFamily: family,
    fontSize: 32,
    fontWeight: FontWeight.w800,
  );

  /// Heading/H1 with 1.1 line height — onboarding headlines.
  static const h1Tight = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w800,
  );

  /// Heading/H2 — 24/700, line height 1.2.
  static const h2 = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  /// Headline/Regular — nav bar titles (SF Pro 17/590 in Figma, Manrope here).
  static const headline = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 22 / 17,
    letterSpacing: -0.43,
    fontWeight: FontWeight.w600,
  );

  /// Heading/H3 — 20/700, line height 1.2.
  static const h3 = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  /// Body/Large — 18/700.
  static const bodyLarge = TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// Body/Medium — 16/700.
  static const bodyMedium = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  /// Body/Paragraph — 16/400, line height 1.4.
  static const paragraph = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  /// Body/Small — 14/400.
  static const bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// Label/Large — 14/600.
  static const labelLarge = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Label/Medium — 12/600.
  static const labelMedium = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// Caption/Small — 12/400.
  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Button/Default — 16/700, line height 1.
  static const button = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: FontWeight.w700,
  );

  /// Button/Small — 10/700, line height 1 (tab bar labels).
  static const buttonSmall = TextStyle(
    fontFamily: family,
    fontSize: 10,
    height: 1,
    fontWeight: FontWeight.w700,
  );
}
