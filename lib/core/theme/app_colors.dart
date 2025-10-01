import 'package:flutter/material.dart';

class AppColors {
  // Colores principales (tema oscuro)
  static const Color primary = Color(0xFF6366F1);
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color accent = Color(0xFF7B68EE);

  // Colores de fondo
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color cardBackground = Color(0xFF1E293B);

  // Colores de texto
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFFCBD5E1);

  // Colores de estado
  static const Color error = Colors.red;
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color liveIndicator = Colors.red;

  // Gradientes principales
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );

  static const RadialGradient discGradient = RadialGradient(
    colors: [Color(0xFF6366F1), Color(0xFF3730A3), Color(0xFF1E1B4B)],
  );

  // Métodos utilitarios para responsividad y variaciones

  /// Obtiene una variante del color primario con opacidad
  static Color primaryWithOpacity(double opacity) =>
      primary.withValues(alpha: opacity);

  /// Obtiene una variante del color de superficie con opacidad
  static Color surfaceWithOpacity(double opacity) =>
      surface.withValues(alpha: opacity);

  /// Obtiene colores de sombra adaptativos según el dispositivo
  static Color getShadowColor(BuildContext context, {double opacity = 0.15}) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    // En tablets, sombras ligeramente más pronunciadas
    return Colors.black.withValues(alpha: isTablet ? opacity * 1.2 : opacity);
  }

  /// Obtiene opacidad de overlay adaptativa
  static Color getOverlayColor(
    BuildContext context, {
    double baseOpacity = 0.2,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    // En tablets, overlays ligeramente más sutiles
    return primary.withValues(
      alpha: isTablet ? baseOpacity * 0.8 : baseOpacity,
    );
  }

  /// Gradiente adaptativo para botones según el dispositivo
  static LinearGradient getAdaptiveButtonGradient(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    if (isTablet) {
      // En tablets, gradiente más sutil
      return LinearGradient(
        colors: [
          primary.withValues(alpha: 0.9),
          secondary.withValues(alpha: 0.9),
        ],
      );
    }

    return buttonGradient;
  }

  /// Obtiene color de borde adaptativo
  static Color getBorderColor(BuildContext context, {double opacity = 0.3}) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return primary.withValues(alpha: isTablet ? opacity * 1.1 : opacity);
  }

  /// Colores de estado con opacidad adaptativa
  static Color getErrorColor(BuildContext context, {double opacity = 1.0}) {
    return error.withValues(alpha: opacity);
  }

  static Color getSuccessColor(BuildContext context, {double opacity = 1.0}) {
    return success.withValues(alpha: opacity);
  }

  static Color getWarningColor(BuildContext context, {double opacity = 1.0}) {
    return warning.withValues(alpha: opacity);
  }

  /// Obtiene color de texto adaptativo según contraste
  static Color getAdaptiveTextColor(
    BuildContext context, {
    required Color backgroundColor,
    Color? lightText,
    Color? darkText,
  }) {
    // Usar valores por defecto si no se proporcionan
    final light = lightText ?? textPrimary;
    final dark = darkText ?? const Color(0xFF1F2937);

    // Calcular luminancia para determinar contraste
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? dark : light;
  }

  /// Colores para diferentes elevaciones de superficie
  static Color getSurfaceColor(int elevation) {
    switch (elevation) {
      case 0:
        return surface;
      case 1:
        return Color.lerp(surface, Colors.white, 0.05)!;
      case 2:
        return Color.lerp(surface, Colors.white, 0.07)!;
      case 3:
        return Color.lerp(surface, Colors.white, 0.08)!;
      case 4:
        return Color.lerp(surface, Colors.white, 0.09)!;
      case 6:
        return Color.lerp(surface, Colors.white, 0.11)!;
      case 8:
        return Color.lerp(surface, Colors.white, 0.12)!;
      case 12:
        return Color.lerp(surface, Colors.white, 0.14)!;
      case 16:
        return Color.lerp(surface, Colors.white, 0.15)!;
      case 24:
        return Color.lerp(surface, Colors.white, 0.16)!;
      default:
        return surface;
    }
  }

  /// Gradientes adicionales para diferentes contextos
  static LinearGradient getCardGradient(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    if (isTablet) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [getSurfaceColor(2), getSurfaceColor(1)],
      );
    }

    return LinearGradient(
      colors: [surface, surface], // Sólido en teléfonos
    );
  }

  /// Paleta de colores de acento para diferentes estados
  static const List<Color> accentPalette = [
    Color(0xFF6366F1), // primary
    Color(0xFF8B5CF6), // secondary
    Color(0xFF7B68EE), // accent
    Color(0xFF10B981), // success
    Color(0xFFF59E0B), // warning
    Color(0xFFEF4444), // error
  ];

  /// Obtiene un color de acento por índice
  static Color getAccentColor(int index) {
    return accentPalette[index % accentPalette.length];
  }
}
