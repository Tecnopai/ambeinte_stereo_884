import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Clase que define el tema y utilidades responsivas de la aplicación
///
/// Proporciona un tema oscuro personalizado y métodos auxiliares para
/// calcular tamaños, padding y otros valores de forma responsiva según
/// el tamaño de pantalla (móvil o tablet)
class AppTheme {
  /// Tema oscuro principal de la aplicación
  ///
  /// Configuración completa de Material Design 3 con colores personalizados
  /// y componentes adaptados para pantallas móviles y tablets
  static ThemeData get darkTheme {
    return ThemeData(
      primarySwatch: MaterialColor(0xFF6366F1, {
        50: Color(0xFFF0F9FF),
        100: Color(0xFFE0F2FE),
        200: Color(0xFFBAE6FD),
        300: Color(0xFF7DD3FC),
        400: Color(0xFF38BDF8),
        500: Color(0xFF0EA5E9),
        600: Color(0xFF6366F1),
        700: Color(0xFF3730A3),
        800: Color(0xFF312E81),
        900: Color(0xFF1E1B4B),
      }),
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
      appBarTheme: _buildResponsiveAppBarTheme(),
      bottomNavigationBarTheme: _buildResponsiveBottomNavTheme(),
      elevatedButtonTheme: _buildResponsiveElevatedButtonTheme(),
      textTheme: _buildResponsiveTextTheme(),
      cardTheme: _buildResponsiveCardTheme(),
      sliderTheme: _buildResponsiveSliderTheme(),
      iconTheme: _buildResponsiveIconTheme(),
    );
  }

  /// Construye el tema del AppBar con soporte responsivo
  ///
  /// Los tamaños de texto se calculan dinámicamente en cada pantalla
  static AppBarTheme _buildResponsiveAppBarTheme() {
    return AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      toolbarHeight: null, // Permite altura adaptativa
    );
  }

  /// Construye el tema de la barra de navegación inferior
  ///
  /// Los tamaños de iconos y texto se ajustan dinámicamente en MainScreen
  static BottomNavigationBarThemeData _buildResponsiveBottomNavTheme() {
    return BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
    );
  }

  /// Construye el tema de los botones elevados
  ///
  /// Los paddings y border radius se calculan dinámicamente donde se usen
  static ElevatedButtonThemeData _buildResponsiveElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.primary),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        elevation: WidgetStateProperty.resolveWith<double>((states) {
          if (states.contains(WidgetState.pressed)) return 2;
          return 4;
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textStyle: WidgetStateProperty.all(
          TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Construye el tema de texto base de la aplicación
  ///
  /// Define estilos para headlines, títulos, cuerpo y etiquetas.
  /// Los tamaños de fuente se calculan dinámicamente en cada widget
  static TextTheme _buildResponsiveTextTheme() {
    return TextTheme(
      // Headlines - Para títulos principales
      headlineLarge: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),

      // Titles - Para títulos de secciones
      titleLarge: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),

      // Body text - Para contenido general
      bodyLarge: TextStyle(color: Colors.white, height: 1.5),
      bodyMedium: TextStyle(color: AppColors.textMuted, height: 1.5),
      bodySmall: TextStyle(color: AppColors.textMuted, height: 1.4),

      // Labels - Para etiquetas y textos pequeños
      labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Construye el tema de las tarjetas (Cards)
  static CardThemeData _buildResponsiveCardTheme() {
    return CardThemeData(
      color: AppColors.surface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero, // Se maneja dinámicamente en cada card
    );
  }

  /// Construye el tema de los sliders
  static SliderThemeData _buildResponsiveSliderTheme() {
    return SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.textSecondary.withValues(alpha: 0.3),
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withValues(alpha: 0.2),
      valueIndicatorColor: AppColors.primary,
      valueIndicatorTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Construye el tema de los iconos
  static IconThemeData _buildResponsiveIconTheme() {
    return IconThemeData(color: Colors.white);
  }

  // ============================================
  // MÉTODOS UTILITARIOS PARA DISEÑO RESPONSIVO
  // ============================================

  /// Calcula el tamaño de fuente responsivo según el dispositivo
  ///
  /// [baseSize] - Tamaño base para móviles
  /// [tabletMultiplier] - Multiplicador para tablets (por defecto 1.2)
  ///
  /// Considera el factor de escala de texto del sistema
  static double getResponsiveFontSize(
    BuildContext context, {
    required double baseSize,
    double tabletMultiplier = 1.2,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    return (isTablet ? baseSize * tabletMultiplier : baseSize) * textScale;
  }

  /// Calcula padding uniforme responsivo
  ///
  /// [basePadding] - Padding base para móviles
  /// [tabletMultiplier] - Multiplicador para tablets (por defecto 1.3)
  static EdgeInsets getResponsivePadding(
    BuildContext context, {
    required double basePadding,
    double tabletMultiplier = 1.3,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final padding = isTablet ? basePadding * tabletMultiplier : basePadding;

    return EdgeInsets.all(padding);
  }

  /// Calcula padding simétrico responsivo (horizontal y vertical)
  ///
  /// [horizontalBase] - Padding horizontal base para móviles
  /// [verticalBase] - Padding vertical base para móviles
  /// [tabletMultiplier] - Multiplicador para tablets (por defecto 1.3)
  static EdgeInsets getResponsiveSymmetricPadding(
    BuildContext context, {
    required double horizontalBase,
    required double verticalBase,
    double tabletMultiplier = 1.3,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return EdgeInsets.symmetric(
      horizontal: isTablet ? horizontalBase * tabletMultiplier : horizontalBase,
      vertical: isTablet ? verticalBase * tabletMultiplier : verticalBase,
    );
  }

  /// Calcula el radio de borde responsivo
  ///
  /// [baseRadius] - Radio base para móviles
  /// [tabletMultiplier] - Multiplicador para tablets (por defecto 1.3)
  static double getResponsiveBorderRadius(
    BuildContext context, {
    required double baseRadius,
    double tabletMultiplier = 1.3,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return isTablet ? baseRadius * tabletMultiplier : baseRadius;
  }

  /// Calcula el tamaño de icono responsivo
  ///
  /// [baseSize] - Tamaño base para móviles
  /// [tabletMultiplier] - Multiplicador para tablets (por defecto 1.2)
  ///
  /// Considera el factor de escala de texto del sistema
  static double getResponsiveIconSize(
    BuildContext context, {
    required double baseSize,
    double tabletMultiplier = 1.2,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    return (isTablet ? baseSize * tabletMultiplier : baseSize) * textScale;
  }

  /// Determina si el dispositivo actual es una tablet
  ///
  /// Considera tablet cualquier dispositivo con lado más corto >= 600dp
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  /// Determina si el dispositivo está en orientación horizontal
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }
}
