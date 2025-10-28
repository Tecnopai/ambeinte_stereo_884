import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Se asume que este archivo define los colores estáticos de la aplicación.
import 'app_colors.dart';

/// {@template app_theme}
/// Clase que define el tema visual de la aplicación y proporciona métodos
/// auxiliares para calcular tamaños, padding y otros valores de forma
/// responsiva según el tamaño de la pantalla (móvil o tablet).
/// {@endtemplate}
class AppTheme {
  /// Constructor privado para evitar la instanciación de esta clase utilitaria.
  AppTheme._();

  /// {@template dark_theme}
  /// Tema oscuro principal de la aplicación.
  ///
  /// Configuración completa de Material Design 3 con colores personalizados
  /// y componentes adaptados para proporcionar una experiencia de usuario consistente.
  /// {@endtemplate}
  static ThemeData get darkTheme {
    return ThemeData(
      // Definición del color primario y su paleta de matices.
      primarySwatch: const MaterialColor(0xFF6366F1, {
        50: Color(0xFFF0F9FF),
        100: Color(0xFFE0F2FE),
        200: Color(0xFFBAE6FD),
        300: Color(0xFF7DD3FC),
        400: Color(0xFF38BDF8),
        500: Color(0xFF0EA5E9),
        // Este es el color primario real de la aplicación (indigo/violeta).
        600: Color(0xFF6366F1),
        700: Color(0xFF3730A3),
        800: Color(0xFF312E81),
        900: Color(0xFF1E1B4B),
      }),
      // Color de fondo principal (escenario).
      scaffoldBackgroundColor: AppColors.background,
      // Habilita explícitamente el uso de Material 3 (opcional, pero buena práctica).
      useMaterial3: true,
      // Temas específicos de componentes con lógica responsiva.
      appBarTheme: _buildResponsiveAppBarTheme(),
      bottomNavigationBarTheme: _buildResponsiveBottomNavTheme(),
      elevatedButtonTheme: _buildResponsiveElevatedButtonTheme(),
      textTheme: _buildResponsiveTextTheme(),
      cardTheme: _buildResponsiveCardTheme(),
      sliderTheme: _buildResponsiveSliderTheme(),
      iconTheme: _buildResponsiveIconTheme(),
    );
  }

  /// Construye el tema del [AppBar] con soporte responsivo.
  ///
  /// Define estilos uniformes y la configuración de la barra de estado.
  static AppBarTheme _buildResponsiveAppBarTheme() {
    return const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      // Estilo de superposición para que los iconos del sistema sean claros.
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      // Permite que la altura sea calculada por el widget AppBar.
      toolbarHeight: null,
    );
  }

  /// Construye el tema de la barra de navegación inferior ([BottomNavigationBar]).
  ///
  /// Asegura consistencia en colores y tipografía para los ítems seleccionados y no seleccionados.
  static BottomNavigationBarThemeData _buildResponsiveBottomNavTheme() {
    return const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      // Tipo fijo para evitar que los ítems se muevan al seleccionarse.
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
    );
  }

  /// Construye el tema de los botones elevados ([ElevatedButton]).
  ///
  /// Define el color primario, el radio de borde y la elevación dinámica.
  static ElevatedButtonThemeData _buildResponsiveElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.primary),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        // Elevación que cambia al presionar el botón.
        elevation: WidgetStateProperty.resolveWith<double>((states) {
          if (states.contains(WidgetState.pressed)) return 2;
          return 4;
        }),
        // Borde redondeado de 12.
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Construye el tema de texto base de la aplicación ([TextTheme]).
  ///
  /// Define estilos base para todas las categorías tipográficas.
  /// **Nota:** Los tamaños de fuente deben calcularse usando [getResponsiveFontSize].
  static TextTheme _buildResponsiveTextTheme() {
    return TextTheme(
      // Headlines - Para títulos principales de gran impacto.
      headlineLarge: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
      headlineMedium: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      headlineSmall: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),

      // Titles - Para títulos de secciones y elementos de interfaz.
      titleLarge: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      titleMedium: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleSmall: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),

      // Body text - Para contenido general de la aplicación.
      bodyLarge: const TextStyle(color: Colors.white, height: 1.5),
      bodyMedium: const TextStyle(color: AppColors.textMuted, height: 1.5),
      bodySmall: const TextStyle(color: AppColors.textMuted, height: 1.4),

      // Labels - Para etiquetas de botones, entradas de texto, etc.
      labelLarge: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Construye el tema de las tarjetas ([CardThemeData]).
  ///
  /// Define el color, elevación, sombra y la forma redondeada para todas las tarjetas.
  static CardThemeData _buildResponsiveCardTheme() {
    return CardThemeData(
      color: AppColors.surface,
      elevation: 4,
      // Sombra sutil para el tema oscuro.
      // CORRECCIÓN: Reemplazo de .withOpacity por .withValues(alpha: 0.15).
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Se establece a cero para permitir el manejo del margen de forma dinámica en el widget Card.
      margin: EdgeInsets.zero,
    );
  }

  /// Construye el tema de los controles deslizantes ([SliderThemeData]).
  ///
  /// Define los colores para la pista, el pulgar y el indicador de valor.
  static SliderThemeData _buildResponsiveSliderTheme() {
    return SliderThemeData(
      activeTrackColor: AppColors.primary,
      // CORRECCIÓN: Reemplazo de .withOpacity por .withValues(alpha: 0.3).
      inactiveTrackColor: AppColors.textSecondary.withValues(alpha: 0.3),
      thumbColor: AppColors.primary,
      // CORRECCIÓN: Reemplazo de .withOpacity por .withValues(alpha: 0.2).
      overlayColor: AppColors.primary.withValues(alpha: 0.2),
      valueIndicatorColor: AppColors.primary,
      valueIndicatorTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Construye el tema de los iconos ([IconThemeData]).
  static IconThemeData _buildResponsiveIconTheme() {
    return const IconThemeData(color: Colors.white);
  }

  // ====================================================================
  // MÉTODOS UTILITARIOS PARA DISEÑO RESPONSIVO
  // ====================================================================

  /// {@template get_responsive_font_size}
  /// Calcula el tamaño de fuente responsivo según el dispositivo (móvil o tablet).
  ///
  /// Aplica un multiplicador de escala para tablets y respeta el factor de escala
  /// de texto configurado por el usuario en el sistema operativo.
  ///
  /// @param context Contexto de construcción del widget.
  /// @param baseSize Tamaño base de la fuente para dispositivos móviles.
  /// @param tabletMultiplier Multiplicador aplicado si es una tablet (por defecto 1.2).
  /// @return Tamaño de fuente calculado.
  /// {@endtemplate}
  static double getResponsiveFontSize(
    BuildContext context, {
    required double baseSize,
    double tabletMultiplier = 1.2,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;
    // Obtiene el factor de escala de texto del sistema.
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    return (isTablet ? baseSize * tabletMultiplier : baseSize) * textScale;
  }

  /// {@template get_responsive_padding}
  /// Calcula padding uniforme responsivo.
  ///
  /// Aplica un multiplicador al padding base si el dispositivo es una tablet.
  ///
  /// @param context Contexto de construcción del widget.
  /// @param basePadding Padding base uniforme para dispositivos móviles.
  /// @param tabletMultiplier Multiplicador aplicado si es una tablet (por defecto 1.3).
  /// @return Objeto [EdgeInsets] con el padding calculado.
  /// {@endtemplate}
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

  /// {@template get_responsive_symmetric_padding}
  /// Calcula padding simétrico responsivo (horizontal y vertical).
  ///
  /// @param context Contexto de construcción del widget.
  /// @param horizontalBase Padding horizontal base para dispositivos móviles.
  /// @param verticalBase Padding vertical base para dispositivos móviles.
  /// @param tabletMultiplier Multiplicador aplicado si es una tablet (por defecto 1.3).
  /// @return Objeto [EdgeInsets] con el padding calculado.
  /// {@endtemplate}
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

  /// {@template get_responsive_border_radius}
  /// Calcula el radio de borde responsivo.
  ///
  /// Aplica un multiplicador al radio base si el dispositivo es una tablet.
  ///
  /// @param context Contexto de construcción del widget.
  /// @param baseRadius Radio base para dispositivos móviles.
  /// @param tabletMultiplier Multiplicador aplicado si es una tablet (por defecto 1.3).
  /// @return Valor [double] del radio de borde calculado.
  /// {@endtemplate}
  static double getResponsiveBorderRadius(
    BuildContext context, {
    required double baseRadius,
    double tabletMultiplier = 1.3,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return isTablet ? baseRadius * tabletMultiplier : baseRadius;
  }

  /// {@template get_responsive_icon_size}
  /// Calcula el tamaño de icono responsivo.
  ///
  /// Aplica un multiplicador de escala para tablets y respeta el factor de escala
  /// de texto del sistema (para iconos que escalan con texto).
  ///
  /// @param context Contexto de construcción del widget.
  /// @param baseSize Tamaño base del icono para dispositivos móviles.
  /// @param tabletMultiplier Multiplicador aplicado si es una tablet (por defecto 1.2).
  /// @return Tamaño del icono calculado.
  /// {@endtemplate}
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

  /// Determina si el dispositivo actual es una tablet.
  ///
  /// La convención utilizada es que un dispositivo es tablet si su lado más corto
  /// es igual o mayor a 600dp.
  ///
  /// @param context Contexto de construcción del widget.
  /// @return `true` si es una tablet, `false` en caso contrario.
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  /// Determina si el dispositivo está en orientación horizontal (landscape).
  ///
  /// @param context Contexto de construcción del widget.
  /// @return `true` si la anchura es mayor que la altura, `false` en caso contrario.
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }
}
