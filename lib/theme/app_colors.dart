import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary (Warm Emerald Green)
  static const Color primary = Color(0xFF00875A);
  static const Color primaryDark = Color(0xFF005A3C);
  static const Color primaryLight = Color(0xFFE3F7EC);
  static const Color primaryContainer = Color(0xFFB5EAD1);

  // Brand Secondary (Warm Orange / Amber)
  static const Color secondary = Color(0xFFFF6B35);
  static const Color secondaryDark = Color(0xFFD64D18);
  static const Color secondaryLight = Color(0xFFFFF0E9);
  static const Color secondaryContainer = Color(0xFFFFD5C2);

  // Accent & Highlights
  static const Color accentYellow = Color(0xFFFFB800);
  static const Color accentBlue = Color(0xFF0065FF);
  static const Color accentPurple = Color(0xFF6554C0);

  // Background & Surfaces
  static const Color background = Color(0xFFF7F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F4F2);
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Status Colors
  static const Color availableGreen = Color(0xFF10B981);
  static const Color availableGreenBg = Color(0xFFDCFCE7);
  static const Color busyOrange = Color(0xFFF97316);
  static const Color busyOrangeBg = Color(0xFFFFEDD5);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedBg = Color(0xFFFEE2E2);

  // Text Colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Colors.white;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00875A), Color(0xFF00B377)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmOrangeGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aiBannerGradient = LinearGradient(
    colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
