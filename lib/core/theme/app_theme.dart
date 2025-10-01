import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
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

  static AppBarTheme _buildResponsiveAppBarTheme() {
    return AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      // Títulos responsivos se manejan directamente en cada AppBar
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        // El tamaño se calcula dinámicamente en cada pantalla
      ),
      toolbarHeight: null, // Permite altura adaptativa
    );
  }

  static BottomNavigationBarThemeData _buildResponsiveBottomNavTheme() {
    return BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      // Los tamaños de iconos y texto se manejan dinámicamente en MainScreen
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
    );
  }

  static ElevatedButtonThemeData _buildResponsiveElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.primary),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        elevation: WidgetStateProperty.resolveWith<double>((states) {
          if (states.contains(WidgetState.pressed)) return 2;
          return 4;
        }),
        // Los paddings y border radius se calculan dinámicamente donde se usen
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Base, se puede override
          ),
        ),
        textStyle: WidgetStateProperty.all(
          TextStyle(
            fontWeight: FontWeight.w600,
            // fontSize se calcula dinámicamente
          ),
        ),
      ),
    );
  }

  static TextTheme _buildResponsiveTextTheme() {
    // Base text theme - los tamaños se calculan dinámicamente en cada widget
    return TextTheme(
      // Headlines
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

      // Titles
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

      // Body text
      bodyLarge: TextStyle(color: Colors.white, height: 1.5),
      bodyMedium: TextStyle(color: AppColors.textMuted, height: 1.5),
      bodySmall: TextStyle(color: AppColors.textMuted, height: 1.4),

      // Labels
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

  static CardThemeData _buildResponsiveCardTheme() {
    return CardThemeData(
      color: AppColors.surface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      // Border radius se calcula dinámicamente
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Base, se puede override
      ),
      margin: EdgeInsets.zero, // Se maneja dinámicamente en cada card
    );
  }

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
      // Track height y thumb radius se calculan dinámicamente
    );
  }

  static IconThemeData _buildResponsiveIconTheme() {
    return IconThemeData(
      color: Colors.white,
      // Size se calcula dinámicamente en cada widget
    );
  }

  // Métodos utilitarios para cálculos responsivos
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

  static double getResponsiveBorderRadius(
    BuildContext context, {
    required double baseRadius,
    double tabletMultiplier = 1.3,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide >= 600;

    return isTablet ? baseRadius * tabletMultiplier : baseRadius;
  }

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

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }
}
