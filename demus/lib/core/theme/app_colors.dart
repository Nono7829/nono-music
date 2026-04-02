import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color background      = Color(0xFF000000);
  static const Color surfaceLowest   = Color(0xFF0A0A0A);
  static const Color surface         = Color(0xFF141414);
  static const Color surfaceElevated = Color(0xFF1C1C1E);
  static const Color surfaceHighlight = Color(0xFF2C2C2E);
  static const Color surfaceOverlay  = Color(0xFF3A3A3C);

  // ── Accent ───────────────────────────────────────────────────────────────
  static const Color accent       = Color(0xFFFF375F);
  static const Color accentSoft   = Color(0xFFFF6B8A);
  static const Color accentOrange = Color(0xFFFF9F0A);
  static const Color accentGreen  = Color(0xFF32D74B);
  static const Color accentBlue   = Color(0xFF0A84FF);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textTertiary  = Color(0xFF666666);
  static const Color textDisabled  = Color(0xFF444444);

  // ── Borders ──────────────────────────────────────────────────────────────
  static const Color borderSubtle  = Color(0xFF1A1A1A);
  static const Color borderDefault = Color(0xFF2C2C2E);
  static const Color borderStrong  = Color(0xFF48484A);

  // ── Nav bar specific ─────────────────────────────────────────────────────
  static const Color navBackground = Color(0xFF111111);
  static const Color navBorder     = Color(0x1AFFFFFF); // 10% white

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color error   = Color(0xFFFF453A);
  static const Color warning = Color(0xFFFFD60A);
  static const Color success = accentGreen;

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradientVertical = LinearGradient(
    colors: [accent, Color(0xFFFF6B35)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardFadeBottom = LinearGradient(
    colors: [Colors.transparent, Color(0xCC000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}