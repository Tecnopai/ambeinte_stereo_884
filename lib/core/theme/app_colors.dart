import 'package:flutter/material.dart';

/// {@template app_colors}
/// Clase que define la paleta de colores estáticos de la aplicación.
///
/// Proporciona colores base, gradientes y métodos utilitarios para obtener
/// variaciones adaptativas según el contexto de uso y el factor de escala
/// de pantalla (móvil o tablet).
/// {@endtemplate}
class AppColors {
  /// Constructor privado para evitar la instanciación de esta clase utilitaria.
  AppColors._();

  // ============================================
  // COLORES PRINCIPALES DE MARCA
  // ============================================

  /// Color primario de la marca (índigo o violeta oscuro).
  static const Color primary = Color(0xFF6366F1);

  /// Color secundario de la marca (violeta).
  static const Color secondary = Color(0xFF8B5CF6);

  /// Color de acento utilizado para resaltar elementos (slate blue).
  static const Color accent = Color(0xFF7B68EE);

  // ============================================
  // COLORES DE FONDO Y SUPERFICIE
  // ============================================

  /// Color de fondo principal de la aplicación (azul oscuro profundo).
  static const Color background = Color(0xFF0F172A);

  /// Color de superficie para cards, app bars y elementos elevados (azul oscuro).
  static const Color surface = Color(0xFF1E293B);

  /// Color de fondo para tarjetas. Mismo que [surface].
  static const Color cardBackground = Color(0xFF1E293B);

  // ============================================
  // COLORES DE TEXTO
  // ============================================

  /// Color de texto principal (blanco).
  static const Color textPrimary = Colors.white;

  /// Color de texto secundario (gris azulado), utilizado para subtítulos.
  static const Color textSecondary = Color(0xFF64748B);

  /// Color de texto atenuado (gris claro), utilizado para descripciones o texto menos importante.
  static const Color textMuted = Color(0xFFCBD5E1);

  // ============================================
  // COLORES DE ESTADO
  // ============================================

  /// Color para estados de error (rojo estándar).
  static const Color error = Colors.red;

  /// Color para estados exitosos (verde).
  static const Color success = Color(0xFF10B981);

  /// Color para advertencias (amarillo/naranja).
  static const Color warning = Color(0xFFF59E0B);

  /// Color del indicador de transmisión en vivo (rojo brillante).
  static const Color liveIndicator = Colors.red;

  // ============================================
  // GRADIENTES PRINCIPALES ESTÁTICOS
  // ============================================

  /// Gradiente principal de fondo (de [surface] a [background]).
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  /// Gradiente para botones principales (de [primary] a [secondary]).
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );

  /// Gradiente para el logo, simulando un brillo blanco.
  static const LinearGradient logo = LinearGradient(
    colors: [
      Color.fromARGB(255, 254, 254, 255),
      Color.fromARGB(255, 250, 250, 250),
    ],
  );

  /// Gradiente radial para el disco de vinilo animado en el reproductor.
  static const RadialGradient discGradient = RadialGradient(
    colors: [Color(0xFF6366F1), Color(0xFF3730A3), Color(0xFF1E1B4B)],
  );

  // ============================================
  // MÉTODOS UTILITARIOS - OPACIDAD
  // ============================================

  /// Obtiene una variante del color primario con opacidad personalizada.
  ///
  /// Utiliza `.withValues(alpha: ...)` para evitar pérdidas de precisión.
  ///
  /// @param opacity Valor de opacidad (alpha) entre 0.0 (transparente) y 1.0 (opaco).
  /// @return Color primario con la opacidad especificada.
  static Color primaryWithOpacity(double opacity) =>
      primary.withValues(alpha: opacity);

  /// Obtiene una variante del color de superficie con opacidad personalizada.
  ///
  /// @param opacity Valor de opacidad (alpha) entre 0.0 (transparente) y 1.0 (opaco).
  /// @return Color de superficie con la opacidad especificada.
  static Color surfaceWithOpacity(double opacity) =>
      surface.withValues(alpha: opacity);

  // ============================================
  // MÉTODOS UTILITARIOS - COLORES ADAPTATIVOS
  // ============================================

  /// Obtiene un color de sombra adaptativo según el dispositivo (móvil o tablet).
  ///
  /// Las sombras son ligeramente más pronunciadas en tablets (multiplicador de 1.2).
  ///
  /// @param context Contexto de construcción del widget.
  /// @param opacity Opacidad base de la sombra (por defecto 0.15).
  /// @return Color negro con opacidad adaptada.
  static Color getShadowColor(BuildContext context, {double opacity = 0.15}) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    // Aumenta la opacidad en tablets.
    return Colors.black.withValues(alpha: isTablet ? opacity * 1.2 : opacity);
  }

  /// Obtiene un color de overlay (superposición) adaptativo según el dispositivo.
  ///
  /// Los overlays son ligeramente más sutiles en tablets (multiplicador de 0.8).
  ///
  /// @param context Contexto de construcción del widget.
  /// @param baseOpacity Opacidad base del overlay (por defecto 0.2).
  /// @return Color primario con opacidad adaptada.
  static Color getOverlayColor(
    BuildContext context, {
    double baseOpacity = 0.2,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    // Reduce la opacidad en tablets.
    return primary.withValues(
      alpha: isTablet ? baseOpacity * 0.8 : baseOpacity,
    );
  }

  /// Obtiene un gradiente de botón adaptativo según el dispositivo.
  ///
  /// En tablets, el gradiente es más sutil (90% de opacidad) para mejor integración.
  ///
  /// @param context Contexto de construcción del widget.
  /// @return [LinearGradient] adaptativo.
  static LinearGradient getAdaptiveButtonGradient(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    if (isTablet) {
      // Gradiente más sutil para tablets.
      return LinearGradient(
        colors: [
          primary.withValues(alpha: 0.9),
          secondary.withValues(alpha: 0.9),
        ],
      );
    }

    // Gradiente normal para móviles.
    return buttonGradient;
  }

  /// Obtiene un color de borde adaptativo.
  ///
  /// El borde es ligeramente más pronunciado en tablets.
  ///
  /// @param context Contexto de construcción del widget.
  /// @param opacity Opacidad base del borde (por defecto 0.3).
  /// @return Color primario con opacidad adaptada.
  static Color getBorderColor(BuildContext context, {double opacity = 0.3}) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    // Aumenta la opacidad en tablets.
    return primary.withValues(alpha: isTablet ? opacity * 1.1 : opacity);
  }

  // ============================================
  // COLORES DE ESTADO CON OPACIDAD (Wrappers)
  // ============================================

  /// Obtiene el color de [error] con opacidad personalizada.
  ///
  /// @param context Contexto de construcción del widget.
  /// @param opacity Opacidad deseada (por defecto 1.0).
  /// @return Color de error con opacidad.
  static Color getErrorColor(BuildContext context, {double opacity = 1.0}) {
    return error.withValues(alpha: opacity);
  }

  /// Obtiene el color de [success] con opacidad personalizada.
  ///
  /// @param context Contexto de construcción del widget.
  /// @param opacity Opacidad deseada (por defecto 1.0).
  /// @return Color de éxito con opacidad.
  static Color getSuccessColor(BuildContext context, {double opacity = 1.0}) {
    return success.withValues(alpha: opacity);
  }

  /// Obtiene el color de [warning] con opacidad personalizada.
  ///
  /// @param context Contexto de construcción del widget.
  /// @param opacity Opacidad deseada (por defecto 1.0).
  /// @return Color de advertencia con opacidad.
  static Color getWarningColor(BuildContext context, {double opacity = 1.0}) {
    return warning.withValues(alpha: opacity);
  }

  // ============================================
  // COLORES BASADOS EN CONTRASTE
  // ============================================

  /// Obtiene un color de texto adaptativo según la luminancia del color de fondo.
  ///
  /// Garantiza la legibilidad retornando texto claro ([lightText]) si el fondo
  /// es oscuro, o texto oscuro ([darkText]) si el fondo es claro.
  ///
  /// @param context Contexto de construcción del widget.
  /// @param backgroundColor Color de fondo sobre el que se mostrará el texto.
  /// @param lightText Color de texto a usar para fondos oscuros (por defecto [textPrimary]).
  /// @param darkText Color de texto a usar para fondos claros (por defecto gris oscuro).
  /// @return Color de texto con alto contraste.
  static Color getAdaptiveTextColor(
    BuildContext context, {
    required Color backgroundColor,
    Color? lightText,
    Color? darkText,
  }) {
    final light = lightText ?? textPrimary;
    final dark = darkText ?? const Color(0xFF1F2937);

    // Si la luminancia es > 0.5 (claro), retorna el color oscuro.
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? dark : light;
  }

  // ============================================
  // COLORES POR ELEVACIÓN (Material 3 Dark Theme)
  // ============================================

  /// Obtiene un color de superficie según el nivel de elevación.
  ///
  /// Implementa el sistema de elevación de Material Design Dark Theme,
  /// mezclando el color de superficie con blanco para simular luz ambiental.
  ///
  /// @param elevation Nivel de elevación (ej. 0, 1, 4, 8, 24).
  /// @return Color de superficie con el tono de elevación correcto.
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

  /// Obtiene un gradiente adaptativo para tarjetas.
  ///
  /// En tablets usa un gradiente sutil para dar profundidad, en móviles usa color sólido.
  ///
  /// @param context Contexto de construcción del widget.
  /// @return [LinearGradient] para tarjetas.
  static LinearGradient getCardGradient(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    if (isTablet) {
      // Un gradiente sutil con diferentes niveles de elevación.
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [getSurfaceColor(2), getSurfaceColor(1)],
      );
    }

    // Color sólido para móviles (sin gradiente visible).
    return const LinearGradient(colors: [surface, surface]);
  }

  // ============================================
  // PALETA DE ACENTOS DINÁMICA
  // ============================================

  /// Paleta de colores de acento base para diferentes estados y contextos.
  static const List<Color> accentPalette = [
    Color(0xFF6366F1), // primary
    Color(0xFF8B5CF6), // secondary
    Color(0xFF7B68EE), // accent
    Color(0xFF10B981), // success
    Color(0xFFF59E0B), // warning
    Color(0xFFEF4444), // error
  ];

  /// Obtiene un color de acento por índice de forma circular.
  ///
  /// Útil para asignar colores distintos a múltiples elementos en una lista (ej. categorías).
  ///
  /// @param index Índice del color deseado.
  /// @return Color de [accentPalette] ajustado automáticamente por módulo.
  static Color getAccentColor(int index) {
    return accentPalette[index % accentPalette.length];
  }
}
