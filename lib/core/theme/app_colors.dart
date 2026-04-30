import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================
  // COLORES PRINCIPALES — Paleta Verde Ambiente
  // Basada en el verde del logo de la emisora
  // ============================================

  static const Color primary = Color(0xFF3CAF3C);    // Verde logo
  static const Color secondary = Color(0xFF56C956);  // Verde más claro
  static const Color accent = Color(0xFF86EFAC);     // Menta suave

  // ============================================
  // FONDOS Y SUPERFICIES — tono bosque oscuro
  // ============================================

  static const Color background = Color(0xFF070D07);
  static const Color surface = Color(0xFF0F1A0F);
  static const Color surfaceVariant = Color(0xFF172517);
  static const Color cardBackground = Color(0xFF0F1A0F);

  // ============================================
  // TEXTO
  // ============================================

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF6B8F6B);
  static const Color textMuted = Color(0xFF94A394);

  // ============================================
  // ESTADOS
  // ============================================

  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF3CAF3C);
  static const Color warning = Color(0xFFF59E0B);
  static const Color liveIndicator = Color(0xFFEF4444);

  // ============================================
  // GRADIENTES
  // ============================================

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F1A0F), Color(0xFF070D07)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3CAF3C), Color(0xFF2E962E)],
  );

  static const LinearGradient logo = LinearGradient(
    colors: [Color(0xFFFEFEFF), Color(0xFFFAFAFA)],
  );

  // Disco de vinilo: verde oscuro metálico, como vinilo verde edición especial
  static const RadialGradient discGradient = RadialGradient(
    colors: [Color(0xFF2D4A2D), Color(0xFF1A2E1A), Color(0xFF0F1A0F)],
  );

  // ============================================
  // MÉTODOS UTILITARIOS
  // ============================================

  static Color primaryWithOpacity(double opacity) =>
      primary.withValues(alpha: opacity);

  static Color surfaceWithOpacity(double opacity) =>
      surface.withValues(alpha: opacity);

  static Color getShadowColor(BuildContext context, {double opacity = 0.3}) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return Colors.black.withValues(alpha: isTablet ? opacity * 1.2 : opacity);
  }

  static Color getOverlayColor(BuildContext context, {double baseOpacity = 0.1}) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return primary.withValues(alpha: isTablet ? baseOpacity * 0.8 : baseOpacity);
  }

  static LinearGradient getAdaptiveButtonGradient(BuildContext context) =>
      buttonGradient;

  static Color getBorderColor(BuildContext context, {double opacity = 0.15}) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return primary.withValues(alpha: isTablet ? opacity * 1.1 : opacity);
  }

  static Color getErrorColor(BuildContext context, {double opacity = 1.0}) =>
      error.withValues(alpha: opacity);

  static Color getSuccessColor(BuildContext context, {double opacity = 1.0}) =>
      success.withValues(alpha: opacity);

  static Color getWarningColor(BuildContext context, {double opacity = 1.0}) =>
      warning.withValues(alpha: opacity);

  static Color getAdaptiveTextColor(
    BuildContext context, {
    required Color backgroundColor,
    Color? lightText,
    Color? darkText,
  }) {
    final light = lightText ?? textPrimary;
    final dark = darkText ?? const Color(0xFF070D07);
    return backgroundColor.computeLuminance() > 0.5 ? dark : light;
  }

  static Color getSurfaceColor(int elevation) {
    switch (elevation) {
      case 0: return surface;
      case 1: return Color.lerp(surface, Colors.white, 0.04)!;
      case 2: return Color.lerp(surface, Colors.white, 0.06)!;
      case 3: return Color.lerp(surface, Colors.white, 0.08)!;
      case 4: return Color.lerp(surface, Colors.white, 0.09)!;
      case 6: return Color.lerp(surface, Colors.white, 0.11)!;
      case 8: return Color.lerp(surface, Colors.white, 0.12)!;
      case 12: return Color.lerp(surface, Colors.white, 0.14)!;
      case 16: return Color.lerp(surface, Colors.white, 0.15)!;
      case 24: return Color.lerp(surface, Colors.white, 0.16)!;
      default: return surface;
    }
  }

  static LinearGradient getCardGradient(BuildContext context) =>
      const LinearGradient(colors: [surface, surfaceVariant]);

  static const List<Color> accentPalette = [
    Color(0xFF3CAF3C),
    Color(0xFF56C956),
    Color(0xFF86EFAC),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  static Color getAccentColor(int index) =>
      accentPalette[index % accentPalette.length];
}
