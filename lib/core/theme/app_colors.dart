import 'package:flutter/material.dart';

/// Clase que define la paleta de colores de la aplicación
///
/// Proporciona colores estáticos para el tema oscuro y métodos
/// utilitarios para obtener variaciones adaptativas según el
/// tamaño de pantalla y contexto de uso
class AppColors {
  // ============================================
  // COLORES PRINCIPALES
  // ============================================

  /// Color primario de la marca (índigo)
  static const Color primary = Color(0xFF6366F1);

  /// Color secundario (violeta)
  static const Color secondary = Color(0xFF8B5CF6);

  /// Color de acento (slate blue)
  static const Color accent = Color(0xFF7B68EE);

  // ============================================
  // COLORES DE FONDO
  // ============================================

  /// Color de fondo principal de la aplicación (azul oscuro profundo)
  static const Color background = Color(0xFF0F172A);

  /// Color de superficie para cards y elementos elevados (azul oscuro)
  static const Color surface = Color(0xFF1E293B);

  /// Color de fondo para tarjetas (mismo que surface)
  static const Color cardBackground = Color(0xFF1E293B);

  // ============================================
  // COLORES DE TEXTO
  // ============================================

  /// Color de texto principal (blanco)
  static const Color textPrimary = Colors.white;

  /// Color de texto secundario (gris azulado)
  static const Color textSecondary = Color(0xFF64748B);

  /// Color de texto atenuado (gris claro)
  static const Color textMuted = Color(0xFFCBD5E1);

  // ============================================
  // COLORES DE ESTADO
  // ============================================

  /// Color para estados de error
  static const Color error = Colors.red;

  /// Color para estados exitosos (verde)
  static const Color success = Color(0xFF10B981);

  /// Color para advertencias (amarillo/naranja)
  static const Color warning = Color(0xFFF59E0B);

  /// Color del indicador de transmisión en vivo (rojo)
  static const Color liveIndicator = Colors.red;

  // ============================================
  // GRADIENTES PRINCIPALES
  // ============================================

  /// Gradiente principal de fondo (de surface a background)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  /// Gradiente para botones (de primary a secondary)
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );

  /// Gradiente para el logo (blanco)
  static const LinearGradient logo = LinearGradient(
    colors: [
      Color.fromARGB(255, 254, 254, 255),
      Color.fromARGB(255, 250, 250, 250),
    ],
  );

  /// Gradiente radial para el disco de vinilo animado
  static const RadialGradient discGradient = RadialGradient(
    colors: [Color(0xFF6366F1), Color(0xFF3730A3), Color(0xFF1E1B4B)],
  );

  // ============================================
  // MÉTODOS UTILITARIOS - OPACIDAD
  // ============================================

  /// Obtiene una variante del color primario con opacidad personalizada
  ///
  /// [opacity] - Valor entre 0.0 (transparente) y 1.0 (opaco)
  static Color primaryWithOpacity(double opacity) =>
      primary.withValues(alpha: opacity);

  /// Obtiene una variante del color de superficie con opacidad personalizada
  ///
  /// [opacity] - Valor entre 0.0 (transparente) y 1.0 (opaco)
  static Color surfaceWithOpacity(double opacity) =>
      surface.withValues(alpha: opacity);

  // ============================================
  // MÉTODOS UTILITARIOS - COLORES ADAPTATIVOS
  // ============================================

  /// Obtiene un color de sombra adaptativo según el dispositivo
  ///
  /// En tablets, las sombras son ligeramente más pronunciadas
  ///
  /// [opacity] - Opacidad base de la sombra (por defecto 0.15)
  static Color getShadowColor(BuildContext context, {double opacity = 0.15}) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return Colors.black.withValues(alpha: isTablet ? opacity * 1.2 : opacity);
  }

  /// Obtiene un color de overlay adaptativo según el dispositivo
  ///
  /// En tablets, los overlays son ligeramente más sutiles
  ///
  /// [baseOpacity] - Opacidad base del overlay (por defecto 0.2)
  static Color getOverlayColor(
    BuildContext context, {
    double baseOpacity = 0.2,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return primary.withValues(
      alpha: isTablet ? baseOpacity * 0.8 : baseOpacity,
    );
  }

  /// Obtiene un gradiente de botón adaptativo según el dispositivo
  ///
  /// En tablets, el gradiente es más sutil (90% de opacidad)
  static LinearGradient getAdaptiveButtonGradient(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    if (isTablet) {
      return LinearGradient(
        colors: [
          primary.withValues(alpha: 0.9),
          secondary.withValues(alpha: 0.9),
        ],
      );
    }

    return buttonGradient;
  }

  /// Obtiene un color de borde adaptativo según el dispositivo
  ///
  /// [opacity] - Opacidad base del borde (por defecto 0.3)
  static Color getBorderColor(BuildContext context, {double opacity = 0.3}) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return primary.withValues(alpha: isTablet ? opacity * 1.1 : opacity);
  }

  // ============================================
  // COLORES DE ESTADO CON OPACIDAD
  // ============================================

  /// Obtiene el color de error con opacidad personalizada
  static Color getErrorColor(BuildContext context, {double opacity = 1.0}) {
    return error.withValues(alpha: opacity);
  }

  /// Obtiene el color de éxito con opacidad personalizada
  static Color getSuccessColor(BuildContext context, {double opacity = 1.0}) {
    return success.withValues(alpha: opacity);
  }

  /// Obtiene el color de advertencia con opacidad personalizada
  static Color getWarningColor(BuildContext context, {double opacity = 1.0}) {
    return warning.withValues(alpha: opacity);
  }

  // ============================================
  // COLORES BASADOS EN CONTRASTE
  // ============================================

  /// Obtiene un color de texto adaptativo según el contraste del fondo
  ///
  /// Calcula la luminancia del color de fondo y retorna texto claro
  /// u oscuro según sea necesario para mantener legibilidad
  ///
  /// [backgroundColor] - Color de fondo sobre el que se mostrará el texto
  /// [lightText] - Color de texto claro (por defecto textPrimary)
  /// [darkText] - Color de texto oscuro (por defecto gris oscuro)
  static Color getAdaptiveTextColor(
    BuildContext context, {
    required Color backgroundColor,
    Color? lightText,
    Color? darkText,
  }) {
    final light = lightText ?? textPrimary;
    final dark = darkText ?? const Color(0xFF1F2937);

    // Calcular luminancia: >0.5 es claro, <=0.5 es oscuro
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? dark : light;
  }

  // ============================================
  // COLORES POR ELEVACIÓN
  // ============================================

  /// Obtiene un color de superficie según el nivel de elevación
  ///
  /// Implementa el sistema de elevación de Material Design mezclando
  /// el color de superficie con blanco según la elevación
  ///
  /// [elevation] - Nivel de elevación (0, 1, 2, 3, 4, 6, 8, 12, 16, 24)
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

  // ============================================
  // GRADIENTES CONTEXTUALES
  // ============================================

  /// Obtiene un gradiente adaptativo para tarjetas según el dispositivo
  ///
  /// En tablets usa un gradiente sutil, en móviles usa color sólido
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

    return LinearGradient(colors: [surface, surface]);
  }

  // ============================================
  // PALETA DE ACENTOS
  // ============================================

  /// Paleta de colores de acento para diferentes estados y contextos
  static const List<Color> accentPalette = [
    Color(0xFF6366F1), // primary
    Color(0xFF8B5CF6), // secondary
    Color(0xFF7B68EE), // accent
    Color(0xFF10B981), // success
    Color(0xFFF59E0B), // warning
    Color(0xFFEF4444), // error
  ];

  /// Obtiene un color de acento por índice circular
  ///
  /// Útil para asignar colores distintos a múltiples elementos
  /// El índice se ajusta automáticamente usando módulo
  ///
  /// [index] - Índice del color deseado
  static Color getAccentColor(int index) {
    return accentPalette[index % accentPalette.length];
  }
}
